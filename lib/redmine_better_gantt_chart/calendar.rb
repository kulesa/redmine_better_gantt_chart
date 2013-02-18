module RedmineBetterGanttChart
  module Calendar
    def self.workdays_between(date_from, date_to)
      date_from, date_to = date_to, date_from if date_to < date_from
      number_of_days_in(date_from, date_to) { |d| is_a_working_day?(d) }
    end

    def self.weekends_between(date_from, date_to)
      date_from, date_to = date_to, date_from if date_to < date_from
      number_of_days_in(date_from, date_to) { |d| !is_a_working_day?(d) }
    end

    def self.next_working_day(date)
      the_same_day_or(date) { next_day_of_week(1, date) }
    end

    def self.previous_working_day(date)
      the_same_day_or(date) { previous_day_of_week(5, date) }
    end

    def self.workdays_from_date(date, shift)
      end_date = date + shift.days

      if RedmineBetterGanttChart.work_on_weekends?
        end_date
      else
        start_date = date
        if shift > 0
          while true
            break if (range = weekends_between(start_date, end_date).days) == 0
            start_date = end_date
            start_date += 1.days if start_date.wday == 6 || start_date.wday == 0
            end_date = end_date + range
          end
          next_working_day(end_date)
        else
          while true
            break if (weekend_diff = weekends_between(start_date, end_date)) == 0
            start_date = end_date
            start_date -= 1.days if start_date.wday == 6 || start_date.wday == 0
            end_date = end_date - weekend_diff.days
          end
          previous_working_day(end_date)
        end
      end
    end

    def self.workdays_before_date(date, shift)
      workdays_from_date(date, -shift)
    end

    # Returns nearest requested day of week, for example
    # next_day_of_week(5) will return next Friday
    # next_day_of_week(5, Date.today + 7) will return Friday of the next week
    def self.next_day_of_week(wday, from = Date.today)
      from + (wday + 7 - from.wday) % 7
    end

    def self.previous_day_of_week(wday, from = Date.today)
      from - (from.wday - wday + 7) % 7
    end

    def self.working_days
      RedmineBetterGanttChart.work_on_weekends? ? 0..6 : 1..5
    end

    def self.is_a_working_day?(date)
      working_days.include?(date.wday)
    end

    def self.number_of_days_in(date_from, date_to, &block)
      (date_from..date_to).select do |date|
        yield date
      end.size
    end

    def self.the_same_day_or(date)
      if RedmineBetterGanttChart.work_on_weekends? || is_a_working_day?(date)
        date
      else
        yield
      end
    end
  end
end
