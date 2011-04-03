require File.dirname(__FILE__) + '/../spec_helper'

describe 'Issue Dependency Patch' do 

  before(:each) do 
    @first_issue, @second_issue = create_related_issues("precedes")
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

