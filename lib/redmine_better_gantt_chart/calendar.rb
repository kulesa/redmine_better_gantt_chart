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
      if RedmineBetterGanttChart.work_on_weekends? || is_a_working_day?(date)
        date
      else
        next_day_of_week(1, date)
      end
    end

    def self.workdays_from_date(date, shift)
      end_date = date + shift.days

      if RedmineBetterGanttChart.work_on_weekends?
        end_date
      else
        next_working_day(end_date + weekends_between(date, end_date).days)
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
  end
end
