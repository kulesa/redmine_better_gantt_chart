require File.expand_path('../../spec_helper', __FILE__)

describe IssuesController do
  include Redmine::I18n
  integrate_views

  before(:each) do
    @current_user = Factory :user
    #@current_user = mock_model(User, :admin? => true, :logged? => true, :language => :en, :active? => true, :memberships => [], :anonymous? => false, :name => "A Test   >User", :projects => Project)
    User.stub!(:current).and_return(@current_user)
    @current_user.stub!(:allowed_to?).and_return(true)
    @current_user.stub!(:pref).and_return(Factory(:user_preference, :user_id => @current_user.id))
    @current_user.stub!(:mail)
  end

  let!(:issue) { Factory(:issue) }

  context "when calculation of estimated duration is enabled" do
    before  do
      configure_plugin 'calculate_duration' => true
    end

    it "should show estimated duration in issue details" do
      get :show, :id => issue.id
      response.should have_text(/th class=.estimated_duration./)
    end

    it "should show estimated duration on issue form" do
      get :edit, :id => issue.id
      response.should have_text(/input id=.issue_estimated_duration./)
    end
  end

  context "when calculation of estimated duration is disabled" do
    before  do
      configure_plugin 'calculate_duration' => true
    end

    describe "#show" do
      it "should NOT show estimated duration in issue details" do
        pending
      end
    end

    describe "#edit" do
      it "should NOT show estimated duration on issue form" do
        pending
      end
    end
  end
end

