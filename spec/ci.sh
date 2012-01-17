echo "Setting up dummy Redmine"
git clone https://github.com/edavis10/redmine.git spec/dummy_redmine 
echo "Checking out branch 1.3"
cd spec/dummy_redmine && git checkout origin/1.3-stable
echo "Copying database.yml"
cp ../ci_config/database.ci.yml config/database.yml  
echo "Cloning the plugin to dummy Redmine plugins folder"
git clone ../.. vendor/plugins/redmine_better_gantt_chart
echo "Migrating database"
RAILS_ENV=test bundle exec rake db:create db:migrate db:migrate_plugins
cd vendor/plugins/redmine_better_gantt_chart && bundle install
