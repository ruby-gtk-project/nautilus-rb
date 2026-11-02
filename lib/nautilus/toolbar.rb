# frozen_string_literal: true

require 'adwaita'
require_relative 'pathbar'
require_relative 'location_entry'
require_relative 'history_controls'
require_relative 'view_controls'

module Nautilus
  # Toolbar is the content side's header bar.
  #
  # Ported from src/resources/ui/nautilus-toolbar.blp and
  # nautilus-toolbar.c. Its title area is a stack with three pages — the
  # pathbar, the location entry and the search container — and its ends carry
  # the sidebar toggle, the history controls, the view controls and the
  # new-folder button, each of them shown or hidden by the window's
  # breakpoint through the same properties the blueprint binds.
  class Toolbar
    def initialize(window_slot: nil, on_sidebar_toggled: nil)
      @window_slot = window_slot
      @on_sidebar_toggled = on_sidebar_toggled
      @show_view_controls = true
      @show_history_controls = true
      @show_sidebar_button = false
      @show_new_folder_button = true
    end

    attr_reader :window_slot

    def window_slot=(window_slot)
      @window_slot = window_slot
      path_bar.window_slot = window_slot
      history_controls.window_slot = window_slot
      view_controls.window_slot = window_slot
      refresh
      window_slot
    end

    def build
      root.tap do |bin|
        bin.child = header_bar

        header_bar.tap do |header|
          header.title_widget = header_toolbar
          header.pack_start(show_sidebar_button)
          header.pack_start(history_controls_stack)
          header.pack_end(view_controls.build)
          header.pack_end(new_folder_button)
        end

        header_toolbar.tap do |box|
          box.append(toolbar_switcher)
          box.append(search_button_stack)
        end

        toolbar_switcher.tap do |stack|
          stack.add_named(path_bar.build, 'pathbar')
          stack.add_named(location_box, 'location')
          stack.add_named(search_container, 'search')
        end

        location_box.tap do |box|
          box.append(location_entry.build)
          box.append(location_cancel_button)

          location_cancel_button.signal_connect('clicked') do
            close_location_entry
          end
        end

        search_button_stack.tap do |stack|
          stack.add_named(search_button, 'search-button')
          stack.add_named(search_button_placeholder, 'placeholder')
        end

        history_controls_stack.tap do |stack|
          stack.add_named(history_controls.build, 'history-controls')
          stack.add_named(history_controls_placeholder, 'placeholder')
        end

        show_sidebar_button.signal_connect('toggled') do
          @on_sidebar_toggled&.call(show_sidebar_button.active?)
        end

        refresh
      end
    end

    # --- The properties the window's breakpoint sets ------------------------

    def show_view_controls=(show)
      @show_view_controls = show
      view_controls.root.visible = show
      show
    end

    def show_history_controls=(show)
      @show_history_controls = show
      history_controls_stack.visible = show
      show
    end

    def show_sidebar_button=(show)
      @show_sidebar_button = show
      show_sidebar_button.visible = show
      show
    end

    def show_new_folder_button=(show)
      @show_new_folder_button = show
      new_folder_button.visible = show
      show
    end

    def sidebar_button_active=(active)
      unless show_sidebar_button.active? == active
        show_sidebar_button.active = active
      end
      active
    end

    # --- The three title-area pages -----------------------------------------

    def show_pathbar
      toolbar_switcher.visible_child_name = 'pathbar'
      search_button_stack.visible_child_name = 'search-button'
    end

    def show_location_entry
      unless @window_slot.nil?
        location_entry.location = @window_slot.location
      end
      toolbar_switcher.visible_child_name = 'location'
      search_button_stack.visible_child_name = 'placeholder'
      location_entry.entry.grab_focus
    end

    def show_search
      toolbar_switcher.visible_child_name = 'search'
      search_button_stack.visible_child_name = 'search-button'
    end

    # nautilus_toolbar_close_location_entry().
    def close_location_entry
      show_pathbar
    end

    def refresh
      unless @window_slot.nil?
        path_bar.location = @window_slot.location
      end
      view_controls.refresh
    end

    # --- Widgets -------------------------------------------------------------

    def root = @root ||= Adwaita::Bin.new

    def header_bar = @header_bar ||= Adwaita::HeaderBar.new

    def header_toolbar = @header_toolbar ||= Gtk::Box.new(:horizontal, 6)

    def toolbar_switcher
      @toolbar_switcher ||= Gtk::Stack.new.tap do |stack|
        stack.valign = :center
        stack.hexpand = false
        stack.transition_type = :crossfade
      end
    end

    def path_bar
      @path_bar ||= PathBar.new(
        window_slot: @window_slot,
        on_open:     ->(location) { open_location(location) },
      )
    end

    def location_box
      @location_box ||= Gtk::Box.new(:horizontal, 0).tap do |box|
        box.add_css_class('linked')
      end
    end

    def location_entry
      @location_entry ||= LocationEntry.new(
        on_open:   ->(location) { open_location(location) },
        on_cancel: -> { close_location_entry },
      )
    end

    def location_cancel_button
      @location_cancel_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = 'window-close-symbolic'
        button.tooltip_text = 'Cancel'
      end
    end

    def search_container = @search_container ||= Gtk::Box.new(:vertical, 0)

    def search_button_stack
      @search_button_stack ||= Gtk::Stack.new.tap do |stack|
        stack.hhomogeneous = true
        stack.transition_type = :crossfade
      end
    end

    def search_button
      @search_button ||= Gtk::ToggleButton.new.tap do |button|
        button.tooltip_text = 'Search Current Folder'
        button.halign = :center
        button.valign = :center
        button.action_name = 'slot.search-visible'
        button.icon_name = 'nautilus-folder-search-symbolic'
      end
    end

    def search_button_placeholder = @search_button_placeholder ||= Adwaita::Bin.new

    def show_sidebar_button
      @show_sidebar_button_widget ||= Gtk::ToggleButton.new.tap do |button|
        button.visible = @show_sidebar_button
        button.tooltip_text = 'Show Sidebar'
        button.icon_name = 'sidebar-show-symbolic'
      end
    end

    def history_controls_stack
      @history_controls_stack ||= Gtk::Stack.new.tap do |stack|
        stack.hhomogeneous = true
        stack.transition_type = :crossfade
      end
    end

    def history_controls
      @history_controls ||= HistoryControls.new(window_slot: @window_slot)
    end

    def history_controls_placeholder = @history_controls_placeholder ||= Adwaita::Bin.new

    def view_controls = @view_controls ||= ViewControls.new(window_slot: @window_slot)

    def new_folder_button
      @new_folder_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = 'folder-new-symbolic'
        button.tooltip_text = 'New Folder'
        button.action_name = 'view.new-folder'
        button.focus_on_click = false
      end
    end

    private

      def open_location(location)
        close_location_entry
        unless @window_slot.nil?
          @window_slot.open_location(location)
        end
      end
  end
end
