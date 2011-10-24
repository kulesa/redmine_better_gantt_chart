require 'redmine_plugin_support'

Dir[File.expand_path(File.dirname(__FILE__)) + "/lib/tasks/**/*.rake"].sort.each { |ext| load ext }

RedminePluginSupport::Base.setup do |plugin|
  plugin.project_name = 'redmine_better_gantt_chart'
  plugin.default_task = [:spec, :features]
  plugin.tasks = [:doc, :release, :clean, :test, :db, :spec]
  plugin.redmine_root = ENV['REDMINE_ROOT'] || File.expand_path(File.dirname(__FILE__) + '/../../..')
end
