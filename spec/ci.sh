#!/usr/bin/env sh
cd spec && git clone https://github.com/edavis10/redmine.git dummy_redmine && cp ci_config/* dummy_redmine/config/ && cd dummy_redmine && git co 1.1.3 && bundle exec rake db:create db:migrate && cd ../.. && bundle exec rake spec
