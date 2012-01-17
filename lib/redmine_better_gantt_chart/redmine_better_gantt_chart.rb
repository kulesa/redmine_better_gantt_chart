module RedmineBetterGanttChart
  def self.calculate_duration?
    Setting['plugin_redmine_better_gantt_chart']['calculate_duration']
  end

  def self.schedule_on_weekends?
    Setting['plugin_redmine_better_gantt_chart']['schedule_on_weekends']
  end

  def self.workdays_between(date_from, date_to)
    date_from, date_to = date_to, date_from if date_to < date_from
    (date_from..date_to).select { |d| is_a_working_day?(d) }.size
  end

  def self.weekends_between(date_from, date_to)
    date_from, date_to = date_to, date_from if date_to < date_from
    (date_from..date_to).select { |d| !is_a_working_day?(d) }.size
  end

  def self.next_working_day(date)
    if schedule_on_weekends? || is_a_working_day?(date)
      date
    else
      next_day_of_week(1, date)
    end
  end

  def self.workdays_from_date(date, shift)
    end_date = date + shift.days

    if schedule_on_weekends?
      end_date
    else
      end_date + weekends_between(date, end_date).days
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
    schedule_on_weekends? ? 0..6 : 1..5
  end

  def self.is_a_working_day?(date)
    working_days.include?(date.wday)
  end
end
