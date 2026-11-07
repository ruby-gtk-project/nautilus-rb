# frozen_string_literal: true

require 'adwaita'
require_relative 'list_base'
require_relative 'column_utilities'
require_relative 'name_cell'
require_relative 'label_cell'
require_relative 'star_cell'

module Nautilus
  # ListView shows the location as a column view, one row per file.
  #
  # Ported from src/nautilus-list-view.c: a Gtk.ColumnView whose columns come
  # from ColumnUtilities, ordered and filtered by the list-view schema's
  # default-column-order and default-visible-columns keys, with the name
  # column carrying a NameCell, the starred column a StarCell and every other
  # column a LabelCell. The three zoom levels set the name cell's icon size
  # and, at the smallest, add the `compact` class style.css keys its tighter
  # row spacing off.
  class ListView < ListBase
    ICON_SIZES = {
      0 => 16,
      1 => 32,
      2 => 64,
    }.freeze

    VIEW_INFO = {
      view_id:             'list',
      zoom_level_min:      0,
      zoom_level_max:      2,
      zoom_level_standard: 1,
    }.freeze

    def view_info = VIEW_INFO

    def icon_size = ICON_SIZES.fetch(zoom_level)

    # FilesView#mode= calls #build every time the view is switched back to,
    # not only the first time, so this has to be safe to call more than
    # once: the view and its controller are memoized widgets, and attaching
    # the same Gtk::GestureClick a second time is a GTK-CRITICAL
    # (gtk_widget_add_controller's single-parent assertion), not a no-op.
    def build
      @built ||= scroller.tap do |window|
        window.child = view

        view.tap do |column_view|
          column_view.model = selection_model
          column_view.signal_connect('activate') { |_view, position| activate(position) }
          column_view.add_controller(background_gesture)
        end

        apply_columns_settings
        apply_compact_class
      end
    end

    def scroller
      @scroller ||= Gtk::ScrolledWindow.new.tap do |window|
        window.hexpand = true
        window.vexpand = true
        window.add_css_class('nautilus-list-view')
      end
    end

    def view
      @view ||= Gtk::ColumnView.new.tap do |column_view|
        column_view.enable_rubberband = true
        column_view.single_click_activate = single_click?
        column_view.reorderable = false
        column_view.vexpand = true
        column_view.add_css_class('view')
      end
    end

    # The visible columns, in the stored order: apply_columns_settings().
    def visible_column_names
      ColumnUtilities.default_visible_columns(
        @directory.kind,
        GlobalPreferences.instance.list_view['default-visible-columns'],
      ).then do |visible|
        ordered_column_names.select { |name| visible.include?(name) }
      end
    end

    def ordered_column_names
      GlobalPreferences.instance.list_view['default-column-order'].then do |order|
        ColumnUtilities.sort_columns(ColumnUtilities.columns_for_file(@directory), order).map(&:name)
      end
    end

    def visible_column_names=(names)
      GlobalPreferences.instance.list_view['default-visible-columns'] = names
      apply_columns_settings
      names
    end

    # Replaces the column set with the one the settings now name.
    def apply_columns_settings
      view.tap do |column_view|
        clear_columns
        visible_column_names.each do |name|
          ColumnUtilities.column_by_name(name).then do |definition|
            unless definition.nil?
              column_view.append_column(column_for(definition))
            end
          end
        end
      end
    end

    def clear_columns
      view.columns.then do |columns|
        while columns.n_items.positive?
          view.remove_column(columns.get_item(0))
        end
      end
    end

    def apply_zoom_level
      super
      apply_compact_class
    end

    private

      def apply_compact_class
        if zoom_level == view_info.fetch(:zoom_level_min)
          scroller.add_css_class('compact')
        else
          scroller.remove_css_class('compact')
        end
      end

      def column_for(definition)
        Gtk::ColumnViewColumn.new(definition.label, factory_for(definition)).tap do |column|
          column.expand = definition.name == 'name'
          column.resizable = definition.name != 'starred'
        end
      end

      def factory_for(definition)
        Gtk::SignalListItemFactory.new.tap do |factory|
          factory.signal_connect('setup') do |_factory, list_item|
            list_item.child = new_cell(definition).build
          end

          factory.signal_connect('bind') do |_factory, list_item|
            bind_cell(list_item)
          end

          factory.signal_connect('teardown') do |_factory, list_item|
            unless list_item.child.nil?
              forget_cell(list_item.child)
            end
          end
        end
      end

      def new_cell(definition)
        cell_class_for(definition).tap { |cell| register_cell(cell) }
      end

      def cell_class_for(definition)
        case definition.name
        when 'name' then name_cell
        when 'starred' then star_cell
        else label_cell(definition)
        end
      end

      def name_cell
        NameCell.new(
          icon_size:       icon_size,
          on_activate:     ->(position) { activate(position) },
          on_context_menu: ->(position, x, y) { show_context_menu(position, x, y) },
        )
      end

      def star_cell
        StarCell.new(
          icon_size:       icon_size,
          on_context_menu: ->(position, x, y) { show_context_menu(position, x, y) },
        )
      end

      def label_cell(definition)
        LabelCell.new(
          definition,
          icon_size:       icon_size,
          on_activate:     ->(position) { activate(position) },
          on_context_menu: ->(position, x, y) { show_context_menu(position, x, y) },
        )
      end

      def bind_cell(list_item)
        cell_for(list_item.child).then do |cell|
          unless cell.nil?
            cell.bind(@directory.file_at(list_item.position), list_item.position)
          end
        end
      end

      def single_click? = GlobalPreferences.instance.preferences['click-policy'] == 'single'

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
