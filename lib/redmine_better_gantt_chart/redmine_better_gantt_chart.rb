module RedmineBetterGanttChart
  def self.work_on_weekends?
    Setting['plugin_redmine_better_gantt_chart']['work_on_weekends']
  end
end
