# frozen_string_literal: true

require 'adwaita'
require_relative 'window_slot'
require_relative 'toolbar'
require_relative 'sidebar'
require_relative 'network_address_bar'
require_relative 'history_controls'
require_relative 'view_controls'
require_relative 'ui_utilities'
require_relative 'global_preferences'
require_relative 'shortcut_manager'

module Nautilus
  # Window is the main window: the tabs, the sidebar and the header bars.
  #
  # Ported from src/resources/ui/nautilus-window.blp and
  # nautilus-window.c. The widget tree is the blueprint's — a toast overlay
  # holding a tab overview, holding an overlay split view whose sidebar is
  # the places list and whose content is the toolbar, the tab bar and the tab
  # view, with a narrow-window action bar carrying the history and view
  # controls. The breakpoint's nine setters fire at the same 682sp, and the
  # three menu models are this file's too.
  class Window
    # app_menu: three sections, with the undo/redo section in the middle.
    APP_MENU = [
      {
        section: [
          {
            label:     'New _Window',
            action:    'app.clone-window',
            verb_icon: 'window-new-symbolic',
          },
          { label: 'New _Tab', action: 'win.new-tab', verb_icon: 'tab-new-symbolic' },
          { label: 'Show All Ta_bs', action: 'win.open-tab-overview' },
        ],
      },
      {
        section: [
          { label: '_Undo', action: 'win.undo' },
          { label: '_Redo', action: 'win.redo' },
        ],
      },
      {
        section: [
          { label: '_Preferences', action: 'app.preferences' },
          { label: '_Keyboard Shortcuts', action: 'app.shortcuts' },
          { label: '_Help', action: 'app.help' },
          { label: '_About Files', action: 'app.about' },
        ],
      },
    ].freeze

    TAB_MENU = [
      {
        section: [
          { label: '_New Tab', action: 'win.new-tab' },
          { label: 'Re_store Closed Tab', action: 'win.restore-tab' },
        ],
      },
      {
        section: [
          { label: 'Move Tab to New _Window', action: 'win.tab-move-new-window' },
          { label: 'Move Tab _Left', action: 'win.tab-move-left' },
          { label: 'Move Tab _Right', action: 'win.tab-move-right' },
        ],
      },
      {
        section: [
          { label: '_Close Tab', action: 'win.close-current-view' },
          { label: 'Close _Other Tabs', action: 'win.close-other-tabs' },
        ],
      },
    ].freeze

    TAB_OVERVIEW_MENU = [
      {
        section: [
          { label: 'New _Window', action: 'app.clone-window' },
          { label: 'Re_store Closed Tab', action: 'win.restore-tab' },
        ],
      },
    ].freeze

    BREAKPOINT_CONDITION = 'max-width: 682sp'

    def initialize(app, location: nil, on_new_window: nil)
      @app = app
      @initial_location = location
      @on_new_window = on_new_window
      @slots = {}
      @closed_locations = []
    end

    attr_reader :app

    def build
      window.tap do |win|
        win.content = shortcut_manager

        shortcut_manager.child = toast_overlay

        toast_overlay.child = tab_overview

        tab_overview.tap do |overview|
          overview.view = tab_view
          overview.enable_new_tab = true
          overview.secondary_menu = UiUtilities.build_menu(TAB_OVERVIEW_MENU)
          overview.child = split_view
          overview.signal_connect('create-tab') { create_tab }
        end

        split_view.tap do |view|
          view.sidebar = sidebar_toolbar_view
          view.content = content_toolbar_view
        end

        sidebar_toolbar_view.tap do |view|
          view.add_top_bar(sidebar_header_bar)
          view.content = sidebar.build
        end

        sidebar_header_bar.tap do |header|
          header.pack_start(search_everywhere_button)
          header.title_widget = Adwaita::WindowTitle.new('Files', '')
          header.pack_end(main_menu_button)
        end

        content_toolbar_view.tap do |view|
          view.add_top_bar(toolbar.build)
          view.add_top_bar(tab_bar)
          view.add_top_bar(network_address_bar.build)
          view.content = tab_view
          view.add_bottom_bar(action_bar)
        end

        tab_bar.view = tab_view

        tab_view.tap do |view|
          view.menu_model = UiUtilities.build_menu(TAB_MENU)
          view.signal_connect('close-page') { |_view, page| on_close_page(page) }
          view.signal_connect('notify::selected-page') { on_selected_page_changed }
          view.signal_connect('create-window') { on_create_window }
        end

        action_bar.tap do |bar|
          bar.pack_start(action_bar_history_controls.build)
          bar.pack_end(action_bar_view_controls.build)
          bar.pack_end(tab_button)
        end

        tab_button.view = tab_view

        win.add_breakpoint(breakpoint)

        install_actions
        open_initial_tab
      end
    end

    def present
      window.present
    end

    # Adwaita::ApplicationWindow is what the blueprint's template root is,
    # and it is the one Adwaita window type that takes `content`.
    def window
      @window ||= Adwaita::ApplicationWindow.new(@app).tap do |win|
        win.set_default_size(890, 550)
        win.height_request = 294
        win.width_request = 360
        win.show_menubar = false
        win.add_css_class('view')
        GlobalPreferences.instance.apply_to(win)
      end
    end

    def shortcut_manager = @shortcut_manager ||= ShortcutManager.new

    def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new

    def tab_overview = @tab_overview ||= Adwaita::TabOverview.new

    def split_view
      @split_view ||= Adwaita::OverlaySplitView.new.tap do |view|
        view.enable_show_gesture = false
        view.enable_hide_gesture = false
        view.sidebar_width_fraction = 0.2
      end
    end

    def sidebar_toolbar_view = @sidebar_toolbar_view ||= Adwaita::ToolbarView.new

    def sidebar_header_bar = @sidebar_header_bar ||= Adwaita::HeaderBar.new

    def search_everywhere_button
      @search_everywhere_button ||= Gtk::ToggleButton.new.tap do |button|
        button.tooltip_text = 'Search Everywhere'
        button.action_name = 'slot.search-global'
        button.icon_name = 'edit-find-symbolic'
      end
    end

    def main_menu_button
      @main_menu_button ||= Gtk::MenuButton.new.tap do |button|
        button.tooltip_text = 'Main Menu'
        button.icon_name = 'open-menu-symbolic'
        button.menu_model = UiUtilities.build_menu(APP_MENU)
      end
    end

    def sidebar
      @sidebar ||= Sidebar.new(
        on_open:        ->(location) { open_location(location) },
        on_empty_trash: -> { active_slot&.files_view&.empty_trash },
      )
    end

    def content_toolbar_view = @content_toolbar_view ||= Adwaita::ToolbarView.new

    def toolbar
      @toolbar ||= Toolbar.new(
        on_sidebar_toggled: ->(active) { split_view.show_sidebar = active },
      )
    end

    # Shown only while browsing network:///, below the toolbar, as
    # nautilus-window.c's `gtk_widget_set_visible (window->network_address_bar,
    # g_file_has_uri_scheme (location, SCHEME_NETWORK_VIEW))` does.
    def network_address_bar
      @network_address_bar ||= NetworkAddressBar.new(
        on_open_location: ->(uri) { active_slot&.open_location(Gio::File.new_for_uri(uri)) },
      )
    end

    def tab_bar = @tab_bar ||= Adwaita::TabBar.new

    def tab_view = @tab_view ||= Adwaita::TabView.new

    def action_bar
      @action_bar ||= Gtk::ActionBar.new.tap do |bar|
        bar.revealed = false
      end
    end

    def action_bar_history_controls = @action_bar_history_controls ||= HistoryControls.new

    def action_bar_view_controls = @action_bar_view_controls ||= ViewControls.new

    def tab_button
      @tab_button ||= Adwaita::TabButton.new.tap do |button|
        button.action_name = 'win.open-tab-overview'
      end
    end

    # The breakpoint's nine setters, at the blueprint's 682sp.
    def breakpoint
      @breakpoint ||= Adwaita::Breakpoint.new(
        Adwaita::BreakpointCondition.parse(BREAKPOINT_CONDITION),
      ).tap do |point|
        # adw_breakpoint_add_setter() needs a GValue the Ruby bindings do not
        # build, so the nine setters are applied from the breakpoint's own
        # apply and unapply signals instead.
        point.signal_connect('apply') { apply_narrow_layout(true) }
        point.signal_connect('unapply') { apply_narrow_layout(false) }
      end
    end

    def actions = @actions ||= Gio::SimpleActionGroup.new

    def active_slot
      tab_view.selected_page.then do |page|
        if page.nil?
          nil
        else
          @slots[page]
        end
      end
    end

    # nautilus_window_open_location_full(): the active tab goes there.
    def open_location(location)
      if active_slot.nil?
        open_new_tab(location)
      else
        active_slot.open_location(location)
        on_slot_changed(active_slot)
      end
    end

    # Returns the tab page, which is what the tab overview's create-tab
    # handler has to hand back.
    def open_new_tab(location)
      new_slot(location).then do |slot|
        tab_view.append(slot.build).tap do |page|
          @slots[page] = slot
          page.title = slot.title
          tab_view.selected_page = page
          on_slot_changed(slot)
        end
      end
    end

    private

      def open_initial_tab
        open_new_tab(@initial_location || Gio::File.new_for_path(Dir.home))
      end

      def new_slot(location)
        WindowSlot.new(
          location:              location,
          on_title_changed:      ->(slot) { on_slot_changed(slot) },
          on_open_in_new_tab:    ->(target) { open_new_tab(target) },
          on_open_in_new_window: ->(target) { @on_new_window&.call(target) },
          on_bookmark:           ->(target) { sidebar.add_bookmark(target) },
          on_unbookmark:         ->(target) { unbookmark(target) },
        )
      end

      def unbookmark(target)
        sidebar.bookmark_places.find { |place| place.uri == target.uri }.then do |place|
          unless place.nil?
            sidebar.remove_bookmark(place)
          end
        end
      end

      def create_tab
        open_new_tab(active_slot&.location || Gio::File.new_for_path(Dir.home))
      end

      def on_close_page(page)
        @slots[page].then do |slot|
          unless slot.nil?
            @closed_locations.push(slot.location)
            slot.close
            @slots.delete(page)
          end
        end
        tab_view.close_page_finish(page, true)
        true
      end

      def on_selected_page_changed
        active_slot.then do |slot|
          unless slot.nil?
            on_slot_changed(slot)
          end
        end
      end

      def on_create_window
        @on_new_window&.call(active_slot&.location)
        nil
      end

      # The window's title, the tab's title and the three controls that bind
      # to the active slot all follow it.
      def on_slot_changed(slot)
        window.title = slot.title
        tab_view.selected_page&.title = slot.title
        toolbar.window_slot = slot
        action_bar_history_controls.window_slot = slot
        action_bar_view_controls.window_slot = slot
        sidebar.window_slot = slot
        network_address_bar.root.visible = slot.location.uri_scheme == 'network'
      end

      # The nine setters the blueprint's breakpoint carries.
      def apply_narrow_layout(narrow)
        split_view.collapsed = narrow
        split_view.enable_show_gesture = narrow
        split_view.enable_hide_gesture = narrow
        split_view.sidebar_width_unit = sidebar_width_unit(narrow)
        action_bar.revealed = narrow
        tab_bar.visible = !narrow
        toolbar.show_sidebar_button = narrow
        toolbar.show_view_controls = !narrow
        toolbar.show_history_controls = !narrow
      end

      def sidebar_width_unit(narrow)
        if narrow
          :px
        else
          :sp
        end
      end

      # --- The win action group ---------------------------------------------

      def install_actions
        simple_actions.each do |name, handler|
          actions.add_action(
            Gio::SimpleAction.new(name).tap do |action|
                        action.signal_connect('activate') { handler.call }
                      end,
          )
        end
        actions.add_action(go_to_tab_action)
        window.insert_action_group('win', actions)
      end


      def simple_actions
        {
          'new-tab'               => -> { open_new_tab(active_slot&.location) },
          'open-tab-overview'     => -> { tab_overview.open = true },
          'close-current-view'    => -> { close_current_view },
          'close-other-tabs'      => -> { close_other_tabs },
          'restore-tab'           => -> { restore_tab },
          'tab-move-left'         => -> { move_tab(-1) },
          'tab-move-right'        => -> { move_tab(1) },
          'tab-move-new-window'   => -> { @on_new_window&.call(active_slot&.location) },
          'go-home'               => -> { open_location(Gio::File.new_for_path(Dir.home)) },
          'toggle-sidebar'        => -> { split_view.show_sidebar = !split_view.show_sidebar? },
          'current-location-menu' => -> { toolbar.path_bar.current_folder_button.popup },
        }
      end

      # win.go-to-tab takes the tab's position, which Alt+0…8 supplies.
      def go_to_tab_action
        Gio::SimpleAction.new('go-to-tab', GLib::VariantType.new('i')).tap do |action|
          action.signal_connect('activate') do |_action, parameter|
            go_to_tab(parameter.to_i)
          end
        end
      end

      def go_to_tab(position)
        tab_view.get_nth_page(position).then do |page|
          unless page.nil?
            tab_view.selected_page = page
          end
        end
      rescue StandardError
        nil
      end

      # Closing the last tab closes the window, which is what
      # "Close Window or Tab" means.
      def close_current_view
        if tab_view.n_pages > 1
          tab_view.close_page(tab_view.selected_page)
        else
          window.close
        end
      end

      def close_other_tabs
        tab_view.selected_page.then do |keep|
          (0...tab_view.n_pages).map { |index| tab_view.get_nth_page(index) }
                                .reject { |page| page == keep }
                                .each { |page| tab_view.close_page(page) }
        end
      end

      def restore_tab
        @closed_locations.pop.then do |location|
          unless location.nil?
            open_new_tab(location)
          end
        end
      end

      def move_tab(offset)
        tab_view.selected_page.then do |page|
          unless page.nil?
            tab_view.reorder_page(page, tab_view.get_page_position(page) + offset)
          end
        end
      end
  end
end
