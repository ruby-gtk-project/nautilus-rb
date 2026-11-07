# frozen_string_literal: true

require 'adwaita'
require_relative 'date_entry_row'

module Nautilus
  # DateRangeDialog lets the search filters popover pick a date range,
  # either a center day with a span around it or two explicit dates.
  #
  # Ported from src/nautilus-date-range-dialog.c and its blueprint: the
  # "Date Range" combo row (Single Day / ±1 / ±3 / ±7 / ±14 / Specify
  # Range), the single-date row shown for every span mode, the from/to
  # rows shown only in "Specify Range" (position 5), and the pill Filter
  # button that stays disabled until the current mode has a valid date (or
  # pair, with "from" no later than "to"). Confirming clamps both ends to
  # "now" the way try_confirm() does and hands the pair to `on_date_range`
  # instead of emitting the "date-range" signal.
  class DateRangeDialog
    SPECIFY_RANGE_POSITION = 5
    SPANS = [0, 1, 3, 7, 14].freeze

    def initialize(initial_date_range: nil, on_date_range: nil)
      @on_date_range = on_date_range
      @initial_date_range = initial_date_range
    end

    def build
      dialog.tap do |window|
        window.title = 'Add Date Filter'
        window.content_height = 362
        window.content_width = 450
        window.child = toolbar_view
        window.default_widget = select_button

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = preferences_page
        end

        header_bar.title_widget = Adwaita::WindowTitle.new('Filter by Date', '')

        preferences_page.tap do |page|
          page.add(range_group)
          page.add(dates_group)
          page.add(button_group)
        end

        range_group.add(date_range_row)
        dates_group.tap do |group|
          group.add(single_date_row.build)
          group.add(from_entry_row.build)
          group.add(to_entry_row.build)
        end
        button_group.add(select_button)

        date_range_row.signal_connect('notify::selected') { on_range_mode_changed }
        select_button.signal_connect('clicked') { try_confirm }

        if @initial_date_range
          set_initial_date_range(@initial_date_range[0], @initial_date_range[1])
        else
          on_range_mode_changed
        end
        from_entry_row.widget.grab_focus
      end
    end

    private

      def dialog = @dialog ||= Adwaita::Dialog.new

      def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

      def header_bar = @header_bar ||= Adwaita::HeaderBar.new

      def preferences_page = @preferences_page ||= Adwaita::PreferencesPage.new

      def range_group = @range_group ||= Adwaita::PreferencesGroup.new

      def dates_group = @dates_group ||= Adwaita::PreferencesGroup.new

      def button_group = @button_group ||= Adwaita::PreferencesGroup.new

      def date_range_row
        @date_range_row ||= Adwaita::ComboRow.new.tap do |row|
          row.title = '_Date Range'
          row.use_underline = true
          row.model = Gtk::StringList.new(
            ['Single Day', "± 1 day", "± 3 days", "± 7 days", "± 14 days", 'Specify Range'],
          )
          row.selected = 0
        end
      end

      def single_date_row
        @single_date_row ||= DateEntryRow.new(on_date_time_changed: ->(_value) { update_confirm_button })
      end

      def from_entry_row
        @from_entry_row ||= DateEntryRow.new(on_date_time_changed: ->(_value) { update_confirm_button })
      end

      def to_entry_row
        @to_entry_row ||= DateEntryRow.new(on_date_time_changed: ->(_value) { update_confirm_button })
      end

      def select_button
        @select_button ||= Gtk::Button.new.tap do |button|
          button.label = '_Filter'
          button.use_underline = true
          button.margin_top = 12
          button.halign = :center
          button.add_css_class('pill')
          button.add_css_class('suggested-action')
        end
      end

      def range_mode? = date_range_row.selected == SPECIFY_RANGE_POSITION

      def on_range_mode_changed
        single_date_row.widget.visible = !range_mode?
        from_entry_row.widget.visible = range_mode?
        to_entry_row.widget.visible = range_mode?
        update_confirm_button
      end

      def valid_date_range?
        if range_mode?
          from = from_entry_row.date_time
          to = to_entry_row.date_time
          !from.nil? && !to.nil? && from <= to
        else
          !single_date_row.date_time.nil?
        end
      end

      def update_confirm_button
        select_button.sensitive = valid_date_range?
      end

      def try_confirm
        if valid_date_range?
          start, finish = resolved_range
          now = Time.now
          @on_date_range&.call([clamp(start, now), clamp(finish, now)])
          dialog.close
        else
          select_button.sensitive = false
        end
      end

      def clamp(date, now) = date > now ? now : date

      def resolved_range
        if range_mode?
          [from_entry_row.date_time, to_entry_row.date_time]
        else
          center = single_date_row.date_time
          span = SPANS[date_range_row.selected] || 0
          [center - (span * 86_400), center + (span * 86_400)]
        end
      end

      def set_initial_date_range(from, to)
        date_range_row.selected = SPECIFY_RANGE_POSITION
        on_range_mode_changed
        from_entry_row.date_time = from
        to_entry_row.date_time = to
        update_confirm_button
      end
  end
end
