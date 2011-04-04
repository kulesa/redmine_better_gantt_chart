require 'redmine'

require 'dispatcher'

Dispatcher.to_prepare :redmine_issue_dependency do
  require_dependency 'issue'
  # Guards against including the module multiple time (like in tests)
  # and registering multiple callbacks
  unless Issue.included_modules.include? RedmineBetterGanttChart::IssueDependencyPatch
    Issue.send(:include, RedmineBetterGanttChart::IssueDependencyPatch)
  end
  
  unless Redmine::Helpers::Gantt.included_modules.include? RedmineBetterGanttChart::GanttHelperPatch
    Redmine::Helpers::Gantt.send(:include, RedmineBetterGanttChart::GanttHelperPatch)
  end
end

Redmine::Plugin.register :redmine_better_gantt_chart do
  name 'Redmine Better Gantt Chart plugin'
  author 'Alexey Kuleshov'
  description 'This plugin improves Redmine Gantt Chart'
  version '0.4.0'
  url 'http://github.com/kulesa/redmine_issue_dependency'
  author_url 'http://github.com/kulesa'
  
  requires_redmine :version_or_higher => '1.1.0'
end
