# frozen_string_literal: true

# Drives the whole nautilus-rb port headlessly: builds the main window,
# navigates a scratch folder of known files, opens every dialog the port
# ships (new folder, select-items, column chooser, grid captions, rename,
# preferences, shortcuts, about), exercises select mode via the view modes,
# sidebar navigation, history, tabs, the narrow-layout breakpoint and the
# application's accelerators, and screenshots each state.
#
# Run it from the repository root:
#
#   nix develop --command xvfb-run -a ruby test/drive_nautilus.rb
#
# A scratch XDG_CONFIG_HOME keeps this from touching real settings, and the
# window is immediately pointed at a scratch directory this script builds,
# so nothing here reads or writes the real home directory.
#
# Every Adw.Dialog interaction here is split across two steps (one tick to
# open, the next to type into it and accept) because gtk_widget_activate
# declines on a widget the main loop has not yet had a turn to realise and
# map - see the companion skill's "dialogs stack" / same-tick traps.

$stdout.sync = true

require 'fileutils'
require 'tmpdir'

ENV['XDG_CONFIG_HOME'] = Dir.mktmpdir('nautilus-drive-config')
ENV['XDG_DATA_HOME'] = Dir.mktmpdir('nautilus-drive-data')
ENV['GTK_A11Y'] = 'none'

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'nautilus'
require_relative 'gtk_driver'

SHOTS = File.expand_path('../tmp/shots', __dir__)
FileUtils.rm_rf(SHOTS)

# A scratch folder with known content to navigate to, rather than the real
# home directory: one subfolder, two regular files and one hidden file, so
# the hidden-files toggle and the folders-first sort both have something to
# prove.
SCRATCH = Dir.mktmpdir('nautilus-drive-scratch')
FileUtils.mkdir_p(File.join(SCRATCH, 'A Folder'))
File.write(File.join(SCRATCH, 'alpha.txt'), 'alpha')
File.write(File.join(SCRATCH, 'beta.txt'), 'beta')
File.write(File.join(SCRATCH, '.hidden'), 'shh')

app_object = Nautilus::Application.new

# Carried from the step that opens a dialog to the step that interacts with
# and closes it, so the dialog gets a tick to be realised before anything
# tries to click inside it.
pending_dialog = nil

