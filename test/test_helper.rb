# Load the normal Rails helper
require File.expand_path(File.dirname(__FILE__) + '/../../../../test/test_helper')
# require 'factory_girl'
# require 'factory_girl/syntax/blueprint'
# require 'factory_girl/syntax/make'
# require 'factory_girl/syntax/sham'
require 'faker'

# Ensure that we are using the temporary fixture path
Engines::Testing.set_fixture_path

# class Test::Unit::TestCase
#     include Factory::Syntax::Methods
# end
Rails::Initializer.run do |config|
  config.gem "thoughtbot-shoulda", :lib => "shoulda", :source => "http://gems.github.com"
  config.gem "machinist", :lib => "machinist", :source => "http://gems.github.com"
end

require File.expand_path(File.dirname(__FILE__) + '/blueprints/blueprint')