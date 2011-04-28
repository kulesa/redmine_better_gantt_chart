require File.dirname(__FILE__) + '/../spec_helper'

describe 'Improved issue dependencies management' do

  before(:each) do 
    @first_issue, @second_issue = create_related_issues("precedes")
  end

  it 'changes date of the dependent task when due date of the first task is moved forward' do
    lambda {
      @first_issue.due_date = @first_issue.due_date + 2.days
      @first_issue.save!
      @second_issue.reload
    }.should change(@second_issue, :start_date).to(@first_issue.due_date + 3.days)
  end

  it 'changes date of the dependent task when due date of the first task is moved back' do
    lambda {
      @first_issue.due_date = @first_issue.due_date - 2.days
      @first_issue.save!
      @second_issue.reload
    }.should change(@second_issue, :start_date).to(@first_issue.due_date - 1.day)
  end

  it 'doesn\'t allow set start date earlier than parent.soonest_start' do
    child_issue = Factory.build(:issue)
    child_issue.parent_issue_id = @second_issue.id
    lambda {
      child_issue.start_date = @second_issue.start_date - 1
      child_issue.save!
    }.should raise_error(ActiveRecord::RecordInvalid)
  end

  describe 'handles long dependency chains' do
    before do
      @start_issue = Factory(:issue) 
      @current_issue = @start_issue
      # Change X.times to a really big number to stress test rescheduling of a really long chain of dependent issues :)
      2.times do
        previous_issue, @current_issue = create_related_issues("precedes", @current_issue)
      end
    end

    it 'and reschedules tens of related issues when due date of the first issue is moved back' do
      puts "******* Long 1 **********"
      puts "First issue #{@start_issue.id}, start: #{@start_issue.start_date}, due: #{@start_issue.due_date}"
      si = Issue.find(@start_issue.id + 1)
      puts "Second issue #{si.id}, start: #{si.start_date}, due: #{si.due_date}"
      puts "Last issue #{@current_issue.id}, start: #{@current_issue.start_date}, due: #{@current_issue.due_date}"
     lambda {
        @start_issue.due_date = @start_issue.due_date - 2.days
        @start_issue.save!
        @current_issue.reload
      }.should change(@current_issue, :start_date).to(@current_issue.start_date - 2.days)
    end

    it 'and reschedules tens of related issues when due date of the first task is moved forth' do
      puts "******* Long 2 **********"
      puts "First issue #{@start_issue.id}, start: #{@start_issue.start_date}, due: #{@start_issue.due_date}"
      puts "Last issue #{@current_issue.id}, start: #{@current_issue.start_date}, due: #{@current_issue.due_date}"
     lambda {
        @start_issue.due_date = @start_issue.due_date + 2.days
        @start_issue.save!
        @current_issue.reload
      }.should change(@current_issue, :start_date).to(@current_issue.start_date + 2.days)
    end

    it 'and doesn\'t allow create circular dependencies' do
      lambda {
        create_related_issues("precedes", @current_issue, @start_issue)
      }.should raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe 'allows fast rescheduling of dependent issues' do
    before do
      # Testing on the following dependency chain:
      # @initial -> @related -> @parent [ @child1 -> @child2]
      @initial, @related = create_related_issues("precedes")
      @related, @parent = create_related_issues("precedes", @related)

      @child1 = Factory.build(:issue, :start_date => @parent.start_date)
      @child2 = Factory.build(:issue, :start_date => @parent.start_date)
      @child1.parent_issue_id = @parent.id
      @child2.parent_issue_id = @parent.id
      @child1.save!
      @child2.save!

      create_related_issues("precedes", @child1, @child2)
    end

  end
end