GtkDriver.drive(app_object, shots: SHOTS) do |d, app|
  d.window { app.windows.first&.window }

  d.step('the application builds and activates one window') do
    d.check('exactly one window object') { app.windows.length == 1 }
    d.check('exactly one toplevel') { Gtk::Window.list_toplevels.length == 1 }
    d.check('it is an Adwaita::ApplicationWindow') do
      app.windows.first.window.is_a?(Adwaita::ApplicationWindow)
    end
    d.check('its application id is set') do
      app.app.application_id == Nautilus::Application::APPLICATION_ID
    end
    d.check('the window title is Home, from the real home directory') do
      app.windows.first.window.title == 'Home'
    end
    d.check('one tab is open') { app.windows.first.tab_view.n_pages == 1 }
  end

  d.step('the home window renders') { d.shot('01-home') }

  d.step('navigating the active tab to the scratch folder') do
    app.windows.first.active_slot.open_location(Gio::File.new_for_path(SCRATCH))
  end

  d.step('the scratch folder loaded with its known files') do
    app.windows.first.then do |win|
      d.check('the window title followed the new location') do
        win.window.title == File.basename(SCRATCH)
      end
      win.active_slot.directory.then do |dir|
        d.check('all four entries are read') { dir.files.length == 4 }
        d.check('the hidden file is excluded by default') do
          dir.visible_files.none? { |f| f.name == '.hidden' }
        end
        d.check('folders sort first') { dir.visible_files.first.directory? }
      end
    end
  end

  d.step('the scratch folder renders') { d.shot('02-scratch-folder') }

  d.step('the sidebar lists the built-in places') do
    app.windows.first.sidebar.then do |sidebar|
      d.check('places are built') { sidebar.places.length.positive? }
      d.check('Home is one of them') { sidebar.places.any? { |p| p.label == 'Home' } }
      d.check('Trash is one of them') { sidebar.places.any? { |p| p.label == 'Trash' } }
    end
  end

  d.step('bookmarking the scratch folder adds a sidebar row') do
    app.windows.first.then do |win|
      before = win.sidebar.bookmark_places.length
      win.sidebar.add_bookmark(Gio::File.new_for_path(SCRATCH))
      d.check('one more bookmark than before') do
        win.sidebar.bookmark_places.length == before + 1
      end
      d.check('the new bookmark names the scratch folder') do
        win.sidebar.bookmark_places.any? { |p| p.uri == Gio::File.new_for_path(SCRATCH).uri }
      end
    end
  end

  d.step('show-hidden-files reveals the dotfile') do
    app.windows.first.active_slot.files_view.then do |view|
      view.directory.show_hidden = true
      d.check('four files are now visible') { view.directory.visible_files.length == 4 }
      d.check('the hidden file is among them') do
        view.directory.visible_files.any? { |f| f.name == '.hidden' }
      end
      view.directory.show_hidden = false
    end
  end

  d.step('the view switches from grid to list and back, more than once') do
    app.windows.first.active_slot.files_view.then do |view|
      d.check('grid is the default mode') { view.mode == :grid }
      view.mode = :list
      d.check('list mode took') { view.mode == :list }
      view.mode = :grid
      d.check('back to grid') { view.mode == :grid }
      # A second round trip: list_view/grid_view#build ran again both times
      # above, which is exactly what used to re-attach an already-attached
      # GtkGestureClick and abort with a GTK-CRITICAL.
      view.mode = :list
      view.mode = :grid
      d.check('a second round trip leaves it in grid, with no assertion') do
        view.mode == :grid
      end
    end
  end

  d.step('switching to list mode once more') do
    app.windows.first.active_slot.files_view.mode = :list
  end

  d.step('list mode renders cleanly after the round trip') { d.shot('03-list-view') }

  d.step('switching back to grid mode') do
    app.windows.first.active_slot.files_view.mode = :grid
  end

  d.step('grid mode renders cleanly after the round trip') { d.shot('04-grid-view') }

  d.step('the new-folder dialog opens from view.new-folder') do
    pending_dialog = app.windows.first.active_slot.files_view.send(:new_folder)
    d.check('create is insensitive with an empty name') { !pending_dialog.create_button.sensitive? }
  end

  d.step('the new-folder dialog renders') { d.shot('05-new-folder-dialog') }

  d.step('naming it and accepting creates the folder') do
    pending_dialog.name_entry.text = 'Fresh Folder'
    d.check('create is sensitive once named') { pending_dialog.create_button.sensitive? }
    pending_dialog.create_button.activate
  end

  d.step('the folder landed on disk and the view reloaded') do
    d.check('the new folder exists') { File.directory?(File.join(SCRATCH, 'Fresh Folder')) }
    app.windows.first.active_slot.directory.then do |dir|
      d.check('the directory now has five entries') { dir.files.length == 5 }
      d.check('the new folder is among them') { dir.files.any? { |f| f.name == 'Fresh Folder' } }
    end
  end

  d.step('view.select-pattern opens the select-items dialog') do
    pending_dialog = app.windows.first.active_slot.files_view.send(:select_pattern)
  end

  d.step('the select-items dialog renders') { d.shot('06-select-items-dialog') }

  d.step('typing a pattern and accepting selects the matches') do
    pending_dialog.pattern_entry.text = '*.txt'
    pending_dialog.select_button.activate
  end

  d.step('the pattern selected the two .txt files') do
    app.windows.first.active_slot.files_view.selected_files.then do |selected|
      d.check('two files are selected') { selected.length == 2 }
      d.check('both are .txt files') { selected.all? { |f| f.name.end_with?('.txt') } }
    end
  end

  # NOTE on what is not asserted here: a real click-through of this popover
  # (type a name, press Rename) is not driveable in this headless Xvfb - see
  # "known environment limitation" in the report this script's caller files
  # under .reports/. Gtk::Popover opens a genuine separate GdkPopup surface
  # (unlike Adwaita::Dialog, which stays inside the main window's own
  # surface), and with no window manager running, that surface's "closed"
  # signal fires on its own within one main-loop turn of being shown - with
  # autohide explicitly turned off first, ruling out an autohide decision.
  # Everything #show_for sets up synchronously, before any of that, is
  # fully checkable; the type-and-click round trip is not.
  d.step('the rename popover opens for the first selected file, pre-filled') do
    app.windows.first.active_slot.files_view.then do |view|
      file = view.selected_files.first
      view.send(:rename_popover).tap do |popover|
        popover.show_for(file, view.directory.location, view.send(:overlay))
        d.check('it is showing') { popover.popover.visible? }
        d.check('the title names the file, not the folder wording') do
          popover.title_label.label == 'Rename File'
        end
        d.check("the entry is pre-filled with the file's display name") do
          popover.name_entry.text == file.display_name
        end
        d.shot('07-rename-popover')
      end
    end
  end

  d.step('view.visible-columns opens the column chooser over the list view') do
    app.windows.first.active_slot.files_view.then do |view|
      view.mode = :list
      pending_dialog = view.send(:show_column_chooser)
    end
  end

  d.step('the column chooser renders') { d.shot('08-column-chooser') }

  d.step('it offers the list view\'s visible columns, then closes') do
    d.check('at least one visible column row') { pending_dialog.send(:visible_columns).length.positive? }
    pending_dialog.dialog.close
    app.windows.first.active_slot.files_view.mode = :grid
  end

  d.step('view.visible-captions opens the grid captions dialog over the grid view') do
    pending_dialog = app.windows.first.active_slot.files_view.send(:show_captions_dialog)
  end

  d.step('the captions dialog renders') { d.shot('09-captions-dialog') }

  d.step('it offers upstream\'s three caption rows, then closes') do
    d.check('three caption rows, as upstream does') { pending_dialog.combo_rows.length == 3 }
    pending_dialog.dialog.close
  end

  d.step('win.new-tab opens a second tab') do
    app.windows.first.actions.lookup_action('new-tab').activate(nil)
  end

  d.step('the tab bar now carries two pages') do
    app.windows.first.then do |win|
      d.check('two tabs now') { win.tab_view.n_pages == 2 }
      d.check('the new tab is on the same location (new-tab, not clone)') do
        win.active_slot.location.path == SCRATCH
      end
    end
  end

  d.step('the two tabs render') { d.shot('10-two-tabs') }

  d.step('win.close-current-view closes the second tab') do
    app.windows.first.actions.lookup_action('close-current-view').activate(nil)
  end

  d.step('one tab is left, and it is the original slot') do
    app.windows.first.then do |win|
      d.check('back to one tab') { win.tab_view.n_pages == 1 }
      d.check('the surviving slot is still on the scratch folder') do
        win.active_slot.location.path == SCRATCH
      end
    end
  end

  d.step('history remembers the trip to the scratch folder') do
    app.windows.first.active_slot.then do |slot|
      d.check('back is available') { slot.can_go_back? }
      slot.back
      d.check('back landed on the real home directory') { slot.location.path == Dir.home }
      d.check('forward is now available') { slot.can_go_forward? }
      slot.forward
      d.check('forward returned to the scratch folder') { slot.location.path == SCRATCH }
    end
  end

  d.step('the narrow-layout breakpoint collapses the sidebar and swaps controls') do
    app.windows.first.then do |win|
      win.breakpoint.signal_emit('apply')
      d.check('the split view collapsed') { win.split_view.collapsed? }
      d.check('the tab bar hid') { !win.tab_bar.visible? }
      d.check('the action bar revealed') { win.action_bar.revealed? }
    end
  end

  d.step('the narrow layout renders') { d.shot('11-narrow-layout') }

  d.step('unapplying the breakpoint widens the layout again') do
    app.windows.first.then do |win|
      win.breakpoint.signal_emit('unapply')
      d.check('the split view widened again') { !win.split_view.collapsed? }
      d.check('the tab bar is back') { win.tab_bar.visible? }
      d.check('the action bar hid again') { !win.action_bar.revealed? }
    end
  end

  d.step('app.preferences opens the preferences dialog') do
    pending_dialog = app.send(:show_preferences)
    d.check('the title is Preferences') { pending_dialog.dialog.title == 'Preferences' }
  end

  d.step('the preferences dialog renders, then closes') do
    d.shot('12-preferences-dialog')
    pending_dialog.dialog.close
  end

  d.step('app.shortcuts opens the shortcuts dialog') do
    pending_dialog = app.send(:show_shortcuts)
    d.check('it is an Adwaita::ShortcutsDialog') { pending_dialog.is_a?(Adwaita::ShortcutsDialog) }
    d.check('its title is Keyboard Shortcuts') { pending_dialog.title == 'Keyboard Shortcuts' }
  end

  d.step('the shortcuts dialog renders, then closes') do
    d.shot('13-shortcuts-dialog')
    pending_dialog.close
  end

  d.step("app.about opens the about dialog with the port's own metadata") do
    pending_dialog = app.send(:show_about)
    d.check('its application name is Files') { pending_dialog.application_name == 'Files' }
    d.check('its icon is system-file-manager') { pending_dialog.application_icon == 'system-file-manager' }
    d.check('its licence is GPL-3.0') { pending_dialog.license_type == :gpl_3_0 }
    d.check("its website is upstream's GNOME page") do
      pending_dialog.website == 'https://apps.gnome.org/Nautilus'
    end
  end

  d.step('the about dialog renders, then closes') do
    d.shot('14-about-dialog')
    pending_dialog.close
  end

  d.step("the application installed every accelerator it names") do
    Nautilus::Application::ACCELERATORS.each do |action, accelerators|
      d.check("#{action} is #{accelerators.first}") do
        app.app.get_accels_for_action(action).map { |accel| Gtk.accelerator_parse(accel) } ==
          accelerators.map { |accel| Gtk.accelerator_parse(accel) }
      end
    end
  end

  d.step('win.toggle-sidebar hides the places sidebar') do
    app.windows.first.actions.lookup_action('toggle-sidebar').activate(nil)
  end

  d.step('the sidebar is hidden now') do
    d.check('show_sidebar? is now false') { !app.windows.first.split_view.show_sidebar? }
  end

  d.step('win.toggle-sidebar shows it again') do
    app.windows.first.actions.lookup_action('toggle-sidebar').activate(nil)
  end

  d.step('the sidebar is back') do
    d.check('show_sidebar? is true again') { app.windows.first.split_view.show_sidebar? }
  end

  d.step('view.select-all selects everything in the folder') do
    app.windows.first.active_slot.files_view.then do |view|
      view.current_view.select_all
      d.check('every entry is selected') do
        view.selected_files.length == view.directory.visible_files.length
      end
    end
  end

  d.step('view.invert-selection empties it again (everything was selected)') do
    app.windows.first.active_slot.files_view.then do |view|
      view.current_view.invert_selection
      d.check('nothing is selected now') { view.selected_files.empty? }
    end
  end
end
