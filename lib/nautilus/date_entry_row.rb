# frozen_string_literal: true

require 'adwaita'
require 'date'

module Nautilus
  # DateEntryRow lets a date be typed or picked from a calendar popover.
  #
  # Ported from src/nautilus-date-entry-row.c and its blueprint: an
  # Adw.EntryRow with a flat "pick date" MenuButton suffix opening a Popover
  # that holds a Calendar. Typing a date that doesn't parse adds the
  # "warning" style class and clears the stored date without touching the
  # text (text_changed()); picking one from the calendar writes the
  # formatted date back into the entry and closes the popover
  # (calendar_date_selected()).
  class DateEntryRow
    def initialize(initial: nil, on_date_time_changed: nil)
      @on_date_time_changed = on_date_time_changed
      @suppress_text_sync = false
      @date_time = initial || Time.now
    end

    attr_reader :date_time

    # The widget tree (and the calendar/entry sync below) is built here
    # rather than in `initialize`, so `date_time=`'s callback can safely
    # call back into whatever memoized this row — by build time that
    # memoization has already finished assigning, where it would not have
    # if the callback fired from inside `initialize` itself.
    def build
      row.tap do |entry_row|
        entry_row.add_suffix(menu_button)
        entry_row.signal_connect('changed') { on_text_changed }
      end
      set_date_time(@date_time, update_entry: true)
      row
    end

    def widget = row

    def date_time=(value)
      set_date_time(value, update_entry: true)
    end

    private

      def row = @row ||= Adwaita::EntryRow.new

      def menu_button
        @menu_button ||= Gtk::MenuButton.new.tap do |button|
          button.icon_name = 'x-office-calendar-symbolic'
          button.tooltip_text = 'Pick Date'
          button.direction = :left
          button.valign = :center
          button.popover = popover
          button.add_css_class('flat')
        end
      end

      def popover
        @popover ||= Gtk::Popover.new.tap do |pop|
          pop.child = calendar
        end
      end

      def calendar
        @calendar ||= Gtk::Calendar.new.tap do |cal|
          cal.signal_connect('day-selected') { on_calendar_date_selected }
        end
      end

      # text_changed(): an unparseable date gets the warning style and
      # clears the stored date-time without touching the entry text or the
      # calendar underneath it.
      def on_text_changed
        unless @suppress_text_sync
          parsed = parse_date(row.text)
          if parsed
            row.remove_css_class('warning')
            set_date_time(parsed, update_entry: false)
          else
            row.add_css_class('warning')
            @date_time = nil
          end
        end
      end

      def parse_date(text)
        Date.strptime(text, '%x').to_time
      rescue ArgumentError, Date::Error
        nil
      end

      def on_calendar_date_selected
        set_date_time(Time.local(calendar.year, calendar.month + 1, calendar.day), update_entry: true)
        popover.popdown
      end

      def set_date_time(value, update_entry:)
        @date_time = value
        calendar.date = value
        if update_entry
          @suppress_text_sync = true
          row.text = value.strftime('%x')
          @suppress_text_sync = false
          row.remove_css_class('warning')
        end
        @on_date_time_changed&.call(value)
      end
  end
end
