module RedmineBetterGanttChart
  def self.calculate_duration?
    Setting['plugin_redmine_better_gantt_chart']['calculate_duration']
  end

  def self.work_on_weekends?
    Setting['plugin_redmine_better_gantt_chart']['work_on_weekends']
  end
end
