# frozen_string_literal: true

require 'adwaita'
require 'fileutils'
require_relative 'sidebar_row'
require_relative 'ui_utilities'
require_relative 'dbus_launcher'

module Nautilus
  # Sidebar is the places list.
  #
  # Ported from src/nautilus-sidebar.c. The places are upstream's: Recent,
  # Starred, Home, Desktop, Trash, the user's bookmarks, then a "Device"
  # section for the drives, volumes and mounts GVolumeMonitor reports, and a
  # "Network" section ending in Network itself. Rows carry the fourteen
  # `row.*` actions, the bookmark rows can be renamed through the rename
  # popover with its "This name is already taken" state, and a failed mount,
  # eject, start or poll is reported with upstream's wording.
  class Sidebar
    # The bookmark file GTK and nautilus share.
    BOOKMARKS_FILE = ::File.join(
      ENV.fetch('XDG_CONFIG_HOME', ::File.expand_path('~/.config')),
      'gtk-3.0',
      'bookmarks',
    )

    # One place in the list: what it shows, where it goes, and what may be
    # done to it.
    Place = Struct.new(
      :label,
      :uri,
      :icon_name,
      :kind,
      :tooltip,
      :section,
      :volume,
      :mount,
      :drive,
      keyword_init: true,
    ) do
      def bookmark? = kind == :bookmark
      def ejectable? = !mount.nil? && mount.can_eject?
      def mountable? = !volume.nil? && mount.nil?
      def unmountable? = !mount.nil? && mount.can_unmount?
      def location = Gio::File.new_for_uri(uri)
    end

    # The row context menu. Its items are the `row.*` actions upstream
    # installs, each hidden when its action is not available for the row.
    ROW_MENU = [
      {
        section: [
          { label: '_Open', action: 'row.open' },
          { label: 'Open in New _Tab', action: 'row.open-other', hidden_when: 'action-disabled' },
        ],
      },
      {
        section: [
          { label: '_Remove', action: 'row.remove', hidden_when: 'action-disabled' },
          { label: 'Re_name…', action: 'row.rename', hidden_when: 'action-disabled' },
        ],
      },
      {
        section: [
          { label: '_Mount', action: 'row.mount', hidden_when: 'action-disabled' },
          { label: '_Unmount', action: 'row.unmount', hidden_when: 'action-disabled' },
          { label: '_Eject', action: 'row.eject', hidden_when: 'action-disabled' },
          { label: '_Detect Media', action: 'row.rescan', hidden_when: 'action-disabled' },
          { label: '_Start', action: 'row.start', hidden_when: 'action-disabled' },
          { label: '_Stop', action: 'row.stop', hidden_when: 'action-disabled' },
          { label: '_Format…', action: 'row.format', hidden_when: 'action-disabled' },
        ],
      },
      {
        section: [
          { label: 'Empty _Trash…', action: 'row.empty-trash', hidden_when: 'action-disabled' },
          {
            label:       'Trash _Settings',
            action:      'row.history-trash-settings',
            hidden_when: 'action-disabled',
          },
        ],
      },
      {
        section: [
          { label: '_Properties', action: 'row.properties', hidden_when: 'action-disabled' },
        ],
      },
    ].freeze

    def initialize(window_slot: nil, on_open: nil, on_properties: nil, on_empty_trash: nil, on_format: nil)
      @window_slot = window_slot
      @on_open = on_open
      @on_properties = on_properties
      @on_empty_trash = on_empty_trash
      @on_format = on_format
      @rows = []
      @context_place = nil
    end

    attr_reader :window_slot, :context_place

    def window_slot=(window_slot)
      @window_slot = window_slot
      update_selection
      window_slot
    end

    def build
      root.tap do |scroller|
        scroller.child = list_box

        list_box.tap do |list|
          list.signal_connect('row-activated') do |_list, row|
            open_row(row)
          end
          list.add_controller(secondary_gesture)
          list.add_controller(long_press_gesture)
        end

        row_menu_popover.set_parent(list_box)
        rename_popover.set_parent(list_box)

        volume_monitor.tap do |monitor|
          %w[mount-added mount-removed volume-added volume-removed drive-connected
             drive-disconnected
].each do |signal|
            monitor.signal_connect(signal) { reload }
          end
        end

        install_actions
        reload
      end
    end

    # nautilus_sidebar_update_places(): the whole list is rebuilt, because the
    # places come from four sources that change independently.
    def reload
      @rows = []
      clear
      places.each do |place|
        append_place(place)
      end
      list_box.append(new_bookmark_row)
      update_selection
      self
    end

    def places
      built_in_places + bookmark_places + device_places + network_places
    end

    # --- Widgets -------------------------------------------------------------

    def root
      @root ||= Gtk::ScrolledWindow.new.tap do |scroller|
        scroller.hscrollbar_policy = :never
        scroller.vexpand = true
      end
    end

    def list_box
      @list_box ||= Gtk::ListBox.new.tap do |list|
        list.add_css_class('navigation-sidebar')
        # Upstream also sets the a11y label "Sidebar" here;
        # gtk_accessible_update_property() has no working Ruby binding.
      end
    end

    def row_menu_popover
      @row_menu_popover ||= Gtk::PopoverMenu.new(UiUtilities.build_menu(ROW_MENU)).tap do |popover|
        popover.signal_connect('closed') do
          @context_row&.has_open_popup = false
        end
      end
    end

    # The rename popover: a grid holding the entry, the error label and the
    # Rename button.
    def rename_popover
      @rename_popover ||= Gtk::Popover.new.tap do |popover|
        popover.child = rename_grid
      end
    end

    def rename_grid
      @rename_grid ||= Gtk::Grid.new.tap do |grid|
        grid.row_spacing = 6
        grid.column_spacing = 6
        grid.margin_top = 12
        grid.margin_bottom = 12
        grid.margin_start = 12
        grid.margin_end = 12
        grid.attach(
          rename_entry,
          0,
          0,
          2,
          1,
        )
        grid.attach(
          rename_error_label,
          0,
          1,
          2,
          1,
        )
        grid.attach(
          rename_button,
          1,
          2,
          1,
          1,
        )
      end
    end

    def rename_entry
      @rename_entry ||= Gtk::Entry.new.tap do |entry|
        entry.activates_default = true
        entry.signal_connect('changed') { validate_rename }
        entry.signal_connect('activate') { apply_rename }
      end
    end

    def rename_error_label
      @rename_error_label ||= Gtk::Label.new('This name is already taken').tap do |label|
        label.visible = false
        label.xalign = 0
        label.add_css_class('warning')
        label.add_css_class('caption')
      end
    end

    def rename_button
      @rename_button ||= Gtk::Button.new(label: 'Rename').tap do |button|
        button.add_css_class('suggested-action')
        button.signal_connect('clicked') { apply_rename }
      end
    end

    # The drop target at the end of the bookmarks: dropping a folder on it
    # bookmarks that folder.
    def new_bookmark_row
      @new_bookmark_row ||= Gtk::ListBoxRow.new.tap do |row|
        row.add_css_class('sidebar-new-bookmark-row')
        row.selectable = false
        row.child = new_bookmark_box
        row.add_controller(new_bookmark_drop_target)
      end
    end

    def new_bookmark_box
      @new_bookmark_box ||= Gtk::Box.new(:horizontal, 0).tap do |box|
        box.append(
          Gtk::Image.new.tap do |image|
                    image.icon_name = 'bookmark-new-symbolic'
                    image.margin_end = 8
                  end,
        )
        box.append(
          Gtk::Label.new('Add a new bookmark').tap do |label|
                    label.xalign = 0
                    label.hexpand = true
                  end,
        )
      end
    end

    def new_bookmark_drop_target
      @new_bookmark_drop_target ||= Gtk::DropTarget.new(Gdk::FileList, :copy).tap do |target|
        target.signal_connect('drop') do |_target, value, _x, _y|
          value.files.each { |location| add_bookmark(location) }
          true
        end
      end
    end

    def volume_monitor = @volume_monitor ||= Gio::VolumeMonitor.get

    def actions = @actions ||= Gio::SimpleActionGroup.new

    # --- The places ----------------------------------------------------------

    def built_in_places
      [
        place(
          'Recent',
          'recent:///',
          'document-open-recent-symbolic',
          :built_in,
        ),
        place(
          'Starred',
          'starred:///',
          'starred-symbolic',
          :starred_location,
        ),
        place(
          'Home',
          Gio::File.new_for_path(Dir.home).uri,
          'user-home-symbolic',
          :built_in,
        ),
        desktop_place,
        place(
          'Trash',
          'trash:///',
          'user-trash-symbolic',
          :trash,
        ),
      ].compact
    end

    def desktop_place
      ::File.join(Dir.home, 'Desktop').then do |path|
        if ::File.directory?(path)
          place(
            'Desktop',
            Gio::File.new_for_path(path).uri,
            'user-desktop-symbolic',
            :built_in,
          )
        end
      end
    end

    # The bookmarks file is a list of URIs, each optionally followed by the
    # label to show instead of the folder's name.
    def bookmark_places
      bookmark_lines.filter_map do |line|
        line.split(' ', 2).then do |(uri, label)|
          unless uri.to_s.empty?
            place(
              label || Gio::File.new_for_uri(uri).basename.to_s,
              uri,
              'folder-symbolic',
              :bookmark,
            )
          end
        end
      end
    end

    def bookmark_lines
      if ::File.exist?(BOOKMARKS_FILE)
        ::File.readlines(BOOKMARKS_FILE, chomp: true).reject(&:empty?)
      else
        []
      end
    end

    def device_places
      (volume_places + mount_places + drive_places).uniq { |candidate| candidate.uri }
    end

    def volume_places
      volume_monitor.volumes.map do |volume|
        Place.new(
          label:     volume.name,
          uri:       volume_uri(volume),
          icon_name: icon_name_of(volume.symbolic_icon),
          kind:      :volume,
          tooltip:   volume.name,
          section:   'Device',
          volume:    volume,
          mount:     volume.mount,
          drive:     volume.drive,
        )
      end
    end

    def mount_places
      volume_monitor.mounts.reject { |mount| mount.shadowed? }.map do |mount|
        Place.new(
          label:     mount.name,
          uri:       mount.root.uri,
          icon_name: icon_name_of(mount.symbolic_icon),
          kind:      :mount,
          tooltip:   mount.root.parse_name,
          section:   'Device',
          mount:     mount,
          volume:    mount.volume,
          drive:     mount.drive,
        )
      end
    end

    # A drive with no volumes is still listed, so a removable drive with no
    # media in it can be started or polled.
    def drive_places
      volume_monitor.connected_drives.select { |drive| drive.volumes.empty? }.map do |drive|
        Place.new(
          label:     drive.name,
          uri:       '',
          icon_name: icon_name_of(drive.symbolic_icon),
          kind:      :drive,
          tooltip:   drive.name,
          section:   'Device',
          drive:     drive,
        )
      end
    end

    def network_places
      [place(
        'Network',
        'network:///',
        'network-workgroup-symbolic',
        :network,
        section: 'Network',
      )
]
    end

    private

      def place(label, uri, icon_name, kind, section: nil)
        Place.new(
          label:     label,
          uri:       uri,
          icon_name: icon_name,
          kind:      kind,
          tooltip:   uri,
          section:   section,
        )
      end

      def volume_uri(volume)
        volume.mount.then do |mount|
          if mount.nil?
            ''
          else
            mount.root.uri
          end
        end
      end

      def icon_name_of(icon)
        if icon.respond_to?(:names)
          icon.names.first
        else
          'drive-harddisk-symbolic'
        end
      end

      # Only the rows are cleared. The two popovers are parented to the list
      # box as well, and a popover is not a row, so walking first_child would
      # stall on one.
      def clear
        @last_section = nil
        while (row = list_box.get_row_at_index(0))
          list_box.remove(row)
        end
      end

      # The section headers upstream puts above the device and network rows.
      def append_place(place)
        unless place.section.nil? || @last_section == place.section
          @last_section = place.section
          list_box.append(separator_row)
          list_box.append(section_header_row(place.section))
        end
        SidebarRow.new(place).tap do |row|
          @rows << row
          row.on_eject { |ejected| eject(ejected) }
          list_box.append(row.build)
        end
      end

      def separator_row
        Gtk::ListBoxRow.new.tap do |row|
          row.selectable = false
          row.activatable = false
          row.child = Gtk::Separator.new(:horizontal)
        end
      end

      def section_header_row(title)
        Gtk::ListBoxRow.new.tap do |row|
          row.selectable = false
          row.activatable = false
          row.child = Gtk::Label.new(title).tap do |label|
            label.xalign = 0
            label.add_css_class('heading')
            label.add_css_class('dim-label')
            label.margin_top = 6
          end
        end
      end

      def row_for(list_box_row)
        @rows.find { |row| row.root == list_box_row }
      end

      def open_row(list_box_row)
        row_for(list_box_row).then do |row|
          unless row.nil?
            open_place(row.place)
          end
        end
      end

      def open_place(place)
        if place.mountable?
          mount(place)
        elsif !place.uri.to_s.empty?
          @on_open&.call(place.location)
        end
      end

      def update_selection
        @window_slot&.location.then do |location|
          unless location.nil?
            @rows.each do |row|
              if row.place.uri == location.uri
                list_box.select_row(row.root)
              end
            end
          end
        end
      end

      def secondary_gesture
        @secondary_gesture ||= Gtk::GestureClick.new.tap do |gesture|
          gesture.button = Gdk::BUTTON_SECONDARY
          gesture.signal_connect('pressed') do |_gesture, _n_press, x, y|
            show_row_menu(x, y)
          end
        end
      end

      def long_press_gesture
        @long_press_gesture ||= Gtk::GestureLongPress.new.tap do |gesture|
          gesture.touch_only = true
          gesture.signal_connect('pressed') do |_gesture, x, y|
            show_row_menu(x, y)
          end
        end
      end

      def show_row_menu(x, y)
        row_at(y).then do |row|
          unless row.nil?
            @context_row = row
            @context_place = row.place
            row.has_open_popup = true
            update_action_availability
            row_menu_popover.tap do |popover|
              popover.pointing_to = Gdk::Rectangle.new(
                x.to_i,
                y.to_i,
                1,
                1,
              )
              popover.popup
            end
          end
        end
      end

      def row_at(y)
        list_box.get_row_at_y(y.to_i).then do |list_box_row|
          if list_box_row.nil?
            nil
          else
            row_for(list_box_row)
          end
        end
      end

      # --- The fourteen row actions ---------------------------------------

      def install_actions
        action_handlers.each do |name, handler|
          Gio::SimpleAction.new(name).tap do |action|
            action.signal_connect('activate') { handler.call }
            action_objects[name] = action
            actions.add_action(action)
          end
        end
        list_box.insert_action_group('row', actions)
      end

      def action_objects = @action_objects ||= {}

      def action_handlers
        {
          'open'                   => -> { open_place(@context_place) },
          'open-other'             => -> { @on_open&.call(@context_place.location) },
          'mount'                  => -> { mount(@context_place) },
          'unmount'                => -> { unmount(@context_place) },
          'eject'                  => -> { eject(@context_place) },
          'rescan'                 => -> { rescan(@context_place) },
          'start'                  => -> { start(@context_place) },
          'stop'                   => -> { stop(@context_place) },
          'format'                 => -> { format_drive(@context_place) },
          'remove'                 => -> { remove_bookmark(@context_place) },
          'rename'                 => -> { show_rename_popover },
          'properties'             => -> { @on_properties&.call(@context_place) },
          'empty-trash'            => -> { @on_empty_trash&.call },
          'history-trash-settings' => -> { open_trash_settings },
        }
      end

      # Which of them apply to the row the menu was opened on, which is what
      # `hidden-when: action-disabled` reads.
      def update_action_availability
        availability.each do |name, enabled|
          action_objects[name]&.set_enabled(enabled == true)
        end
      end

      def availability
        @context_place.then do |place|
          {
            'open'                   => !place.uri.to_s.empty?,
            'open-other'             => !place.uri.to_s.empty?,
            'mount'                  => place.mountable?,
            'unmount'                => place.unmountable?,
            'eject'                  => place.ejectable?,
            'rescan'                 => !place.drive.nil? && place.drive.can_poll_for_media?,
            'start'                  => !place.drive.nil? && place.drive.can_start?,
            'stop'                   => !place.drive.nil? && place.drive.can_stop?,
            'format'                 => !place.drive.nil?,
            'remove'                 => place.bookmark?,
            'rename'                 => place.bookmark?,
            'properties'             => !place.uri.to_s.empty?,
            'empty-trash'            => place.kind == :trash,
            'history-trash-settings' => place.kind == :trash,
          }
        end
      end

      # --- Mount operations, with upstream's error wording ------------------

      def mount_operation = Gtk::MountOperation.new(root.root)

      def mount(place)
        place.volume&.mount(:none, mount_operation) do |_volume, result|
          finish_operation(result, "Unable to access “#{place.label}”") { place.volume.mount_finish(result) }
        end
      end

      def unmount(place)
        place.mount&.unmount(:none) do |_mount, result|
          finish_operation(result, "Unable to access “#{place.label}”") { place.mount.unmount_finish(result) }
        end
      end

      def eject(place)
        place.mount&.eject(:none) do |_mount, result|
          finish_operation(result, "Unable to eject “#{place.label}”") { place.mount.eject_finish(result) }
        end
      end

      def rescan(place)
        place.drive&.poll_for_media do |_drive, result|
          finish_operation(result, "Unable to poll “#{place.label}” for media changes") do
            place.drive.poll_for_media_finish(result)
          end
        end
      end

      def start(place)
        place.drive&.start(:none, mount_operation) do |_drive, result|
          finish_operation(result, "Unable to start “#{place.label}”") { place.drive.start_finish(result) }
        end
      end

      def stop(place)
        place.drive&.stop(:none, mount_operation) do |_drive, result|
          finish_operation(result, "Unable to stop “#{place.label}”") { place.drive.stop_finish(result) }
        end
      end

      def format_drive(place)
        unless place.drive.nil?
          @on_format&.call(place)
        end
      end

      def finish_operation(_result, heading)
        yield
        reload
      rescue GLib::Error => error
        UiUtilities.show_ok_dialog(heading, error.message, root.root)
      end

      # --- Bookmarks --------------------------------------------------------

      public

      def add_bookmark(location)
        bookmark_lines.then do |lines|
          unless lines.any? { |line| line.split(' ', 2).first == location.uri }
            write_bookmarks(lines + [location.uri])
          end
        end
        reload
      end

      def remove_bookmark(place)
        write_bookmarks(bookmark_lines.reject { |line| line.split(' ', 2).first == place.uri })
        reload
      end

      private

        def rename_bookmark(place, new_label)
          write_bookmarks(
            bookmark_lines.map do |line|
                        if line.split(' ', 2).first == place.uri
                          "#{place.uri} #{new_label}"
                        else
                          line
                        end
                      end,
          )
          reload
        end

        def write_bookmarks(lines)
          FileUtils.mkdir_p(::File.dirname(BOOKMARKS_FILE))
          ::File.write(BOOKMARKS_FILE, "#{lines.join("\n")}\n")
        end

        def show_rename_popover
          rename_entry.text = @context_place.label
          rename_error_label.visible = false
          rename_button.sensitive = true
          rename_popover.tap do |popover|
            popover.pointing_to = row_menu_popover.pointing_to
            popover.popup
          end
        end

      # The one error state the rename popover has: a label already used by
      # another bookmark.
        def validate_rename
          taken?(rename_entry.text).then do |taken|
            rename_error_label.visible = taken
            rename_button.sensitive = !taken && !rename_entry.text.strip.empty?
          end
        end

        def taken?(label)
          bookmark_places.any? do |candidate|
            candidate.label == label && candidate.uri != @context_place.uri
          end
        end

        def apply_rename
          validate_rename
          if rename_button.sensitive?
            rename_bookmark(@context_place, rename_entry.text.strip)
            rename_popover.popdown
          end
        end

      # row.history-trash-settings opens Settings' privacy panel, which is
      # what nautilus reaches over D-Bus too.
        def open_trash_settings
          DBusLauncher.instance.open_settings_panel('privacy')
        end
  end
end
