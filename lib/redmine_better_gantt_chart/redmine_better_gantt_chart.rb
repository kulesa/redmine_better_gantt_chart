module RedmineBetterGanttChart
  def self.calculate_duration?
    Setting['plugin_redmine_better_gantt_chart']['calculate_duration']
  end

  def self.schedule_on_weekends?
    Setting['plugin_redmine_better_gantt_chart']['schedule_on_weekends']
  end

  def self.workdays_between(date_from, date_to)
    date_from, date_to = date_to, date_from if date_to < date_from
    (date_from..date_to).select { |d| working_days.include?(d.wday) }.size
  end

  protected
  def self.working_days
    schedule_on_weekends? ? 0..6 : 1..5
  end
end
