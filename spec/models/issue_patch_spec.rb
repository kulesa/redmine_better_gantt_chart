require File.expand_path('../../spec_helper', __FILE__)

describe 'Improved issue dependencies management' do
  context 'with work on weekends enabled' do
    before(:all) do
      work_on_weekends true
    end

    before(:each) do
      @first_issue, @second_issue = create_related_issues("precedes")
    end

    it "issue duration is in calendar days" do
      issue = Factory(:issue, :start_date => Date.today, :due_date => Date.today + 1.week)
      issue.duration.should == 8
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
      expect {
        child_issue.start_date = @second_issue.start_date - 1
        child_issue.save!
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "doesn't fail when removing an only child issue from the parent" do
      parent_issue, next_issue = create_related_issues("precedes")
      child_issue = Factory(:issue)
      child_issue.parent_issue_id = parent_issue.id
      child_issue.save!
      parent_issue.reload

      expect {
        child_issue.parent_issue_id = nil
        child_issue.save!
      }.not_to raise_error()
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

      expect {
        child_issue1.start_date = Date.today
        child_issue1.save!
      }.not_to raise_error()
    end

    it "doesn't fail when start_date of an issue deep in hierarchy is changed from empty" do
      parent_issue = Factory(:issue, :start_date => nil, :due_date => nil)
      child_issue1 = Factory(:issue, :start_date => nil, :due_date => nil)
      child_issue2 = Factory(:issue, :start_date => nil, :due_date => nil)
      child_issue1.parent_issue_id = parent_issue.id
      child_issue2.parent_issue_id = parent_issue.id
      child_issue1.save!
      child_issue2.save!

      child_issue1_1 = Factory(:issue, :start_date => nil, :due_date => nil)
      child_issue1_2 = Factory(:issue, :start_date => nil, :due_date => nil)
      child_issue1_1.parent_issue_id = child_issue1.id
      child_issue1_2.parent_issue_id = child_issue1.id
      child_issue1_1.save!
      child_issue1_2.save!

      child_issue2_1 = Factory(:issue, :start_date => nil, :due_date => nil)
      child_issue2_2 = Factory(:issue, :start_date => nil, :due_date => nil)
      child_issue2_1.parent_issue_id = child_issue2.id
      child_issue2_2.parent_issue_id = child_issue2.id
      child_issue2_1.save!
      child_issue2_2.save!

      expect {
        child_issue2_2.start_date = Date.today
        child_issue2_2.save!
      }.not_to raise_error()
    end

    it "doesn't fail when an issue without start or due date becomes a parent issue" do
      parent_issue = Factory(:issue, :start_date => nil, :due_date => nil)
      child_issue = Factory(:issue, :due_date => nil)

      expect {
        child_issue.parent_issue_id = parent_issue.id
        child_issue.save!
      }.not_to raise_error()
    end

    describe 'handles long dependency chains' do
      before do
        @start_issue = Factory(:issue)
        @current_issue = @start_issue
        # Change X.times to a really big number to stress test rescheduling of a really long chain of dependent issues :)
        3.times do
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
        expect {
          create_related_issues("precedes", @current_issue, @start_issue)
        }.to raise_error(ActiveRecord::RecordInvalid)
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

      it "should reshedule a following task of a parent task, when the parent task itself being rescheduled after changes in it's child task" do
        parent = Factory(:issue)
        child  = Factory(:issue, :start_date => Date.today,
                                 :due_date   => Date.today + 1,
                                 :parent_issue_id => parent.id)
        follower = Factory(:issue, :start_date => Date.today, :due_date => Date.today + 1)
        relate_issues parent, follower

        child.update_attributes(:due_date => Date.today + 7)
        parent.reload
        follower.reload

        follower.start_date.should == parent.due_date + 1
      end
    end
  end

  context "when work on weekends is disabled" do
    before(:all) do
      work_on_weekends false
    end

    it "issue duration is in working days" do
      issue = Factory(:issue, :start_date => Date.today, :due_date => Date.today + 1.week)
      issue.duration.should == 6
    end

    it "should reschedule after with earlier date" do
      monday = RedmineBetterGanttChart::Calendar.next_day_of_week(1)
      @first_issue  = Factory(:issue, :start_date => monday, :due_date => monday + 1)
      @second_issue = Factory(:issue, :start_date => monday, :due_date => monday + 1)

      lambda {
        relate_issues(@first_issue, @second_issue)
      }.should change(@second_issue, :due_date).to(monday + 3)

    end

    it "lets create a relation between issues without due dates" do
      pop = Factory(:issue)
      parent_issue = Factory(:issue, :start_date => Date.today, :due_date => nil)
      issue1 = Factory(:issue, :start_date => Date.today, :due_date => nil)
      issue1.update_attributes!(:parent_issue_id => parent_issue.id)
      issue2 = Factory(:issue, :start_date => Date.today, :due_date => nil)
      issue2.update_attributes!(:parent_issue_id => parent_issue.id)
      relate_issues(issue2, issue1, "follows")

      issue1.reload
      issue1.relations.count.should == 1
    end

  end
end
