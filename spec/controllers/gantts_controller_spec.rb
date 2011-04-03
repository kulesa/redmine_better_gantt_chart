require File.dirname(__FILE__) + '/../spec_helper'

describe GanttsController, '#show' do
  include Redmine::I18n
  integrate_views
        
  before(:all) do 
    # Precedes - Follows
    @preceding_issue, @following_issue = create_related_issues("precedes")
    
    # Blocks - Blocked
    @blocks_issue, @blocked_issue = create_related_issues("blocks")
    
    # Duplicates - Duplicated
    @duplicates_issue, @duplicated_issue = create_related_issues("duplicates")

    # Relates
    @one_issue, @other_issue = create_related_issues("relates")
  end
  
  before(:each) do
    @current_user = mock_model(User, :admin? => true, :logged? => true, :language => :en, :active? => true, :memberships => [], :anonymous? => false, :name => "A Test   >User", :projects => Project)
    User.stub!(:current).and_return(@current_user)
    @current_user.stub!(:allowed_to?).and_return(true)
    @current_user.stub!(:pref).and_return(Factory(:user_preference, :user_id => @current_user.id))
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
