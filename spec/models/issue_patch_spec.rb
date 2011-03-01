require File.dirname(__FILE__) + '/../spec_helper'

describe 'Issue Dependency Patch' do 

  before(:all) do 
    Issue.included_modules.should include(RedmineBetterGanttChart::IssueDependencyPatch)
  end
  
  before(:each) do 
    @tracker = Factory(:tracker)
    @project = Factory(:project)
    
    @start_date = Time.new()
    start_date, due_date = @start_date, @start_date + 3.days
    @first_issue = Factory(:issue, :project => @project, :tracker => @tracker, :start_date => start_date, :due_date => due_date) 
    @second_issue = Factory(:issue, :project => @project, :tracker => @tracker, :start_date => start_date, :due_date => due_date)
    @first_issue.relations << IssueRelation.create!(:issue_from => @first_issue, :issue_to => @second_issue, :relation_type => "precedes", :delay => 0)
    @first_issue.save!
    @first_issue.reload
    @second_issue.reload
  end

  it 'should change date of dependent task when due date of first task is moved forward' do
    lambda {
      @first_issue.due_date = @first_issue.due_date + 2.days
      @first_issue.save!
      @second_issue.reload
    }.should change(@second_issue, :start_date).to(@first_issue.due_date + 3.days)
  end

  it 'should change date of dependent task when due date of first task is moved back' do 
    lambda {
      @first_issue.due_date = @first_issue.due_date - 2.days
      @first_issue.save!
      @second_issue.reload
    }.should change(@second_issue, :start_date).to(@first_issue.due_date - 1.day)
  end
end

