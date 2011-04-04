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

  describe 'Long dependency chain' do
    before do
      @start_issue = Factory(:issue) 
      @current_issue = @start_issue
      # Change X.times to a really big number to stress test rescheduling of a really long chain of dependent issues :)
      3.times do 
        previous_issue, @current_issue = create_related_issues("precedes", @current_issue)
      end
    end

    it 'should reschedule tens of related issues when moving due date back' do 
     lambda {
        @start_issue.due_date = @start_issue.due_date - 2.days
        @start_issue.save!
        @current_issue.reload
      }.should change(@current_issue, :start_date).to(@current_issue.start_date - 2.days)
    end

    it 'should reschedule tens of related issues when moving due date forth' do 
     lambda {
        @start_issue.due_date = @start_issue.due_date + 2.days
        @start_issue.save!
        @current_issue.reload
      }.should change(@current_issue, :start_date).to(@current_issue.start_date + 2.days)
    end

    it 'should not allow to create circular dependencies' do
      lambda {
        create_related_issues("precedes", @current_issue, @start_issue)
      }.should raise_error(ActiveRecord::RecordInvalid)
    end
   end

    it 'should not allow set start date earlier than parent.soonest_start' do
      child_issue = Factory.build(:issue)
      child_issue.parent_issue_id = @second_issue.id
      lambda {
        child_issue.start_date = @second_issue.start_date - 1
        child_issue.save!
      }.should raise_error(ActiveRecord::RecordInvalid)
    end
end

