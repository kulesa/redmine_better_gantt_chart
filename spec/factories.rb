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
  @test_time ||= Time.new()
end

Factory.define :user_preference do |p|
  p.time_zone ''
  p.hide_mail false
  p.others {{:gantt_months=>6, :comments_sorting=>"asc", :gantt_zoom=>3, :no_self_notified=>true}}
end

Factory.define :user do |u|
  u.sequence(:firstname) {|n| "John#{n}"}
  u.lastname 'Kilmer'
  u.sequence(:login) {|n| "john_#{n}"}
  u.sequence(:mail) {|n| "john#{n}@local.com"} 
  u.association :preference, :factory => :user_preference
end

Factory.define :admin, :parent => :user do |u|
  u.admin true
end

Factory.define :project do |p|
  p.sequence(:name) {|n| "project#{n}"}
  p.identifier {|u| u.name }
  p.is_public true
  # enabled_modules
end

Factory.define :tracker do |t| 
   t.sequence(:name) { |n| "Feature #{n}" }
   t.sequence(:position) {|n| n}
end

Factory.define :bug, :parent => :tracker do |t|
  t.name 'Bug'
end

Factory.define :main_project, :parent => :project do |project|
  project.name 'The Main Project'
  project.identifier 'supaproject'
  project.after_create { |p| p.trackers << single_instances[:bug]; p.save! }
end

Factory.define :issue_priority do |i|
  i.sequence(:name) {|n| "Issue#{n}"}
end

Factory.define :issue_status do |s|
  s.sequence(:name) {|n| "status#{n}"}
  s.is_closed false
  s.is_default false
  s.sequence(:position) {|n| n}
end

Factory.define :issue do |i|
  i.sequence(:subject) {|n| "Issue_no_#{n}"}
  i.description {|u| u.subject}
  i.project { single_instances[:main_project] }
  i.tracker { single_instances[:bug] }
  i.association :priority, :factory => :issue_priority
  i.association :status, :factory => :issue_status
  i.association :author, :factory => :user
  i.start_date { test_time }
  i.due_date { |u| u.start_date + 3.days}
end
