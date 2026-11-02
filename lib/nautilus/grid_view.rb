# frozen_string_literal: true

require 'adwaita'
require_relative 'list_base'
require_relative 'grid_cell'

module Nautilus
  # GridView shows the location as a grid of icons.
  #
  # Ported from src/nautilus-grid-view.c: a Gtk.GridView of grid cells, with
  # the five zoom levels and the icon sizes NautilusGridIconSize names, and
  # the captions the icon-view schema's `captions` key lists.
  class GridView < ListBase
    ICON_SIZES = {
      0 => 48,
      1 => 64,
      2 => 96,
      3 => 168,
      4 => 256,
    }.freeze

    VIEW_INFO = {
      view_id:             'grid',
      zoom_level_min:      0,
      zoom_level_max:      4,
      zoom_level_standard: 2,
    }.freeze

    def view_info = VIEW_INFO

    def icon_size = ICON_SIZES.fetch(zoom_level)

    def build
      scroller.tap do |window|
        window.child = view

        view.tap do |grid|
          grid.model = selection_model
          grid.factory = factory
          grid.signal_connect('activate') { |_view, position| activate(position) }
          grid.add_controller(background_gesture)
        end
      end
    end

    def scroller
      @scroller ||= Gtk::ScrolledWindow.new.tap do |window|
        window.hexpand = true
        window.vexpand = true
        window.hscrollbar_policy = :never
        window.add_css_class('nautilus-grid-view')
      end
    end

    def view
      @view ||= Gtk::GridView.new.tap do |grid|
        grid.max_columns = 20
        grid.min_columns = 1
        grid.enable_rubberband = true
        grid.single_click_activate = single_click?
        grid.vexpand = true
      end
    end

    def factory
      @factory ||= Gtk::SignalListItemFactory.new.tap do |signal_factory|
        signal_factory.signal_connect('setup') do |_factory, list_item|
          list_item.child = new_cell.build
        end

        signal_factory.signal_connect('bind') do |_factory, list_item|
          bind_cell(list_item)
        end

        signal_factory.signal_connect('teardown') do |_factory, list_item|
          unless list_item.child.nil?
            forget_cell(list_item.child)
          end
        end
      end
    end

    # The captions shown under each name, from the icon-view schema.
    def captions = GlobalPreferences.instance.icon_view['captions']

    def captions=(captions)
      GlobalPreferences.instance.icon_view['captions'] = captions
      refresh_captions
      captions
    end

    def apply_zoom_level
      super
      refresh_captions
    end

    private

      def refresh_captions
        @cells.each_value do |cell|
          cell.captions = captions
        end
      end

      def new_cell
        GridCell.new(
          icon_size:       icon_size,
          captions:        captions,
          on_activate:     ->(position) { activate(position) },
          on_context_menu: ->(position, x, y) { show_context_menu(position, x, y) },
        ).tap { |cell| register_cell(cell) }
      end

      def bind_cell(list_item)
        cell_for(list_item.child).then do |cell|
          unless cell.nil?
            cell.bind(@directory.file_at(list_item.position), list_item.position)
          end
        end
      end

      def single_click? = GlobalPreferences.instance.preferences['click-policy'] == 'single'

      # A click on the empty area around the icons clears the selection and
      # offers the background menu, as nautilus_list_base's background click
      # handler does.
      def background_gesture
        @background_gesture ||= Gtk::GestureClick.new.tap do |gesture|
          gesture.button = Gdk::BUTTON_SECONDARY
          gesture.signal_connect('pressed') do |_gesture, _n_press, x, y|
            @on_context_menu&.call(nil, x, y)
          end
        end
      end
  end
end
