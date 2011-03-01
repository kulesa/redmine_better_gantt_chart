Factory.define :user do |u|
  u.sequence(:firstname) {|n| "John#{n}"}
  u.lastname 'Kilmer'
  u.sequence(:login) {|n| "john_#{n}"}
  u.sequence(:mail) {|n| "john#{n}@local.com"} 
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

Factory.define :project_with_tracker, :parent => :project do |project|
  project.after_create { |p| p.trackers << Factory(:tracker); p.save! }
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
  i.association :project
  i.association :tracker
  i.association :priority, :factory => :issue_priority
  i.association :status, :factory => :issue_status
  i.association :author, :factory => :user
end
