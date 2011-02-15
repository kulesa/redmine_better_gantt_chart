require 'redmine'

require 'dispatcher'

Dispatcher.to_prepare :redmine_issue_dependency do
  require_dependency 'issue'
  # Guards against including the module multiple time (like in tests)
  # and registering multiple callbacks
  unless Issue.included_modules.include? RedmineIssueDependency::IssueDependencyPatch
    Issue.send(:include, RedmineIssueDependency::IssueDependencyPatch)
  end
  
  unless Redmine::Helpers::Gantt.included_modules.include? RedmineIssueDependency::GanttHelperPatch
    Redmine::Helpers::Gantt.send(:include, RedmineIssueDependency::GanttHelperPatch)
  end
end

Redmine::Plugin.register :redmine_issue_dependency do
  name 'Redmine Issue Dependency plugin'
  author 'Alexey Kuleshov'
  description 'This plugin improves functionality of related issues'
  version '0.0.1'
  url 'http://github.com/kulesa/redmine_issue_dependency'
  author_url 'http://github.com/kulesa'
  
  requires_redmine :version_or_higher => '1.1.0'
end
