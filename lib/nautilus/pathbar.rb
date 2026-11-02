# frozen_string_literal: true

require 'adwaita'
require_relative 'ui_utilities'

module Nautilus
  # PathBar is the breadcrumb trail of the current location.
  #
  # Ported from src/nautilus-pathbar.c and
  # src/resources/menu/nautilus-pathbar-context-menu.ui. One button per path
  # segment inside a horizontally scrolling viewport, the last of them being
  # the current folder's menu button; a secondary click on any other button
  # opens the three-item button menu for that segment. The `nautilus-pathbar`
  # and `nautilus-path-button` classes are what style.css shapes.
  class PathBar
    # button-menu: the three items offered for a segment that is not the
    # current folder.
    BUTTON_MENU = [
      { label: 'Open in New _Window', action: 'pathbar.open-item-new-window' },
      { label: 'Open in New _Tab', action: 'pathbar.open-item-new-tab' },
      { label: '_Properties', action: 'pathbar.properties' },
    ].freeze

    # current-view-menu: the menu the current folder's button opens.
    CURRENT_VIEW_MENU = [
      { label: 'New _Folder…', action: 'view.new-folder', accel: '<shift><control>n' },
      # The templates submenu. Upstream grows it from the files in the user's
      # Templates folder; the one entry that is always there is the empty
      # document, and it is the only one with an action of its own.
      {
        label:     'New _Document',
        item_name: 'templates-submenu',
        submenu:   [{ label: 'Empty Document', action: 'view.template-empty' }],
      },
      { label: 'Open _With…', action: 'view.open-current-directory-with-other-application' },
      {
        label:       'Open in Consol_e',
        action:      'view.current-directory-console',
        hidden_when: 'action-disabled',
      },
      {
        section: [
          { label: 'R_eload', action: 'slot.reload', hidden_when: 'action-disabled', accel: 'F5' },
          { label: 'St_op', action: 'slot.stop', hidden_when: 'action-disabled' },
          {
            label:       'Add to _Bookmarks',
            action:      'slot.bookmark-current-directory',
            hidden_when: 'action-disabled',
            accel:       '<control>d',
          },
          {
            label:       'Remove from _Bookmarks',
            action:      'slot.unbookmark-current-directory',
            hidden_when: 'action-disabled',
          },
          {
            label:       '_Star Folder',
            action:      'slot.star-current-directory',
            hidden_when: 'action-disabled',
          },
          {
            label:       '_Unstar Folder',
            action:      'slot.unstar-current-directory',
            hidden_when: 'action-disabled',
          },
          { label: '_Copy Location', action: 'view.copy-current-location' },
          {
            label:       '_Open in File Manager',
            action:      'view.open-current-directory-with-files',
            hidden_when: 'action-disabled',
          },
        ],
      },
      {
        section: [
          { label: '_Paste', action: 'view.paste' },
          { label: 'Paste as Lin_k', action: 'view.create-link', hidden_when: 'action-disabled' },
          { label: 'Select _All', action: 'view.select-all' },
        ],
      },
      # background-extensions-section: an extension slot, and empty here
      # because a Ruby port has no NautilusMenuProvider ABI to fill it from.
      { section: [] },
      {
        section: [
          { label: 'Empty _Trash…', action: 'view.empty-trash', hidden_when: 'action-disabled' },
        ],
      },
      {
        section: [
          {
            label:       'P_roperties',
            action:      'view.current-directory-properties',
            accel:       '<alt>Return',
            hidden_when: 'action-disabled',
          },
        ],
      },
    ].freeze

    # The segments that get a name of their own rather than their basename.
    SPECIAL_NAMES = {
      '/'     => 'Operating System',
      '/root' => 'Administrator Root',
    }.freeze

    def initialize(window_slot: nil, on_open: nil)
      @window_slot = window_slot
      @on_open = on_open
      @buttons = []
      @context_location = nil
    end

    attr_reader :window_slot, :context_location

    def window_slot=(window_slot)
      @window_slot = window_slot
      unless window_slot.nil?
        self.location = window_slot.location
      end
      window_slot
    end

    def build
      root.tap do |scroller|
        scroller.child = viewport
        viewport.child = container
        button_menu.set_parent(container)
      end
    end

    # Rebuilds the trail. nautilus_path_bar_set_path() does the same thing:
    # the segments are recreated from the location every time it changes.
    def location=(location)
      @location = location
      rebuild
      location
    end

    attr_reader :location

    def root
      @root ||= Gtk::ScrolledWindow.new.tap do |scroller|
        scroller.vscrollbar_policy = :never
        scroller.hscrollbar_policy = :external
        scroller.valign = :center
        scroller.add_css_class('nautilus-pathbar')
      end
    end

    def viewport
      @viewport ||= Gtk::Viewport.new(nil, nil).tap do |port|
        port.scroll_to_focus = true
      end
    end

    def container = @container ||= Gtk::Box.new(:horizontal, 0)

    def button_menu = @button_menu ||= Gtk::PopoverMenu.new(UiUtilities.build_menu(BUTTON_MENU))

    def current_view_menu
      @current_view_menu ||= UiUtilities.build_menu(CURRENT_VIEW_MENU)
    end

    def current_folder_button
      @current_folder_button ||= Gtk::MenuButton.new.tap do |button|
        button.tooltip_text = 'Current Folder Menu'
        button.menu_model = current_view_menu
        button.add_css_class('nautilus-path-button')
        button.add_css_class('current-dir')
      end
    end

    private

      def rebuild
        clear
        segments.each_with_index do |segment, index|
          if index.positive?
            append_segment(separator)
          end
          append_segment(button_for(segment, index == segments.size - 1))
        end
      end

      def append_segment(widget)
        (@segment_widgets ||= []) << widget
        container.append(widget)
      end

      # Only the widgets this put in are taken out: the button menu is
      # parented to the container too, and removing it would fail.
      def clear
        @buttons = []
        (@segment_widgets || []).each { |widget| discard(widget) }
        @segment_widgets = []
      end

      # A button's child has to be unparented explicitly, or GTK reports the
      # button being finalized with children still attached.
      def discard(widget)
        container.remove(widget)
        if widget.is_a?(Gtk::Button)
          widget.child = nil
        end
      end

      # The locations from the root of the trail down to the current one.
      def segments
        if @location.nil?
          []
        else
          ancestry(@location).reverse
        end
      end

      # The trail stops at the home directory rather than walking into it, as
      # nautilus_path_bar's home-relative paths do.
      def ancestry(location)
        [location].tap do |locations|
          while (parent = locations.last.parent)
            if home?(locations.last)
              break
            end
            locations << parent
          end
        end
      end

      def home?(location) = location.path == Dir.home

      def separator
        Gtk::Label.new('/').tap do |label|
          label.add_css_class('dim-label')
        end
      end

      def button_for(location, current)
        if current
          current_folder_button.tap do |button|
            button.label = label_for(location)
          end
        else
          path_button(location)
        end
      end

      def path_button(location)
        Gtk::Button.new.tap do |button|
          button.child = button_content(location)
          button.add_css_class('nautilus-path-button')
          button.tooltip_text = location.path
          button.signal_connect('clicked') { @on_open&.call(location) }
          button.add_controller(secondary_gesture(location, button))
          @buttons << button
        end
      end

      # The root and the home directory show an icon instead of a name.
      def button_content(location)
        icon_name_for(location).then do |icon_name|
          if icon_name.nil?
            Gtk::Label.new(label_for(location))
          else
            Gtk::Image.new.tap { |image| image.icon_name = icon_name }
          end
        end
      end

      def icon_name_for(location)
        if location.path == '/'
          'drive-harddisk-symbolic'
        elsif home?(location)
          'user-home-symbolic'
        end
      end

      def label_for(location)
        if home?(location)
          'Home'
        else
          SPECIAL_NAMES.fetch(location.path.to_s, location.basename.to_s)
        end
      end

      def secondary_gesture(location, button)
        Gtk::GestureClick.new.tap do |gesture|
          gesture.button = Gdk::BUTTON_SECONDARY
          gesture.signal_connect('pressed') do |_gesture, _n_press, x, y|
            open_button_menu(
              location,
              button,
              x,
              y,
            )
          end
        end
      end

      # The menu's three actions act on the segment that was clicked, which is
      # what `context_location` carries to them. The popover moves to the
      # button that was clicked, and a widget can only have one parent, so it
      # is unparented from the previous one first.
      def open_button_menu(location, button, x, y)
        @context_location = location
        button_menu.tap do |popover|
          popover.unparent
          popover.set_parent(button)
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
