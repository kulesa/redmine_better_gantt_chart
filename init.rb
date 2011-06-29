require 'redmine'

require 'dispatcher'

Dispatcher.to_prepare :redmine_issue_dependency do
  require_dependency 'issue'
  require_dependency 'project'
  # Guards against including the module multiple time (like in tests)
  # and registering multiple callbacks
  unless ActiveRecord::Base.included_modules.include? RedmineBetterGanttChart::ActiveRecord::CallbackExtensions
    ActiveRecord::Base.send(:include, RedmineBetterGanttChart::ActiveRecord::CallbackExtensions)
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
end

Redmine::Plugin.register :redmine_better_gantt_chart do
  name 'Redmine Better Gantt Chart plugin'
  author 'Alexey Kuleshov'
  description 'This plugin improves Redmine Gantt Chart'
  version '0.5.3'
  url 'http://github.com/kulesa/redmine_issue_dependency'
  author_url 'http://github.com/kulesa'
  
  requires_redmine :version_or_higher => '1.1.0'
end
