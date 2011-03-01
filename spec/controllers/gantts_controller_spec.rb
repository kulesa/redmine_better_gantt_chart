require File.dirname(__FILE__) + '/../spec_helper'

describe GanttsController, '#show' do
  include Redmine::I18n
  integrate_views
        
  before(:all) do 
    @tracker = Factory(:tracker)
    @project = Factory(:project)
    
    @start_date = Time.new()
    start_date, due_date = @start_date, @start_date + 3.days
    @first_issue = Factory(:issue, :project => @project, :tracker => @tracker, :start_date => start_date, :due_date => due_date) 
    @second_issue = Factory(:issue, :project => @project, :tracker => @tracker, :start_date => start_date, :due_date => due_date)
    @first_issue.relations << IssueRelation.create!(:issue_from => @first_issue, :issue_to => @second_issue, :relation_type => "precedes", :delay => 0)
    @first_issue.save!
  end
  
  before(:each) do
    @current_user = mock_model(User, :admin? => true, :logged? => true, :language => :en, :active? => true, :memberships => [], :anonymous? => false, :name => "A Test   >User", :projects => Project)
    User.stub!(:current).and_return(@current_user)
    @current_user.stub!(:allowed_to?).and_return(true)
    @current_user.stub!(:pref).and_return({:gantt_zoom => 2, :gantt_months => 6})
    fake_pref = mock_model(Object)
    fake_pref.stub!(:save).and_return(true)
    @current_user.stub!(:preferences).and_return(fake_pref)
  end

  it 'should be successful' do
    get :show
    response.should be_success
  end

  it 'should have custom javascripts included' do 
    get :show
    response.should have_text(/raphael.min.js/)
    response.should have_text(/raphael.arrow.js/)
  end
  
  it 'should insert issue ids and follow tags to issue bars' do
    get :show
    response.should have_text(/div id='#{@first_issue.id}'/)
    response.should have_text(/div id='#{@second_issue.id}' follows='#{@first_issue.id}'/)
  end
  
end
