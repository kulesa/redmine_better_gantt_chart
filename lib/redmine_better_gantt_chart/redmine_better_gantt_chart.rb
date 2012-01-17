module RedmineBetterGanttChart
  def self.calculate_duration?
    Setting['plugin_redmine_better_gantt_chart']['calculate_duration']
  end

  def self.schedule_on_weekends?
    Setting['plugin_redmine_better_gantt_chart']['schedule_on_weekends']
  end
end
