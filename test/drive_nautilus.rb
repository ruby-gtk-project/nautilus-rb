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

# GLib reads $XDG_DATA_HOME once, through g_get_user_data_dir(), and caches
# the result for the life of the process — so this has to be the directory
# GIO's trash implementation will use for the rest of the run, decided here
# before anything below has a chance to call into GLib and freeze a
# different answer in. It is rooted under the real home directory rather
# than the system temp directory for the same reason the trash-test scratch
# folder near the bottom of this script is: GIO's local trash backend
# refuses to move a file across a filesystem boundary (confirmed by hand —
# see the port report), and the system temp directory is commonly a tmpfs
# distinct from the one the real home directory sits on. Everything written
# under either scratch directory is still scoped to a `Dir.mktmpdir` this
# script owns and removes; nothing here reads or writes the rest of the
# real home directory.
ENV['XDG_DATA_HOME'] = Dir.mktmpdir('nautilus-drive-data', Dir.home)
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

# --- Fixtures for the binding-gem checks below ----------------------------
#
# A real archive, a real image and (best-effort) a real audio file: ashpd,
# gnome-autoar, gexiv2, glycin and gstreamer_pbutils all fail softly on
# content they cannot read, which means a check built on nil/empty/missing
# fixtures would pass whether or not the gem actually worked. Each fixture
# below is something the relevant gem can actually parse, confirmed by hand
# first (see the port report), so a later check failing here means the gem
# call broke, not that the fixture was hollow.
#
# Built in their own folder, not SCRATCH, and copied in only right before the
# step that needs them: the early steps above assert SCRATCH's exact entry
# count (four), and dropping these in from the start would throw that off.
FIXTURES = Dir.mktmpdir('nautilus-drive-fixtures')

# A real one-file tar.gz, built with the system `tar` the dev shell provides
# — this is what GnomeAutoar::Extractor is asked to open below.
ARCHIVE_SOURCE = Dir.mktmpdir('nautilus-drive-archive-source')
File.write(File.join(ARCHIVE_SOURCE, 'inside.txt'), 'packed')
ARCHIVE_FIXTURE = File.join(FIXTURES, 'bundle.tar.gz')
system('tar', '-czf', ARCHIVE_FIXTURE, '-C', ARCHIVE_SOURCE, 'inside.txt', exception: true)

# A real 1x1 PNG (not a placeholder with a .png extension on empty bytes) —
# GExiv2::Metadata needs real image data to read pixel_width/pixel_height
# from, which is the whole point of the check below. The bytes are the
# smallest possible PNG: an 8-byte signature, one IHDR chunk declaring a
# single red pixel, one IDAT chunk, and IEND.
PNG_1X1_BYTES = [
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x04, 0x00, 0x00, 0x00, 0xb5, 0x1c, 0x0c, 0x02, 0x00, 0x00, 0x00,
  0x0b, 0x49, 0x44, 0x41, 0x54, 0x78, 0xda, 0x63, 0x64, 0xf8, 0x0f, 0x00,
  0x01, 0x05, 0x00, 0x01, 0x68, 0xfa, 0xc5, 0x04, 0x00, 0x00, 0x00, 0x00,
  0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82,
].freeze
IMAGE_FIXTURE = File.join(FIXTURES, 'pixel.png')
File.binwrite(IMAGE_FIXTURE, PNG_1X1_BYTES.pack('C*'))

