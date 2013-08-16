require File.expand_path('../../spec_helper', __FILE__)

describe IssuesController do
  include Redmine::I18n
  render_views

  before(:each) do
    @current_user = Factory :user
    User.stub(:current).and_return(@current_user)
    @current_user.stub(:allowed_to?).and_return(true)
    @current_user.stub(:pref).and_return(Factory(:user_preference, :user_id => @current_user.id))
    @current_user.stub(:mail)
  end

  let!(:issue) { Factory(:issue) }

  it "should show estimated duration in issue details" do
    get :show, :id => issue.id
    response.should have_text(/th class=.duration./)
  end
end

