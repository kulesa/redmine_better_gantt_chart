module RedmineBetterGanttChart
  def self.work_on_weekends?
    Setting['plugin_redmine_better_gantt_chart']['work_on_weekends']
  end

  def self.smart_sorting?
    Setting['plugin_redmine_better_gantt_chart']['smart_sorting']
  end
end