# A real, short Ogg/Vorbis tone, built with the gst-launch-1.0 the dev shell
# provides (gst-plugins-base alone, no codecs from -good/-ugly, can both
# produce and read this container/codec pair) — GstPbutils::Discoverer needs
# a file GStreamer can actually demux and decode, which a WAV or an empty
# file in this dev shell's plugin set is not: no wavparse ships here.
AUDIO_FIXTURE = File.join(FIXTURES, 'tone.ogg')
AUDIO_FIXTURE_BUILT = system(
  'gst-launch-1.0', 'audiotestsrc', 'num-buffers=50', '!', 'audioconvert', '!',
  'vorbisenc', '!', 'oggmux', '!', 'filesink', "location=#{AUDIO_FIXTURE}",
  %i[out err] => File::NULL,
)

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

  # --- The binding gems: each one's own live code path, not a mock -------
  #
  # None of the steps above ever selected an archive, an image, an audio
  # file, or opened Properties, or looked at the sidebar's Cloud section —
  # so ashpd, gnome-autoar, gexiv2, glycin, gstreamer_pbutils and
  # libcloudproviders were never actually exercised by this script, however
  # real their call sites looked on a read of the source. Each step below
  # drives the same GAction or public method the UI does.

  d.step('the sidebar\'s Cloud section calls into CloudProviders::Collector') do
    app.windows.first.sidebar.then do |sidebar|
      d.check('the collector is a real CloudProviders::Collector') do
        sidebar.cloud_provider_collector.is_a?(CloudProviders::Collector)
      end
      d.check('asking it for places does not raise') do
        sidebar.cloud_provider_places.is_a?(Array)
      end
    end
  end

  d.step('the archive, image and (if built) tone fixtures land in the scratch folder') do
    FileUtils.cp(ARCHIVE_FIXTURE, SCRATCH)
    FileUtils.cp(IMAGE_FIXTURE, SCRATCH)
    FileUtils.cp(AUDIO_FIXTURE, SCRATCH) if AUDIO_FIXTURE_BUILT
    app.windows.first.active_slot.reload
  end

  d.step('the scratch folder sees the new fixtures') do
    app.windows.first.active_slot.directory.then do |dir|
      d.check('the archive is there') { dir.files.any? { |f| f.name == 'bundle.tar.gz' } }
      d.check('the image is there') { dir.files.any? { |f| f.name == 'pixel.png' } }
    end
  end

  d.step('view.select-pattern selects the test archive') do
    app.windows.first.active_slot.files_view.then do |view|
      view.current_view.select_pattern('bundle.tar.gz')
      d.check('exactly the archive is selected') do
        view.selected_files.map(&:name) == ['bundle.tar.gz']
      end
      d.check('view.extract-here is enabled for it') do
        view.actions.lookup_action('extract-here').enabled?
      end
    end
  end

  d.step('view.extract-here runs GnomeAutoar::Extractor on it') do
    app.windows.first.active_slot.files_view.actions.lookup_action('extract-here').activate(nil)
  end

  d.step('the extracted file is exactly where autoar\'s own suggested name puts it') do
    d.check('bundle/inside.txt exists') { File.exist?(File.join(SCRATCH, 'bundle', 'inside.txt')) }
    d.check('its content survived the round trip') do
      File.read(File.join(SCRATCH, 'bundle', 'inside.txt')) == 'packed'
    end
    d.check('autoar did not nest a second "bundle" inside it (the bug this fixed)') do
      !File.directory?(File.join(SCRATCH, 'bundle', 'bundle'))
    end
    app.windows.first.active_slot.reload
  end

  d.step('view.select-pattern selects the test image') do
    app.windows.first.active_slot.files_view.then do |view|
      view.current_view.select_pattern('pixel.png')
      d.check('exactly the image is selected') { view.selected_files.map(&:name) == ['pixel.png'] }
    end
  end

  d.step('view.properties opens a Properties dialog that read the image with GExiv2') do
    pending_dialog = app.windows.first.active_slot.files_view.send(:show_properties)
    metadata = pending_dialog.send(:image_metadata)
    d.check('GExiv2::Metadata opened the real file') { !metadata.nil? }
    d.check('it read real pixel dimensions off it (not the 0x0 glycin fallback)') do
      metadata.pixel_width == 1 && metadata.pixel_height == 1
    end
    d.check('the dialog\'s own dimensions text agrees') do
      pending_dialog.send(:dimensions_text, metadata) == '1 × 1'
    end
  end

  d.step('the properties dialog renders, then closes') do
    d.shot('16-properties-dialog')
    pending_dialog.dialog.close
  end

  if AUDIO_FIXTURE_BUILT
    d.step('view.select-pattern selects the test tone') do
      app.windows.first.active_slot.files_view.then do |view|
        view.current_view.select_pattern('tone.ogg')
        d.check('exactly the tone is selected') { view.selected_files.map(&:name) == ['tone.ogg'] }
      end
    end

    d.step('view.properties opens a Properties dialog that read the tone with GstPbutils') do
      pending_dialog = app.windows.first.active_slot.files_view.send(:show_properties)
      info = pending_dialog.send(:discover_info)
      d.check('GstPbutils::Discoverer discovered the real file') { !info.nil? }
      d.check('it found the one audio stream') { info.audio_streams.length == 1 }
      d.check('it read a positive duration off it') { info.duration.positive? }
    end

    d.step('the audio properties dialog renders, then closes') do
      d.shot('17-audio-properties-dialog')
      pending_dialog.dialog.close
    end
  else
    d.step('gstreamer_pbutils check skipped: no gst-launch-1.0 tone fixture to discover') do
      d.check('skipped, not failed - see AUDIO_FIXTURE_BUILT above') { true }
    end
  end

  d.step('view.send-email reaches Ashpd::OpenUri.open (falling back without crashing)') do
    app.windows.first.active_slot.files_view.then do |view|
      view.current_view.select_pattern('pixel.png')
      d.check('one file is selected to attach') { view.selected_files.length == 1 }
      view.actions.lookup_action('send-email').activate(nil)
      d.check('send-email did not raise out to the main loop') { true }
    end
  end

  # view.move-to-trash, exercised through the real FileOperations.trash call
  # (Ashpd::Trash.file, falling back to GIO's own g_file_trash()) on a file
  # placed where that fallback can actually succeed: GIO's local trash
  # backend refuses to move a file across a filesystem boundary, and won't
  # use a tmpfs at all — confirmed by hand first, see the port report. The
  # top-level XDG_DATA_HOME above is already rooted under the real home
  # directory for exactly this reason; this file just needs to share that
  # filesystem, which a second home-directory scratch folder does, where
  # the system temp directory SCRATCH otherwise lives in does not.
  TRASH_SCRATCH = Dir.mktmpdir('nautilus-drive-trash-scratch', Dir.home)
  TRASH_FILE = File.join(TRASH_SCRATCH, 'trash-me.txt')
  File.write(TRASH_FILE, 'temporary')

  d.step('win.new-tab opens a second tab, navigated to the trash-test folder') do
    app.windows.first.actions.lookup_action('new-tab').activate(nil)
    app.windows.first.active_slot.open_location(Gio::File.new_for_path(TRASH_SCRATCH))
  end

  d.step('the trash-test folder loaded with its one file') do
    app.windows.first.active_slot.directory.then do |dir|
      d.check('the file is there to begin with') { dir.files.any? { |f| f.name == 'trash-me.txt' } }
    end
  end

  d.step('view.select-all selects the one file, then view.move-to-trash runs FileOperations.trash') do
    app.windows.first.active_slot.files_view.then do |view|
      view.current_view.select_all
      view.actions.lookup_action('move-to-trash').activate(nil)
    end
  end

  d.step('the file is gone from disk - Ashpd::Trash.file or its GIO fallback actually ran') do
    d.check('trash-me.txt no longer exists at its old path') { !File.exist?(TRASH_FILE) }
  end

  d.step('win.close-current-view closes the trash-test tab') do
    app.windows.first.actions.lookup_action('close-current-view').activate(nil)
  end

  # FileOperations.copy's real conflict path: copying over an existing name
  # pauses on a live Nautilus::FileConflictDialog rather than just erroring.
  CONFLICT_DIR = Dir.mktmpdir('nautilus-drive-conflict')
  CONFLICT_SOURCE = File.join(CONFLICT_DIR, 'source.txt')
  CONFLICT_DEST_DIR = File.join(CONFLICT_DIR, 'dest')
  CONFLICT_DEST_FILE = File.join(CONFLICT_DEST_DIR, 'source.txt')
  FileUtils.mkdir_p(CONFLICT_DEST_DIR)
  File.write(CONFLICT_SOURCE, 'new-contents')
  File.write(CONFLICT_DEST_FILE, 'old-contents')

  d.step('Nautilus::FileOperations.copy onto an existing name opens a conflict dialog') do
    Nautilus::FileOperations.copy(
      [Gio::File.new_for_path(CONFLICT_SOURCE)],
      Gio::File.new_for_path(CONFLICT_DEST_DIR),
    )
  end

  conflict_dialog = nil

  d.step('the conflict dialog is a live FileConflictDialog, offering Replace') do
    conflict_dialog = ObjectSpace.each_object(Nautilus::FileConflictDialog).first
    d.check('a FileConflictDialog instance exists') { !conflict_dialog.nil? }
    d.check('the destination content is still the old one, pending a response') do
      File.read(CONFLICT_DEST_FILE) == 'old-contents'
    end
  end

  d.step('choosing Replace runs the real overwrite through Gio::File#copy') do
    conflict_dialog.send(:respond, Nautilus::FileConflictDialog::RESPONSE_REPLACE)
  end

  d.step('the destination now has the source file’s real content') do
    d.check('source.txt was actually overwritten') { File.read(CONFLICT_DEST_FILE) == 'new-contents' }
  end

  # NetworkAddressBar's real Gio::Vfs query decides which schemes enable
  # Connect; it also only shows up while browsing network:///. This dev
  # shell has no gvfs network backend to actually enumerate network:///
  # (Gio::IOError::NotSupported), so the slot's location is swapped
  # directly rather than through a real failing navigation — Window#
  # on_slot_changed is still the real production method under test.
  d.step('the window reacts to a network:/// location by showing the address bar') do
    window = app.windows.first
    window.active_slot.instance_variable_set(:@location, Gio::File.new_for_uri('network:///'))
    window.send(:on_slot_changed, window.active_slot)
    d.check('network_address_bar.root is visible') { window.network_address_bar.root.get_property('visible') }
  end

  d.step('its Connect button reflects the real Gio::Vfs-supported schemes') do
    bar = app.windows.first.network_address_bar
    bar.address_entry.text = 'bogus-no-such-scheme://host'
    d.check('an unsupported scheme leaves Connect disabled') { !bar.connect_button.get_property('sensitive') }
    bar.address_entry.text = 'resource://x'
    d.check('a real Gio::Vfs-supported scheme enables Connect') { bar.connect_button.get_property('sensitive') }
  end

  d.step('leaving network:/// hides the address bar again') do
    window = app.windows.first
    window.active_slot.instance_variable_set(:@location, Gio::File.new_for_path(SCRATCH))
    window.send(:on_slot_changed, window.active_slot)
    d.check('network_address_bar.root is hidden again') { !window.network_address_bar.root.get_property('visible') }
  end
end

# Not removed before this point: closing the tab above does not synchronously
# drop the window slot's directory file-monitor, so an rm_rf of either scratch
# folder while the main loop could still deliver a queued reload for it was
# observed to crash the run with an uncaught Gio::IOError::NotFound, from well
# after the step that triggered it. By the time GtkDriver.drive returns, the
# application has quit and the main loop is no longer running anything that
# could race with this.
FileUtils.rm_rf(ENV.fetch('XDG_DATA_HOME'))
FileUtils.rm_rf(FIXTURES)
FileUtils.rm_rf(ARCHIVE_SOURCE)
FileUtils.rm_rf(TRASH_SCRATCH)
FileUtils.rm_rf(CONFLICT_DIR)
