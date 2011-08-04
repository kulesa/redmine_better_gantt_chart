require File.dirname(__FILE__) + '/../spec_helper'

describe 'Improved issue dependencies management' do
  # Useful for debugging - draws ASCII gantt chart
  def draw_tasks(start, tasks)
    tasks.each { |t| t.reload }
    tasks.each { |task| draw_from_date(start, task) }
  end

  def draw_from_date(date_from, issue)
    start_date = issue.start_date
    due_date = issue.due_date || issue.start_date
    puts " "*(start_date - date_from) + "#"*(due_date - start_date)
  end

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
  
  it "doesn't fail when removing an only child issue from the parent" do
    parent_issue, next_issue = create_related_issues("precedes")
    child_issue = Factory(:issue)
    child_issue.parent_issue_id = parent_issue.id
    child_issue.save!
    parent_issue.reload

    lambda {
      child_issue.parent_issue_id = nil
      child_issue.save!
    }.should_not raise_error(NoMethodError)
  end

  it "doesn't fail when assigning start_date to a child issue when parent's start_date is empty and siblings' start_dates are empty" do
    parent_issue = Factory(:issue, :start_date => nil, :due_date => nil)
    child_issue1 = Factory(:issue, :start_date => nil, :due_date => nil)
    child_issue2 = Factory(:issue, :start_date => nil, :due_date => nil)
    child_issue1.parent_issue_id = parent_issue.id
    child_issue2.parent_issue_id = parent_issue.id
    child_issue1.save!
    child_issue2.save!
    parent_issue.reload

    lambda {
      child_issue1.start_date = Date.today
      child_issue1.save!
    }.should_not raise_error(ArgumentError)
  end

  it "doesn't fail when an issue without start or due date becomes a parent issue" do
    parent_issue = Factory(:issue, :start_date => nil, :due_date => nil)
    child_issue = Factory(:issue, :due_date => nil)

    lambda {
      child_issue.parent_issue_id = parent_issue.id
      child_issue.save!
    }.should_not raise_error(NoMethodError)
  end
  
   describe 'handles long dependency chains' do
     before do
       @start_issue = Factory(:issue)
       @current_issue = @start_issue
       # Change X.times to a really big number to stress test rescheduling of a really long chain of dependent issues :)
       20.times do
         previous_issue, @current_issue = create_related_issues("precedes", @current_issue)
       end
     end
  
     it 'and reschedules tens of related issues when due date of the first issue is moved back' do
       si = Issue.find(@start_issue.id + 1)
      lambda {
         @start_issue.due_date = @start_issue.due_date - 2.days
         @start_issue.save!
         @current_issue.reload
       }.should change(@current_issue, :start_date).to(@current_issue.start_date - 2.days)
     end
  
     it 'and reschedules tens of related issues when due date of the first task is moved forth' do
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
      @child1.save!
      @child2.parent_issue_id = @parent.id
      @child2.save!

      create_related_issues("precedes", @child1, @child2)
    end
       
    it "should change start date of the last dependend child issue when due date of the first issue moved FORWARD" do
     lambda {
       @initial.due_date = @initial.due_date + 2.days
       @initial.save!
       @child2.reload
     }.should change(@child2, :start_date).to(@child2.start_date + 2.days)
    end

    it "should change start date of the last dependend child issue when due date of the first issue moved BACK" do
     lambda {
       @initial.due_date = @initial.due_date - 2.days
       @initial.save!
       @child2.reload
     }.should change(@child2, :start_date).to(@child2.start_date - 2.days)
    end
    
    it "should not fail when due_date of one of rescheduled issues is nil" do 
        initial, child = create_related_issues("precedes")
        parent = Factory(:issue, :due_date => nil)
        other_child = Factory(:issue, :due_date => nil)
        child.parent_issue_id = parent.id
        child.save!
        other_child.parent_issue_id = parent.id
        other_child.save!
        parent.reload
        other_child.reload
        puts "other child due: #{other_child.due_date}, parent due: #{parent.due_date}"
        child.destroy
    end
    

    it "should reschedule start date of parent task of a dependend child task" do
      parent_a = Factory(:issue)
      child_a = Factory.build(:issue, :start_date => parent_a.start_date)
      child_b = Factory.build(:issue, :start_date => parent_a.start_date)
      child_a.parent_issue_id = parent_a.id
      child_b.parent_issue_id = parent_a.id
      child_a.save!
      child_b.save!

      child_a, child_b = create_related_issues("precedes", child_a, child_b)

      parent_b = Factory(:issue)
      child_c = Factory.build(:issue, :start_date => parent_b.start_date)
      child_d = Factory.build(:issue, :start_date => parent_b.start_date)
      child_c.parent_issue_id = parent_b.id
      child_d.parent_issue_id = parent_b.id
      child_c.save!
      child_d.save!

      child_b, child_c = create_related_issues("precedes", child_b, child_c)
      child_c, child_d = create_related_issues("precedes", child_c, child_d)

      parent_b.reload

      parent_start  = parent_b.start_date
      parent_due    = parent_b.due_date 

      child_a.due_date = child_a.due_date - 2.days
      child_a.save!
      parent_b.reload

      parent_b.start_date.should == parent_start - 2.days
      parent_b.due_date.should   == parent_due - 2.days
    end
  end
end
