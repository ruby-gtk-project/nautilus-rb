# frozen_string_literal: true

require 'adwaita'
require 'fileutils'
require_relative 'directory'
require_relative 'grid_view'
require_relative 'list_view'
require_relative 'floating_bar'
require_relative 'ui_utilities'
require_relative 'file_operations'
require_relative 'clipboard'
require_relative 'mime_actions'
require_relative 'dbus_launcher'
require_relative 'new_folder_dialog'
require_relative 'rename_file_popover'
require_relative 'select_items_dialog'
require_relative 'column_chooser'
require_relative 'grid_view_captions_dialog'
require_relative 'error_reporting'
require_relative 'global_preferences'
require_relative 'location_banner'

module Nautilus
  # FilesView hosts the grid or list view, the floating status bar and the
  # two context menus, and owns the `view.*` action group.
  #
  # Ported from src/resources/ui/nautilus-files-view.blp,
  # src/nautilus-files-view.c and
  # src/resources/menu/nautilus-files-view-context-menus.ui. The menu models
  # are upstream's, item for item, and every item is `hidden-when:
  # action-disabled` exactly as the .ui has it — so a menu item whose action
  # this port does not install, such as the archive and properties ones,
  # hides itself the same way it does upstream when the feature is
  # unavailable.
  class FilesView
    # background-menu: five sections, with the extension section left empty
    # because a Ruby port has no NautilusMenuProvider ABI to fill it from.
    BACKGROUND_MENU = [
      {
        section: [
          { label: 'New _Folder…', action: 'view.new-folder', accel: '<shift><control>n' },
          {
            label:     'New _Document',
            item_name: 'templates-submenu',
            submenu:   [{ label: 'Empty Document', action: 'view.template-empty' }],
          },
          {
            label:       'Open _With…',
            action:      'view.open-current-directory-with-other-application',
            hidden_when: 'action-disabled',
          },
          {
            label:       'Open in Consol_e',
            action:      'view.current-directory-console',
            hidden_when: 'action-disabled',
          },
        ],
      },
      {
        section: [
          { label: '_Paste', action: 'view.paste' },
          { label: 'Paste as _Link', action: 'view.create-link', hidden_when: 'action-disabled' },
          { label: 'Select _All', action: 'view.select-all' },
        ],
      },
      {
        section: [
          { label: 'Empty _Trash…', action: 'view.empty-trash', hidden_when: 'action-disabled' },
        ],
      },
      { section: [] },
      {
        section: [
          {
            label:       'P_roperties',
            action:      'view.current-directory-properties',
            hidden_when: 'action-disabled',
          },
        ],
      },
    ].freeze

    # selection-menu: nine sections. The open submenu, the drive section, the
    # move/copy section, the file-actions section and the network section are
    # upstream's, as are the three extension slots, which stay empty.
    SELECTION_MENU = [
      { section: [] },
      {
        section: [
          { label: '_Extract', action: 'view.extract-here', hidden_when: 'action-disabled' },
          { label: 'E_xtract to…', action: 'view.extract-to', hidden_when: 'action-disabled' },
          {
            label:       'Open _With…',
            action:      'view.open-with-other-application',
            hidden_when: 'action-disabled',
            item_name:   'open_with_in_main_menu',
          },
          {
            label:       '_Run as a Program',
            action:      'view.run-in-terminal',
            hidden_when: 'action-disabled',
          },
        ],
      },
      {
        section: [
          {
            label:     '_Open',
            item_name: 'open_in_view_submenu',
            submenu:   [
              {
                section: [
                  {
                    label:       'Open',
                    action:      'view.open-with-default-application',
                    hidden_when: 'action-disabled',
                  },
                  {
                    label:       'Open in New _Tab',
                    action:      'view.open-item-new-tab',
                    hidden_when: 'action-disabled',
                  },
                  {
                    label:       'Open in New _Window',
                    action:      'view.open-item-new-window',
                    hidden_when: 'action-disabled',
                  },
                ],
              },
              {
                section: [
                  {
                    label:       'Open _With…',
                    action:      'view.open-with-other-application',
                    hidden_when: 'action-disabled',
                  },
                  {
                    label:       'Open in Consol_e',
                    action:      'view.console',
                    hidden_when: 'action-disabled',
                  },
                ],
              },
            ],
          },
          {
            label:       '_Open Item Location',
            action:      'view.open-item-location',
            hidden_when: 'action-disabled',
          },
        ],
      },
      {
        section: [
          {
            label:     '_Scripts',
            item_name: 'scripts-submenu',
            submenu:   [
              { section: [] },
              {
                section: [
                  {
                    label:       '_Open Scripts Folder',
                    action:      'view.open-scripts-folder',
                    hidden_when: 'action-disabled',
                  },
                ],
              },
            ],
          },
        ],
      },
      {
        section: [
          { label: '_Mount', action: 'view.mount-volume', hidden_when: 'action-disabled' },
          { label: '_Unmount', action: 'view.unmount-volume', hidden_when: 'action-disabled' },
          { label: '_Eject', action: 'view.eject-volume', hidden_when: 'action-disabled' },
          { label: '_Start', action: 'view.start-volume', hidden_when: 'action-disabled' },
          { label: '_Stop', action: 'view.stop-volume', hidden_when: 'action-disabled' },
          { label: '_Detect Media', action: 'view.detect-media', hidden_when: 'action-disabled' },
        ],
      },
      {
        section: [
          { label: 'Cu_t', action: 'view.cut' },
          { label: '_Copy', action: 'view.copy' },
          { label: 'Move to…', action: 'view.move-to' },
          { label: 'Copy to…', action: 'view.copy-to' },
        ],
      },
      {
        section: [
          { label: 'Rena_me…', action: 'view.rename' },
          { label: '_Paste Into Folder', action: 'view.paste-into', hidden_when: 'action-disabled' },
          {
            label:       'Create _Link',
            action:      'view.create-link-in-place',
            hidden_when: 'action-disabled',
          },
          { label: 'C_ompress…', action: 'view.compress', hidden_when: 'action-disabled' },
          {
            label:       'Set as Background…',
            action:      'view.set-as-wallpaper',
            hidden_when: 'action-disabled',
          },
          { label: 'Email…', action: 'view.send-email', hidden_when: 'action-disabled' },
          { label: 'Mo_ve to Trash', action: 'view.move-to-trash', hidden_when: 'action-disabled' },
          {
            label:       '_Delete From Trash…',
            action:      'view.delete-from-trash',
            hidden_when: 'action-disabled',
          },
          {
            label:       '_Delete Permanently…',
            action:      'view.delete-permanently-menu-item',
            hidden_when: 'action-disabled',
          },
          {
            label:       '_Delete Permanently…',
            action:      'view.permanent-delete-permanently-menu-item',
            hidden_when: 'action-disabled',
          },
          {
            label:       '_Restore From Trash',
            action:      'view.restore-from-trash',
            hidden_when: 'action-disabled',
          },
          {
            label:       '_Remove From Recent',
            action:      'view.remove-from-recent',
            hidden_when: 'action-disabled',
          },
          { label: 'Star', action: 'view.star', hidden_when: 'action-disabled' },
          { label: 'Unstar', action: 'view.unstar', hidden_when: 'action-disabled' },
        ],
      },
      {
        section: [
          { label: '_Copy Address', action: 'view.copy-network-address' },
          {
            label:       '_Remove',
            action:      'view.remove-recent-server',
            hidden_when: 'action-disabled',
          },
        ],
      },
      { section: [] },
      {
        section: [
          { label: 'P_roperties', action: 'view.properties', hidden_when: 'action-disabled' },
        ],
      },
    ].freeze

    def initialize(directory:, on_open_location: nil, on_open_in_new_tab: nil, on_open_in_new_window: nil)
      @directory = directory
      @on_open_location = on_open_location
      @on_open_in_new_tab = on_open_in_new_tab
      @on_open_in_new_window = on_open_in_new_window
      @mode = default_mode
      @loading = false
    end

    attr_reader :directory, :mode

    def build
      root.tap do |bin|
        bin.child = overlay

        overlay.tap do |widget|
          widget.child = current_view.build
          widget.add_overlay(floating_bar.build)
        end

        background_menu_popover.set_parent(overlay)
        selection_menu_popover.set_parent(overlay)
        rename_popover.build

        install_actions
        reload
      end
    end

    def root
      @root ||= Adwaita::Bin.new.tap do |bin|
        bin.hexpand = true
        bin.vexpand = true
      end
    end

    def overlay
      @overlay ||= Gtk::Overlay.new.tap do |widget|
        widget.hexpand = true
        widget.vexpand = true
      end
    end

    def floating_bar
      @floating_bar ||= FloatingBar.new(on_stop: -> { stop_loading })
    end

    def grid_view
      @grid_view ||= GridView.new(
        directory:            @directory,
        on_activate:          ->(file) { activate(file) },
        on_context_menu:      ->(file, x, y) { show_context_menu(file, x, y) },
        on_selection_changed: ->(files) { on_selection_changed(files) },
      )
    end

    def list_view
      @list_view ||= ListView.new(
        directory:            @directory,
        on_activate:          ->(file) { activate(file) },
        on_context_menu:      ->(file, x, y) { show_context_menu(file, x, y) },
        on_selection_changed: ->(files) { on_selection_changed(files) },
      )
    end

    def current_view
      if @mode == :list
        list_view
      else
        grid_view
      end
    end

    # slot.files-view-mode / slot.files-view-mode-toggle land here.
    def mode=(mode)
      unless @mode == mode
        @mode = mode
        GlobalPreferences.instance.preferences['default-folder-viewer'] = viewer_name(mode)
        overlay.child = current_view.build
        current_view.directory = @directory
        refresh_action_availability
      end
      mode
    end

    def toggle_mode
      if @mode == :list
        self.mode = :grid
      else
        self.mode = :list
      end
    end

    # Only a view that has already been built is handed the new location;
    # the other one picks it up when it is next switched to.
    def directory=(directory)
      @directory = directory
      unless @grid_view.nil?
        @grid_view.directory = directory
      end
      unless @list_view.nil?
        @list_view.directory = directory
      end
      reload
      directory
    end

    def selected_files = current_view.selected_files

    def actions = @actions ||= Gio::SimpleActionGroup.new

    def background_menu_popover
      @background_menu_popover ||= Gtk::PopoverMenu.new(UiUtilities.build_menu(BACKGROUND_MENU))
    end

    def selection_menu_popover
      @selection_menu_popover ||= Gtk::PopoverMenu.new(UiUtilities.build_menu(SELECTION_MENU))
    end

    def rename_popover
      @rename_popover ||= RenameFilePopover.new(
        on_accept: ->(file, new_name) { apply_rename(file, new_name) },
      )
    end

    def clipboard = @clipboard ||= Clipboard.for_display

    def window = root.root

    # Loads the location and updates the floating bar, which is where the
    # `loading` property the blueprint binds to the spinner comes from.
    def reload
      @loading = true
      update_floating_bar
      @directory.load
      @directory.monitor
      @loading = false
      update_floating_bar
      refresh_action_availability
    end

    def stop_loading
      @loading = false
      update_floating_bar
    end

    # view.empty-trash, which the trash banner's button also calls.
    def empty_trash
      FileOperations.empty_trash(parent: window) { reload }
    end

    private

      def default_mode
        if GlobalPreferences.instance.preferences['default-folder-viewer'] == 'list-view'
          :list
        else
          :grid
        end
      end

      def viewer_name(mode)
        if mode == :list
          'list-view'
        else
          'icon-view'
        end
      end



      def activate(file)
        unless file.nil?
          if MimeActions.opens_in_view?(file)
            @on_open_location&.call(file.location)
          else
            MimeActions.activate_file(
              file,
              parent:           window,
              on_open_location: ->(location) { @on_open_location&.call(location) },
            )
          end
        end
      end

      def on_selection_changed(_files)
        update_floating_bar
        refresh_action_availability
      end

      # The floating bar's status line: the item count, or the selection's
      # size, which is what real_update_status() reports.
      def update_floating_bar
        floating_bar.show_spinner = @loading
        floating_bar.show_stop = @loading
        floating_bar.primary_label_text = status_text
        floating_bar.details_label_text = details_text
      end

      def status_text
        if @loading
          'Loading…'
        elsif selected_files.empty?
          item_count_text(@directory.visible_files.size)
        else
          selection_text
        end
      end

      def item_count_text(count)
        if count == 1
          '1 item'
        else
          "#{count} items"
        end
      end

      def selection_text
        selected_files.then do |files|
          if files.size == 1
            files.first.display_name
          else
            "#{files.size} items selected"
          end
        end
      end

      def details_text
        selected_files.reject(&:directory?).sum(&:size).then do |bytes|
          if bytes.zero?
            ''
          else
            GLib.format_size(bytes)
          end
        end
      end

      # --- Context menus ---------------------------------------------------

      def show_context_menu(file, x, y)
        unless file.nil?
          current_view.select_file(file)
        end
        refresh_action_availability
        popover_for(file).tap do |popover|
          popover.pointing_to = Gdk::Rectangle.new(
            x.to_i,
            y.to_i,
            1,
            1,
          )
          popover.popup
        end
      end

      def popover_for(file)
        if file.nil?
          background_menu_popover
        else
          selection_menu_popover
        end
      end

      # --- The view action group -------------------------------------------

      def install_actions
        simple_actions.each do |name, handler|
          add_action(
            name,
            Gio::SimpleAction.new(name).tap do |action|
                        action.signal_connect('activate') { handler.call }
                      end,
          )
        end
        add_action('sort', sort_action)
        add_action('show-hidden-files', show_hidden_action)
        root.insert_action_group('view', actions)
        refresh_action_availability
      end

      # The actions are kept by name as well as handed to the group, so
      # enabling one does not have to look it back up out of GTK.
      def add_action(name, action)
        action_objects[name] = action
        actions.add_action(action)
      end

      def action_objects = @action_objects ||= {}

      # The `view.*` actions this port installs. Those upstream also has but
      # whose backends are not ported are deliberately absent, so their menu
      # items hide themselves through `hidden-when: action-disabled`.
      def simple_actions
        {
          'new-folder'                             => -> { new_folder },
          'new-folder-with-selection'              => -> { new_folder(with_selection: true) },
          'template-empty'                         => -> { new_empty_document },
          'open-with-default-application'          => -> { open_selection },
          'open-item-new-tab'                      => -> { open_selection_in_new_tab },
          'open-item-new-window'                   => -> { open_selection_in_new_window },
          'open-item-location'                     => -> { open_item_location },
          'open-scripts-folder'                    => -> { open_scripts_folder },
          'console'                                => -> { open_console(selected_files.first&.location) },
          'current-directory-console'              => -> { open_console(@directory.location) },
          'run-in-terminal'                        => -> { open_console(selected_files.first&.location) },
          'cut'                                    => -> { clipboard.cut(selected_files) },
          'copy'                                   => -> { clipboard.copy(selected_files) },
          'paste'                                  => -> { paste_into(@directory.location) },
          'paste-into'                             => -> { paste_into(selected_files.first&.location) },
          'move-to'                                => -> { choose_destination(move: true) },
          'copy-to'                                => -> { choose_destination(move: false) },
          'copy-current-location'                  => -> { copy_text(@directory.uri) },
          'copy-network-address'                   => -> { copy_text(selected_files.first&.uri.to_s) },
          'create-link'                            => -> { create_links_from_clipboard },
          'create-link-in-place'                   => -> { create_links(selected_files) },
          'rename'                                 => -> { rename_selection },
          'move-to-trash'                          => -> { trash_selection },
          'delete-from-trash'                      => -> { delete_selection },
          'delete-permanently-menu-item'           => -> { delete_selection },
          'permanent-delete-permanently-menu-item' => -> { delete_selection },
          'delete-permanently-shortcut'            => -> { delete_selection },
          'restore-from-trash'                     => -> { restore_selection },
          'empty-trash'                            => -> { empty_trash },
          'star'                                   => -> { set_starred(true) },
          'unstar'                                 => -> { set_starred(false) },
          'select-all'                             => -> { current_view.select_all },
          'invert-selection'                       => -> { current_view.invert_selection },
          'select-pattern'                         => -> { select_pattern },
          'send-email'                             => -> { send_email },
          'zoom-in'                                => -> { current_view.zoom_in },
          'zoom-out'                               => -> { current_view.zoom_out },
          'zoom-standard'                          => -> { current_view.zoom_standard },
          'visible-columns'                        => -> { show_column_chooser },
          'visible-captions'                       => -> { show_captions_dialog },
          'popup-menu'                             => -> { show_context_menu(selected_files.first, 0, 0) },
        }
      end

      # view.sort takes the attribute and whether to reverse it, which is the
      # (sb) target the sort section's items carry.
      def sort_action
        Gio::SimpleAction.new('sort', GLib::VariantType.new('(sb)')).tap do |action|
          action.signal_connect('activate') do |_action, parameter|
            apply_sort(parameter)
          end
        end
      end

      # A GVariant parameter reaches a Ruby activate handler already unpacked:
      # a tuple arrives as an Array, a string as a String.
      def apply_sort(parameter)
        Array(parameter).then do |(attribute, reversed)|
          @directory.sort(attribute: attribute, reversed: reversed)
        end
      end

      # view.show-hidden-files is a stateful toggle, as the accel '<control>h'
      # on the menu item implies.
      def show_hidden_action
        Gio::SimpleAction.new(
          'show-hidden-files',
          nil,
          GLib::Variant.parse(show_hidden_text),
        ).tap do |action|
          action.signal_connect('activate') do
            toggle_show_hidden(action)
          end
        end
      end

      def show_hidden_text
        if GlobalPreferences.instance.file_chooser['show-hidden']
          'true'
        else
          'false'
        end
      end

      def toggle_show_hidden(action)
        (!GlobalPreferences.instance.file_chooser['show-hidden']).then do |show|
          GlobalPreferences.instance.file_chooser['show-hidden'] = show
          @directory.show_hidden = show
          action.set_state(GLib::Variant.parse(show.to_s))
        end
      end

      # Which actions apply right now, which is what every
      # `hidden-when: action-disabled` item reads.
      def refresh_action_availability
        availability.each do |name, enabled|
          action_objects[name]&.set_enabled(enabled == true)
        end
      end

      def availability
        selected_files.then do |files|
          {
            'open-with-default-application'          => !files.empty?,
            'open-item-new-tab'                      => files.any?(&:directory?),
            'open-item-new-window'                   => files.any?(&:directory?),
            'open-item-location'                     => (@directory.recent? || @directory.starred?) && !files.empty?,
            'console'                                => DBusLauncher.instance.available?(:console) && files.any?(&:directory?),
            'current-directory-console'              => DBusLauncher.instance.available?(:console),
            'run-in-terminal'                        => DBusLauncher.instance.available?(:console) &&
              files.any?(&:can_execute?),
            'cut'                                    => !files.empty?,
            'copy'                                   => !files.empty?,
            'paste-into'                             => files.size == 1 && files.first.directory?,
            'move-to'                                => !files.empty?,
            'copy-to'                                => !files.empty?,
            'copy-network-address'                   => !files.empty? && @directory.network?,
            'create-link'                            => GlobalPreferences.instance.preferences['show-create-link'],
            'create-link-in-place'                   => !files.empty? &&
              GlobalPreferences.instance.preferences['show-create-link'],
            'rename'                                 => files.size == 1 && files.first.can_rename?,
            'move-to-trash'                          => !files.empty? && !@directory.trash? && files.all?(&:can_trash?),
            'delete-from-trash'                      => !files.empty? && @directory.trash?,
            'delete-permanently-menu-item'           => !files.empty? && !@directory.trash? &&
              GlobalPreferences.instance.preferences['show-delete-permanently'],
            'permanent-delete-permanently-menu-item' => !files.empty? && !@directory.trash? &&
              files.none?(&:can_trash?),
            'restore-from-trash'                     => !files.empty? && @directory.trash?,
            'empty-trash'                            => @directory.trash?,
            'star'                                   => !files.empty? && files.none?(&:starred?),
            'unstar'                                 => !files.empty? && files.all?(&:starred?),
            'send-email'                             => !files.empty? && files.none?(&:directory?),
            'zoom-in'                                => current_view.can_zoom_in?,
            'zoom-out'                               => current_view.can_zoom_out?,
            'visible-columns'                        => @mode == :list,
            'visible-captions'                       => @mode == :grid,
            'popup-menu'                             => !files.empty?,
          }
        end
      end

      # --- What the actions do ----------------------------------------------

      def new_folder(with_selection: false)
        NewFolderDialog.new(
          containing_directory: @directory.location,
          with_selection:       with_selection,
          on_accept:            ->(name, selection) { create_folder(name, selection) },
        ).tap do |dialog|
          dialog.build
          dialog.present(window)
        end
      end

      def create_folder(name, with_selection)
        FileOperations.new_folder(@directory.location, name, parent: window).then do |folder|
          unless folder.nil?
            if with_selection
              FileOperations.move(selected_files.map(&:location), folder, parent: window)
            end
            reload
          end
        end
      end

      def new_empty_document
        FileOperations.new_file(@directory.location, 'Untitled Document', parent: window)
        reload
      end

      def open_selection
        MimeActions.activate_files(
          selected_files,
          parent:             window,
          on_open_location:   ->(location) { @on_open_location&.call(location) },
          on_open_in_new_tab: ->(location) { @on_open_in_new_tab&.call(location) },
        )
      end

      def open_selection_in_new_tab
        selected_files.select(&:directory?).each do |file|
          @on_open_in_new_tab&.call(file.location)
        end
      end

      def open_selection_in_new_window
        selected_files.select(&:directory?).each do |file|
          @on_open_in_new_window&.call(file.location)
        end
      end

      def open_item_location
        selected_files.first&.location&.parent.then do |parent_location|
          unless parent_location.nil?
            @on_open_location&.call(parent_location)
          end
        end
      end

      def open_scripts_folder
        FileUtils.mkdir_p(LocationBanner::SCRIPTS_PATH)
        @on_open_location&.call(Gio::File.new_for_path(LocationBanner::SCRIPTS_PATH))
      end

      def open_console(location)
        unless location.nil?
          DBusLauncher.instance.open_console(location.uri)
        end
      end

      def paste_into(location)
        unless location.nil?
          clipboard.read do |contents|
            unless contents.nil?
              paste_contents(contents, location)
            end
          end
        end
      end

      def paste_contents(contents, location)
        if contents[:cut]
          FileOperations.move(contents[:locations], location, parent: window) { reload }
        else
          FileOperations.copy(contents[:locations], location, parent: window) { reload }
        end
      end

      # view.create-link pastes the clipboard as links, which is what
      # "Paste as Link" means.
      def create_links_from_clipboard
        clipboard.read do |contents|
          unless contents.nil?
            FileOperations.create_links(
              contents[:locations],
              @directory.location,
              parent: window,
            ) { reload }
          end
        end
      end

      def create_links(files)
        FileOperations.create_links(
          files.map(&:location),
          @directory.location,
          parent: window,
        ) { reload }
      end

      def choose_destination(move:)
        Gtk::FileDialog.new.tap do |dialog|
          dialog.title = destination_title(move)
          dialog.select_folder(window, nil) do |_dialog, result|
            transfer_to(dialog.select_folder_finish(result), move)
          end
        end
      rescue GLib::Error
        nil
      end

      def destination_title(move)
        if move
          'Select Move Destination'
        else
          'Select Copy Destination'
        end
      end

      def transfer_to(destination, move)
        unless destination.nil?
          if move
            FileOperations.move(selected_files.map(&:location), destination, parent: window)
          else
            FileOperations.copy(selected_files.map(&:location), destination, parent: window)
          end
          reload
        end
      rescue GLib::Error
        nil
      end

      def copy_text(text)
        clipboard.clipboard.set(text.to_s)
      end

      def rename_selection
        selected_files.first.then do |file|
          unless file.nil?
            rename_popover.show_for(file, @directory.location, overlay)
          end
        end
      end

      def apply_rename(file, new_name)
        FileOperations.rename(file.location, new_name)
        reload
      rescue GLib::Error => error
        ErrorReporting.report_error_renaming_file(
          file.display_name,
          new_name,
          error,
          window,
        )
      end

      def trash_selection
        FileOperations.trash(selected_files.map(&:location), parent: window) { reload }
      end

      def delete_selection
        FileOperations.delete(selected_files.map(&:location), parent: window) { reload }
      end

      # view.restore-from-trash puts each item back where trash::orig-path
      # says it came from.
      def restore_selection
        selected_files.each do |file|
          file.trash_orig_path.then do |original|
            unless original.nil?
              file.location.move(Gio::File.new_for_path(original), :nofollow_symlinks)
            end
          end
        end
        reload
      rescue GLib::Error => error
        ErrorReporting.report_error_loading_directory(@directory.display_name, error, window)
      end

      def set_starred(starred)
        selected_files.each { |file| file.starred = starred }
        reload
      end

      def select_pattern
        SelectItemsDialog.new(
          on_select: ->(pattern) { current_view.select_pattern(pattern) },
        ).tap do |dialog|
          dialog.build
          dialog.present(window)
        end
      end

      def send_email
        selected_files.map { |file| "attach=#{file.uri}" }.join('&').then do |attachments|
          Gtk::UriLauncher.new("mailto:?#{attachments}").launch(window, nil)
        end
      rescue GLib::Error
        nil
      end

      def show_column_chooser
        ColumnChooser.new(directory: @directory, on_changed: -> { list_view.apply_columns_settings })
                     .tap do |dialog|
          dialog.build
          dialog.present(window)
        end
      end

      def show_captions_dialog
        GridViewCaptionsDialog.new(on_changed: ->(captions) { grid_view.captions = captions })
                              .tap do |dialog|
          dialog.build
          dialog.present(window)
        end
      end
  end
end
