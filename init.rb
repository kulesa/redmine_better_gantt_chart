require 'redmine'
require 'dispatcher' unless Rails::VERSION::MAJOR >= 3

if Rails::VERSION::MAJOR >= 3
  ActionDispatch::Callbacks.to_prepare do
    require_dependency 'redmine_better_gantt_chart/patches'

    unless ActiveRecord::Base.included_modules.include?(RedmineBetterGanttChart::ActiveRecord::CallbackExtensionsForRails3)
      ActiveRecord::Base.send(:include, RedmineBetterGanttChart::ActiveRecord::CallbackExtensionsForRails3)
    end
  end
else
  Dispatcher.to_prepare :redmine_better_gantt_chart do
    unless ActiveRecord::Base.included_modules.include?(RedmineBetterGanttChart::ActiveRecord::CallbackExtensionsForRails2)
      ActiveRecord::Base.send(:include, RedmineBetterGanttChart::ActiveRecord::CallbackExtensionsForRails2)
    end
    require_dependency 'redmine_better_gantt_chart/patches'
  end
end

Redmine::Plugin.register :redmine_better_gantt_chart do
  name 'Redmine Better Gantt Chart plugin'
  author 'Alexey Kuleshov'
  description 'This plugin improves Redmine Gantt Chart'
  version '0.7.0'
  url 'https://github.com/kulesa/redmine_better_gantt_chart'
  author_url 'http://github.com/kulesa'
  
  requires_redmine :version_or_higher => '1.1.0'

  settings(:default => {
    'work_on_weekends' => true,
    'smart_sorting' => true
  }, :partial => "better_gantt_chart_settings")
end
