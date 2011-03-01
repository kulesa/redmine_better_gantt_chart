require File.dirname(__FILE__) + '/../spec_helper'

describe GanttsController, '#show' do
  include Redmine::I18n
  integrate_views
        
  before(:all) do 
    @tracker = Factory(:tracker)
    @project = Factory(:project)
    
    @start_date = Time.new()
    start_date, due_date = @start_date, @start_date + 3.days
    
    # Precedes - Follows
    @preceding_issue = Factory(:issue, :project => @project, :tracker => @tracker, :start_date => start_date, :due_date => due_date) 
    @following_issue = Factory(:issue, :project => @project, :tracker => @tracker, :start_date => start_date, :due_date => due_date)
    @preceding_issue.relations << IssueRelation.create!(:issue_from => @preceding_issue, :issue_to => @following_issue, :relation_type => "precedes", :delay => 0)
    @preceding_issue.save!
    
    # Blocks - Blocked
    @blocks_issue = Factory(:issue, :project => @project, :tracker => @tracker, :start_date => start_date, :due_date => due_date) 
    @blocked_issue = Factory(:issue, :project => @project, :tracker => @tracker, :start_date => start_date, :due_date => due_date) 
    @blocks_issue.relations << IssueRelation.create!(:issue_from => @blocks_issue, :issue_to => @blocked_issue, :relation_type => "blocks", :delay => 0)
    @blocks_issue.save!

    # Duplicates - Duplicated
    @duplicates_issue = Factory(:issue, :project => @project, :tracker => @tracker, :start_date => start_date, :due_date => due_date) 
    @duplicated_issue = Factory(:issue, :project => @project, :tracker => @tracker, :start_date => start_date, :due_date => due_date) 
    @duplicates_issue.relations << IssueRelation.create!(:issue_from => @duplicates_issue, :issue_to => @duplicated_issue, :relation_type => "duplicates", :delay => 0)
    @duplicates_issue.save!

    # Relates
    @one_issue = Factory(:issue, :project => @project, :tracker => @tracker, :start_date => start_date, :due_date => due_date) 
    @other_issue = Factory(:issue, :project => @project, :tracker => @tracker, :start_date => start_date, :due_date => due_date) 
    @one_issue.relations << IssueRelation.create!(:issue_from => @one_issue, :issue_to => @other_issue, :relation_type => "relates", :delay => 0)
    @one_issue.save!
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
  
  it 'should insert issue ids and follow tags' do
    get :show
    response.should have_text(/div id='#{@preceding_issue.id}'/)
    response.should have_text(/div id='#{@following_issue.id}' follows='#{@preceding_issue.id}'/)
  end
  
  it 'should insert blocked tags' do
    get :show
    response.should have_text(/div id='#{@blocks_issue.id}'/)
    response.should have_text(/div id='#{@blocked_issue.id}' blocked='#{@blocks_issue.id}'/)
  end
  
  it 'should insert duplicated tags' do
    get :show
    response.should have_text(/div id='#{@duplicates_issue.id}'/)
    response.should have_text(/div id='#{@duplicated_issue.id}' duplicated='#{@duplicates_issue.id}'/)
  end
  
  it 'should insert relates tags' do
    get :show
    response.should have_text(/div id='#{@one_issue.id}'/)
    response.should have_text(/div id='#{@other_issue.id}' relates='#{@one_issue.id}'/)
  end
  
  it 'should insert an array of ids to a tag' do
    @blocks_issue.relations << IssueRelation.create!(:issue_from => @blocks_issue, :issue_to => @duplicated_issue, :relation_type => "duplicates", :delay => 0)
    @blocks_issue.save!

    get :show
    response.should have_text(/duplicated='#{@duplicates_issue.id},#{@blocks_issue.id}'/)
  end

  it 'should mix different relation types' do 
    @blocks_issue.relations << IssueRelation.create!(:issue_from => @blocks_issue, :issue_to => @duplicated_issue, :relation_type => "duplicates", :delay => 0)
    @blocks_issue.save!
    @one_issue.relations << IssueRelation.create!(:issue_from => @one_issue, :issue_to => @duplicated_issue, :relation_type => "relates")
    @one_issue.save!

    get :show
    response.should have_text(/duplicated='#{@duplicates_issue.id},#{@blocks_issue.id}' relates='#{@one_issue.id}'/)
  end
end
