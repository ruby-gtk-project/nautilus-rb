# frozen_string_literal: true

require 'adwaita'
require_relative 'global_preferences'
require_relative 'date_utilities'

module Nautilus
  # PreferencesDialog is the app's preferences.
  #
  # Ported from src/resources/ui/nautilus-preferences-dialog.blp and
  # nautilus-preferences-dialog.c: one page with five groups — General with
  # its two switches and the single/double-click toggle group, Optional
  # Context Menu Actions, Performance with its three speed-tradeoff combos,
  # and Date and Time Format with its two radio rows driven by the
  # `preferences.date-time-format` action.
  class PreferencesDialog
    # The three speed-tradeoff combos all offer the same choices, in the
    # order the enum declares them.
    SPEED_TRADEOFF_LABELS = ['On All Locations', 'On This Device Only', 'Never'].freeze
    SPEED_TRADEOFF_VALUES = %w[always local-only never].freeze

    PERFORMANCE_ROWS = [
      ['Search in Su_bfolders', 'recursive-search'],
      ['Show _Thumbnails', 'show-image-thumbnails'],
      ['_Count Number of Files in Folders', 'show-directory-item-counts'],
    ].freeze

    GENERAL_DESCRIPTION = 'Show more actions in the menus. Keyboard shortcuts can be used even ' \
                          'if the actions are not shown.'

    PERFORMANCE_DESCRIPTION = 'These features may cause slowdowns and excess network usage, ' \
                              'especially when browsing files outside this device, such as on a ' \
                              'remote server.'

    DATE_DESCRIPTION = 'Choose how dates and times are displayed in list and grid views.'

    def initialize(preferences: GlobalPreferences.instance)
      @preferences = preferences
    end

    def build
      dialog.tap do |window|
        window.add(page)

        page.tap do |preferences_page|
          preferences_page.add(general_group)
          preferences_page.add(context_menu_group)
          preferences_page.add(performance_group)
          preferences_page.add(date_group)
        end

        general_group.tap do |group|
          group.add(sort_folders_first_row)
          group.add(use_tree_view_row)
          group.add(open_action_row)
        end

        open_action_row.add_suffix(open_action_toggle_group)

        context_menu_group.tap do |group|
          group.add(show_create_link_row)
          group.add(show_delete_permanently_row)
        end

        performance_group.tap do |group|
          performance_rows.each { |row| group.add(row) }
        end

        date_group.tap do |group|
          group.add(date_format_simple_row)
          group.add(date_format_detailed_row)
        end

        date_format_simple_row.add_prefix(date_format_simple_button)
        date_format_detailed_row.add_prefix(date_format_detailed_button)

        connect_handlers
        load_values
        install_actions
      end
    end

    def present(parent) = dialog.present(parent)

    def dialog
      @dialog ||= Adwaita::PreferencesDialog.new.tap do |window|
        window.search_enabled = true
      end
    end

    def page
      @page ||= Adwaita::PreferencesPage.new.tap do |preferences_page|
        preferences_page.title = 'General'
      end
    end

    def general_group
      @general_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = 'General'
      end
    end

    def sort_folders_first_row = switch_row('Sort _Folders Before Files')

    def use_tree_view_row = switch_row('_Expandable Folders in List View')

    def open_action_row
      @open_action_row ||= Adwaita::ActionRow.new.tap do |row|
        row.title = '_Action to Open Items'
        row.use_underline = true
      end
    end

    def open_action_toggle_group
      @open_action_toggle_group ||= Adwaita::ToggleGroup.new.tap do |group|
        group.valign = :center
        group.add(toggle('single', 'Single-Click'))
        group.add(toggle('double', 'Double-Click'))
      end
    end

    def context_menu_group
      @context_menu_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = 'Optional Context Menu Actions'
        group.description = GENERAL_DESCRIPTION
      end
    end

    def show_create_link_row = switch_row('Create _Link')

    def show_delete_permanently_row = switch_row('_Delete Permanently')

    def performance_group
      @performance_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = 'Performance'
        group.description = PERFORMANCE_DESCRIPTION
      end
    end

    def performance_rows
      @performance_rows ||= PERFORMANCE_ROWS.map do |(title, _key)|
        Adwaita::ComboRow.new.tap do |row|
          row.title = title
          row.use_underline = true
          row.model = Gtk::StringList.new(SPEED_TRADEOFF_LABELS)
        end
      end
    end

    def date_group
      @date_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = 'Date and Time Format'
        group.description = DATE_DESCRIPTION
      end
    end

    def date_format_simple_row = date_row('_Simple', :simple)

    def date_format_detailed_row = date_row('Deta_iled', :detailed)

    def date_format_simple_button
      @date_format_simple_button ||= Gtk::CheckButton.new.tap do |button|
        button.valign = :center
        button.action_name = 'preferences.date-time-format'
        button.action_target = GLib::Variant.parse("'simple'")
      end
    end

    def date_format_detailed_button
      @date_format_detailed_button ||= Gtk::CheckButton.new.tap do |button|
        button.valign = :center
        button.group = date_format_simple_button
        button.action_name = 'preferences.date-time-format'
        button.action_target = GLib::Variant.parse("'detailed'")
      end
    end

    def actions = @actions ||= Gio::SimpleActionGroup.new

    private

      def switch_row(title)
        (@switch_rows ||= {})[title] ||= Adwaita::SwitchRow.new.tap do |row|
          row.title = title
          row.use_underline = true
        end
      end

      def date_row(title, kind)
        (@date_rows ||= {})[kind] ||= Adwaita::ActionRow.new.tap do |row|
          row.title = title
          row.use_underline = true
        end
      end

      def toggle(name, label)
        Adwaita::Toggle.new.tap do |widget|
          widget.name = name
          widget.label = label
        end
      end

      # The two rows whose subtitles preview the chosen date format, which is
      # what nautilus_preferences_dialog_setup_date_time_format does.
      def refresh_date_previews
        Time.now.then do |now|
          date_format_simple_row.subtitle = DateUtilities.preview_detailed_format(now, false)
          date_format_detailed_row.subtitle = DateUtilities.preview_detailed_format(now, true)
        end
      end

      def load_values
        sort_folders_first_row.active = @preferences.file_chooser['sort-directories-first']
        use_tree_view_row.active = @preferences.list_view['use-tree-view']
        open_action_toggle_group.active_name = @preferences.preferences['click-policy']
        show_create_link_row.active = @preferences.preferences['show-create-link']
        show_delete_permanently_row.active = @preferences.preferences['show-delete-permanently']
        load_performance_values
        refresh_date_previews
        refresh_date_buttons
      end

      def load_performance_values
        PERFORMANCE_ROWS.each_with_index do |(_title, key), index|
          performance_rows[index].selected =
            SPEED_TRADEOFF_VALUES.index(@preferences.preferences[key]).to_i
        end
      end

      def refresh_date_buttons
        (@preferences.preferences['date-time-format'] == 'detailed').then do |detailed|
          date_format_detailed_button.active = detailed
          date_format_simple_button.active = !detailed
        end
      end

      def connect_handlers
        sort_folders_first_row.signal_connect('notify::active') do
          @preferences.file_chooser['sort-directories-first'] = sort_folders_first_row.active?
        end
        use_tree_view_row.signal_connect('notify::active') do
          @preferences.list_view['use-tree-view'] = use_tree_view_row.active?
        end
        open_action_toggle_group.signal_connect('notify::active-name') do
          @preferences.preferences['click-policy'] = open_action_toggle_group.active_name
        end
        show_create_link_row.signal_connect('notify::active') do
          @preferences.preferences['show-create-link'] = show_create_link_row.active?
        end
        show_delete_permanently_row.signal_connect('notify::active') do
          @preferences.preferences['show-delete-permanently'] = show_delete_permanently_row.active?
        end
        connect_performance_handlers
      end

      def connect_performance_handlers
        PERFORMANCE_ROWS.each_with_index do |(_title, key), index|
          performance_rows[index].signal_connect('notify::selected') do |row|
            @preferences.preferences[key] = SPEED_TRADEOFF_VALUES.fetch(row.selected)
          end
        end
      end

      # preferences.date-time-format carries 'simple' or 'detailed', which is
      # what the two check buttons target.
      def install_actions
        actions.add_action(date_time_format_action)
        dialog.insert_action_group('preferences', actions)
      end

      def date_time_format_action
        Gio::SimpleAction.new(
          'date-time-format',
          GLib::VariantType.new('s'),
          GLib::Variant.parse("'#{@preferences.preferences['date-time-format']}'"),
        ).tap do |action|
          action.signal_connect('activate') do |_action, parameter|
            apply_date_time_format(action, parameter.to_s)
          end
        end
      end

      def apply_date_time_format(action, format)
        @preferences.preferences['date-time-format'] = format
        action.set_state(GLib::Variant.parse("'#{format}'"))
        refresh_date_previews
      end
  end
end
