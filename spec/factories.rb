# This should prevent creation of new instance when I want to use the only existing
saved_single_instances = {}
#Find or create the model instance
single_instances = lambda do |factory_key|
  begin
    saved_single_instances[factory_key].reload
  rescue NoMethodError, ActiveRecord::RecordNotFound
    #was never created (is nil) or was cleared from db
    saved_single_instances[factory_key] = Factory.create(factory_key)  #recreate
  end

  return saved_single_instances[factory_key]
end

def test_time
  @test_time ||= Time.zone.now.to_date
end

FactoryGirl.define do
  factory :user_preference do
    time_zone ''
    hide_mail false
    others {{:gantt_months=>6, :comments_sorting=>"asc", :gantt_zoom=>3, :no_self_notified=>true}}
  end

  factory :user do
    sequence(:firstname) {|n| "John#{n}"}
    lastname 'Kilmer'
    sequence(:login) {|n| "john_#{n}"}
    sequence(:mail) {|n| "john#{n}@local.com"}
    after_create do |u|
      Factory(:user_preference, :user => u)
    end
  end

  factory :admin, :parent => :user do
    admin true
  end

  factory :project do
    sequence(:name) {|n| "project#{n}"}
    identifier {|u| u.name }
    is_public true
  end

  factory :tracker do
    sequence(:name) { |n| "Feature #{n}" }
    sequence(:position) {|n| n}
  end

  factory :bug, :parent => :tracker do
    name 'Bug'
  end

  factory :main_project, :parent => :project do
    name 'The Main Project'
    identifier 'supaproject'
    after_create do |p|
      p.trackers << single_instances[:bug]; p.save!
    end
  end

  factory :issue_priority do
    sequence(:name) {|n| "Issue#{n}"}
  end

  factory :issue_status do
    sequence(:name) {|n| "status#{n}"}
    is_closed false
    is_default false
    sequence(:position) {|n| n}
  end

  factory :issue do
    sequence(:subject) {|n| "Issue_no_#{n}"}
    description {|u| u.subject}
    project { single_instances[:main_project] }
    tracker { single_instances[:bug] }
    priority { Factory(:issue_priority) }
    status { Factory(:issue_status) }
    author { Factory(:user) }
    start_date test_time
    due_date { |u| u.start_date + 3.days}
  end
end
