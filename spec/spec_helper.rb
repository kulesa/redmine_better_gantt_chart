# This file is copied to ~/spec when you run 'ruby script/generate rspec'
# from the project root directory.
ENV["RAILS_ENV"] = "test"
require 'active_record'
require 'active_record/connection_adapters/abstract_adapter'
require 'active_record/connection_adapters/abstract_mysql_adapter'

# Allows loading of an environment config based on the environment
redmine_root = ENV["REDMINE_ROOT"] || File.dirname(__FILE__) + "/../../.."
require File.expand_path(redmine_root + "/config/environment", __FILE__)
require 'rspec/rails'
require 'factory_girl'

require File.expand_path(File.dirname(__FILE__) + '/factories.rb')
require File.expand_path(File.dirname(__FILE__) + '/helpers')

RSpec.configure do |config|
  config.use_transactional_fixtures = false
  require 'database_cleaner'
  DatabaseCleaner.strategy = :truncation
  config.include Helpers
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run_including :focus => true

  config.before(:suite) do
    DatabaseCleaner.clean
  end
end
