require_dependency 'issue'
require_dependency 'project'

unless IssuesHelper.included_modules.include? RedmineBetterGanttChart::IssuesHelperPatch
  IssuesHelper.send(:include, RedmineBetterGanttChart::IssuesHelperPatch)
end

unless Issue.included_modules.include? RedmineBetterGanttChart::IssueDependencyPatch
  Issue.send(:include, RedmineBetterGanttChart::IssueDependencyPatch)
end

unless Issue.included_modules.include? RedmineBetterGanttChart::IssuePatch
  Issue.send(:include, RedmineBetterGanttChart::IssuePatch)
end

unless Project.included_modules.include? RedmineBetterGanttChart::ProjectPatch
  Project.send(:include, RedmineBetterGanttChart::ProjectPatch)
end

unless GanttsController.included_modules.include? RedmineBetterGanttChart::GanttsControllerPatch
  GanttsController.send(:include, RedmineBetterGanttChart::GanttsControllerPatch)
end

require_dependency 'redmine_better_gantt_chart/redmine_better_gantt_chart'
require_dependency 'redmine_better_gantt_chart/calendar'
require_dependency 'redmine_better_gantt_chart/hooks/view_issues_show_details_bottom_hook'
