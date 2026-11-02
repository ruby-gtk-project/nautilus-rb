# frozen_string_literal: true

require 'adwaita'
require_relative 'column_utilities'
require_relative 'global_preferences'
require_relative 'ui_utilities'

module Nautilus
  # ColumnChooser picks which list-view columns are visible, and in what
  # order.
  #
  # Ported from src/resources/ui/nautilus-column-chooser.blp and
  # nautilus-column-chooser.c: the banner offering to revert a folder's
  # custom settings, the boxed list of column rows each with a switch and a
  # move-up/move-down menu, and the "Only Apply to Current Folder" row.
  class ColumnChooser
    ROW_BUTTON_MENU = [
      {
        section: [
          { label: 'Move _Up', action: 'column-chooser.move-up' },
          { label: 'Move _Down', action: 'column-chooser.move-down' },
        ],
      },
    ].freeze

    def initialize(directory:, on_changed: nil)
      @directory = directory
      @on_changed = on_changed
      @rows = {}
    end

    def build
      dialog.tap do |window|
        window.child = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = content_box
          view.add_bottom_bar(use_custom_box)
        end

        content_box.tap do |box|
          box.append(banner)
          box.append(page)
        end

        page.add(group)
        group.add(list_box)
        use_custom_box.append(use_custom_row)

        banner.signal_connect('button-clicked') { use_default }

        install_actions
        rebuild_rows
      end
    end

    def present(parent) = dialog.present(parent)

    def dialog
      @dialog ||= Adwaita::Dialog.new.tap do |window|
        window.content_width = 360
        window.content_height = 480
      end
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def header_bar
      @header_bar ||= Adwaita::HeaderBar.new.tap do |header|
        header.title_widget = Adwaita::WindowTitle.new('Visible Columns', '')
      end
    end

    def content_box = @content_box ||= Gtk::Box.new(:vertical, 0)

    def banner
      @banner ||= Adwaita::Banner.new('This folder uses custom settings').tap do |widget|
        widget.button_label = '_Revert'
        widget.revealed = false
      end
    end

    def page = @page ||= Adwaita::PreferencesPage.new

    def group = @group ||= Adwaita::PreferencesGroup.new

    def list_box
      @list_box ||= Gtk::ListBox.new.tap do |list|
        list.selection_mode = :none
        list.add_css_class('boxed-list')
      end
    end

    def use_custom_box
      @use_custom_box ||= Gtk::ListBox.new.tap do |list|
        list.selection_mode = :none
        list.add_css_class('background')
      end
    end

    def use_custom_row
      @use_custom_row ||= Adwaita::SwitchRow.new.tap do |row|
        row.hexpand = true
        row.selectable = false
        row.title = '_Only Apply to Current Folder'
        row.use_underline = true
      end
    end

    # The menu model the per-row buttons share. Each button needs a popover
    # of its own: a Gtk::PopoverMenu has one parent, and handing the same one
    # to every button would reparent it row after row.
    def row_menu = @row_menu ||= UiUtilities.build_menu(ROW_BUTTON_MENU)

    def actions = @actions ||= Gio::SimpleActionGroup.new

    private

      def settings = GlobalPreferences.instance.list_view

      def column_order = settings['default-column-order']

      def visible_columns = settings['default-visible-columns']

      # One row per column the location can show, in the stored order. The
      # name column is always visible and so cannot be switched off.
      def rebuild_rows
        clear_rows
        ColumnUtilities.sort_columns(
          ColumnUtilities.columns_for_file(@directory),
          column_order,
        ).each do |column|
          append_row(column)
        end
      end

      # Only the rows are cleared: the move-up/move-down popover is parented
      # to the list box as well, and it is not a row.
      def clear_rows
        @rows = {}
        while (row = list_box.get_row_at_index(0))
          list_box.remove(row)
        end
      end

      def append_row(column)
        Adwaita::SwitchRow.new.tap do |row|
          row.title = row_title(column)
          row.subtitle = column.description
          row.active = visible_columns.include?(column.name)
          row.sensitive = column.name != 'name'
          row.add_suffix(menu_button(column))
          row.signal_connect('notify::active') { toggle(column, row.active?) }
          @rows[column.name] = row
          list_box.append(row)
        end
      end

      # The starred column's label is blank upstream, so the row names it.
      def row_title(column)
        if column.label.to_s.empty?
          'Starred'
        else
          column.label
        end
      end

      # Gtk::MenuButton has no "clicked" signal; the row the menu will act on
      # is noted when the button goes active, which is when its popover opens.
      def menu_button(column)
        Gtk::MenuButton.new.tap do |button|
          button.icon_name = 'view-more-symbolic'
          button.valign = :center
          button.add_css_class('flat')
          button.signal_connect('notify::active') do
            if button.active?
              @context_column = column
            end
          end
          button.popover = Gtk::PopoverMenu.new(row_menu)
        end
      end

      def toggle(column, active)
        if active
          write_visible(visible_columns + [column.name])
        else
          write_visible(visible_columns - [column.name])
        end
      end

      def write_visible(names)
        settings['default-visible-columns'] = column_order.select { |name| names.include?(name) }
        banner.revealed = use_custom_row.active?
        @on_changed&.call
      end

      def install_actions
        {
          'move-up'   => -> { move(-1) },
          'move-down' => -> { move(1) },
        }.each do |name, handler|
          actions.add_action(
            Gio::SimpleAction.new(name).tap do |action|
                        action.signal_connect('activate') { handler.call }
                      end,
          )
        end
        list_box.insert_action_group('column-chooser', actions)
      end

      def move(offset)
        column_order.dup.then do |order|
          order.index(@context_column&.name).then do |index|
            unless index.nil?
              reorder(order, index, (index + offset).clamp(0, order.size - 1))
            end
          end
        end
      end

      def reorder(order, from, to)
        order.insert(to, order.delete_at(from))
        settings['default-column-order'] = order
        rebuild_rows
        @on_changed&.call
      end

      # use_default_clicked_callback(): the banner's Revert drops the folder's
      # custom columns back to the defaults.
      def use_default
        settings['default-visible-columns'] = GlobalPreferences::SCHEMAS
                                              .fetch('list-view')
                                              .fetch('default-visible-columns')
                                              .fetch(:default)
        settings['default-column-order'] = GlobalPreferences::SCHEMAS
                                           .fetch('list-view')
                                           .fetch('default-column-order')
                                           .fetch(:default)
        banner.revealed = false
        rebuild_rows
        @on_changed&.call
      end
  end
end
