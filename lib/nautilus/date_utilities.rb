# frozen_string_literal: true

require_relative 'global_preferences'

module Nautilus
  # DateUtilities formats the timestamps shown in the views and in the
  # properties dialog.
  #
  # Ported from src/nautilus-date-utilities.c. Upstream drives the strings
  # through libicu's relative-date and pattern formatters; there is no ICU
  # binding for Ruby, so the same three entry points
  # (nautilus_date_to_str, nautilus_date_range_to_str and
  # nautilus_date_preview_detailed_format) are built on Time#strftime with the
  # same branching: the short "simple" form is relative (Today / Yesterday /
  # weeks / months / years) and carries a time only within a day of now, while
  # the "detailed" form always spells the date out, with seconds when it is
  # asked for the long variant.
  module DateUtilities
    SECONDS_PER_DAY = 86_400

    module_function

    # Mirrors nautilus_date_setup_preferences(): reads the date-time-format
    # key and keeps following it, so views formatted later pick the change up.
    def setup_preferences(preferences = GlobalPreferences.instance.preferences)
      @preferences = preferences
      @detailed = preferences['date-time-format'] == 'detailed'
      preferences.connect('date-time-format') do |schema, _key|
        @detailed = schema['date-time-format'] == 'detailed'
      end
    end

    def detailed_format? = @detailed == true

    # True when the locale writes 13:00 rather than 1:00 PM. Upstream asks the
    # desktop's clock-format key, whose schema is not installed in a checkout.
    def use_24_hour?
      if @use_24_hour.nil?
        @use_24_hour = Time.new(
          2000,
          1,
          1,
          13,
          0,
          0,
        ).strftime('%X').start_with?('13')
      end
      @use_24_hour
    end

    def time_format
      if use_24_hour?
        '%H:%M'
      else
        '%l:%M %p'
      end
    end

    def seconds_time_format
      if use_24_hour?
        '%H:%M:%S'
      else
        '%l:%M:%S %p'
      end
    end

    # nautilus_date_to_str(): the string the views put in a date column.
    def to_str(timestamp, use_short_format: true)
      date_to_str(
        timestamp,
        use_short_format: use_short_format,
        detailed_date:    detailed_format?,
        with_time:        true,
      )
    end

    # nautilus_date_preview_detailed_format(): the sample the preferences
    # dialog shows beside each date-format choice.
    def preview_detailed_format(timestamp, use_detailed)
      date_to_str(
        timestamp,
        use_short_format: true,
        detailed_date:    use_detailed,
        with_time:        true,
      )
    end

    # nautilus_date_range_to_str(): the label of a search date filter.
    def range_to_str(date_range, use_short_format: true)
      Array(date_range).then do |(start_date, end_date)|
        if start_date.nil? || end_date.nil?
          nil
        else
          range_string(start_date, end_date, use_short_format)
        end
      end
    end

    def date_to_str(timestamp, use_short_format:, detailed_date:, with_time:)
      if use_short_format && !detailed_date
        relative_to_str(timestamp, with_time)
      else
        absolute_to_str(timestamp, use_short_format, with_time)
      end
    end

    def relative_to_str(timestamp, with_time)
      midnight_difference(timestamp).then do |difference|
        relative_day(difference).then do |relative|
          if with_time && difference.abs < (2 * SECONDS_PER_DAY)
            combine(relative, timestamp.strftime(time_format).strip)
          else
            relative
          end
        end
      end
    end

    def absolute_to_str(timestamp, use_short_format, with_time)
      if !with_time
        timestamp.strftime('%x')
      elsif use_short_format
        "#{timestamp.strftime('%x')}, #{timestamp.strftime(time_format).strip}"
      else
        "#{timestamp.strftime('%x')}, #{timestamp.strftime(seconds_time_format).strip}"
      end
    end

    # Whole days between the timestamp's midnight and today's midnight, the
    # explicit day boundary upstream uses so "Yesterday" does not depend on
    # the time of day.
    def midnight_difference(timestamp)
      Time.now.then do |now|
        midnight(now) - midnight(timestamp)
      end
    end

    def midnight(time) = Time.new(
      time.year,
      time.month,
      time.day,
      0,
      0,
      0,
    )

    # The unit ladder of get_relative_day_month_year(): days under a week,
    # then weeks, months and years.
    def relative_day(difference)
      (difference / SECONDS_PER_DAY.to_f).then do |days|
        if days.abs < 7
          relative_days(days.round)
        elsif days.abs < 31
          plural((days / 7.0).round.abs, 'week')
        elsif days.abs < 365
          plural((days / 30.4).round.abs, 'month')
        else
          plural((days / 365.25).round.abs, 'year')
        end.then { |unit| direction(unit, days) }
      end
    end

    def relative_days(days)
      case days
      when 0 then 'Today'
      when 1 then 'Yesterday'
      when -1 then 'Tomorrow'
      else plural(days.abs, 'day')
      end
    end

    def plural(count, unit)
      if count == 1
        "1 #{unit}"
      else
        "#{count} #{unit}s"
      end
    end

    def direction(unit, days)
      if %w[Today Yesterday Tomorrow].include?(unit)
        unit
      elsif days.negative?
        "in #{unit}"
      else
        "#{unit} ago"
      end
    end

    # ureldatefmt_combineDateAndTime(): "Yesterday at 17:04".
    def combine(date, time)
      if %w[Today Yesterday Tomorrow].include?(date)
        "#{date} at #{time}"
      else
        "#{date}, #{time}"
      end
    end

    def range_string(start_date, end_date, use_short_format)
      plain = lambda do |value|
        date_to_str(
          value,
          use_short_format: use_short_format,
          detailed_date:    false,
          with_time:        false,
        )
      end

      if ((end_date - start_date) / SECONDS_PER_DAY) < 1 || same_date?(start_date, end_date)
        plain.call(start_date)
      elsif same_date?(Time.now, end_date)
        "Since #{plain.call(start_date)}"
      else
        "#{plain.call(start_date)} - #{plain.call(end_date)}"
      end
    end

    def same_date?(one, other)
      one.year == other.year && one.month == other.month && one.day == other.day
    end
  end
end
