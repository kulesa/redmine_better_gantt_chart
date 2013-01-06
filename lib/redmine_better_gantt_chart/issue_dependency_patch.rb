module RedmineBetterGanttChart
  module IssueDependencyPatch
    def self.included(base) # :nodoc:
      base.send(:include, InstanceMethods)

      base.class_eval do
        alias_method_chain :reschedule_following_issues, :fast_update
        alias_method_chain :reschedule_on!, :earlier_date
        alias_method_chain :soonest_start, :dependent_parent_validation
        alias_method_chain :duration, :work_days
      end
    end
  
    module InstanceMethods

      def create_journal_entry
        create_journal
      end

      # Redefined to work without recursion on AR objects
      def reschedule_following_issues_with_fast_update
        if start_date_changed? || due_date_changed?
          cache_and_apply_changes do
            reschedule_dependent_issue
          end
        end
      end

      def cache_and_apply_changes(&block)
        @changes = {} # a hash of changes to be applied later, will contain values like this: { issue_id => {:start_date => ..., :end_date => ...}}
        @parents = {} # a hash of children for any affected parent issue

        yield

        reschedule_parents
        ordered_changes = prepare_and_sort_changes_list(@changes)

        Issue.with_all_callbacks_disabled do
          transaction do
            ordered_changes.each do |the_changes|
              issue_id, changes = the_changes[1]
              apply_issue_changes(issue_id, changes)
            end
          end
        end
      end

      def prepare_and_sort_changes_list(changes_list)
        ordered_changes = []
        changes_list.each do |c| 
          ordered_changes << [c[1][:due_date] || c[1][:start_date], c]
        end
        ordered_changes.sort!
      end

      def apply_issue_changes(issue_id, changes)
        issue = Issue.find(issue_id)
        changes.each_pair do |key, value|
          changes.delete(key) if issue.send(key) == value.to_date
        end
        unless changes.empty?
          issue.init_journal(User.current, I18n.t('task_moved_journal_entry'))
          issue.update_attributes(changes)
          issue.create_journal_entry
        end
      end

      def reschedule_dependent_issue(issue = self, options = {}) #start_date_to = nil, due_date_to = nil
        cache_change(issue, options)
        process_child_issues(issue) if !issue.leaf?
        process_following_issues(issue)
        update_parent_start_and_due(issue) if issue.parent_id
      end

      def process_child_issues(issue)
        childs_with_nil_start_dates = []

        issue.leaves.each do |leaf|
          start_date =       cached_value(issue, :start_date) 
          child_start_date = cached_value(leaf, :start_date)

          cache_change(issue, :start_date => child_start_date) if start_date.nil?

          if child_start_date.nil? or 
             (start_date > child_start_date) or
             (start_date < child_start_date and issue.start_date == leaf.start_date)
            reschedule_dependent_issue(leaf, :start_date => start_date)
          end
        end
      end

      def process_following_issues(issue)
        issue.relations_from.each do |relation|
          if is_a_link_with_following_issue?(relation) && due_date = cached_value(issue, :due_date)
            new_start_date = RedmineBetterGanttChart::Calendar.workdays_from_date(due_date, relation.delay) + 1.day
            new_start_date = RedmineBetterGanttChart::Calendar.next_working_day(new_start_date)
            reschedule_dependent_issue(relation.issue_to, :start_date => new_start_date)
          end
        end
      end

      def is_a_link_with_following_issue?(relation)
        relation.issue_to && relation.relation_type == IssueRelation::TYPE_PRECEDES
      end

      def reschedule_parents
        @parents.each_pair do |parent_id, children|
          parent_min_start = min_parent_start(parent_id)
          parent_max_start = max_parent_due(parent_id)
          cache_change(parent_id, :start_date => parent_min_start, 
                                  :due_date   => parent_max_start)

          children.each do |child| # If parent's start is changing, change start_date of any childs that have empty start_date
            if cached_value(child, :start_date).nil?
              cache_change(child, :start_date => parent_min_start, :parent => true)
            end
          end

          process_following_issues(Issue.find(parent_id))
        end
      end
      
      # Caches changes to be applied later. If no attributes to change given, just caches current values.
      # Use :parent => true to just change one date without changing the other. If :parent is not specified, 
      # change of one of the issue dates will cause change of the other.
      #
      # If no options is provided existing, issue cache is initialized.
      def cache_change(issue, options = {})
        if issue.is_a?(Integer)
          issue_id = issue
          issue = Issue.find(issue_id) unless options[:start_date] && options[:due_date] # optimization for the case when issue is not required
        else
          issue_id = issue.id
        end

        @changes[issue_id] ||= {}
        new_dates = {}

        if options.empty? || (options[:start_date] && options[:due_date])
          # Both or none dates changed
          [:start_date, :due_date].each do |attr|
            new_dates[attr] = options[attr] || @changes[issue_id][attr] || issue.send(attr)
          end
        else
          # One of the dates changed - change another accordingly
          changed_attr = options[:start_date] && :start_date || :due_date
          other_attr   = if changed_attr == :start_date then :due_date else :start_date end

          new_dates[changed_attr] = options[changed_attr]
          if issue.send(other_attr)
            if options[:parent]
              new_dates[other_attr] = issue.send(other_attr)
            else
              new_dates[other_attr] = RedmineBetterGanttChart::Calendar.workdays_from_date(issue.send(other_attr), new_dates[changed_attr] - issue.send(changed_attr))
            end
          end
        end

        [:start_date, :due_date].each do |attr|
          @changes[issue_id][attr] = new_dates[attr].to_date if new_dates[attr]
        end
      end

      # Returns cached value or caches it if it hasn't been cached yet
      def cached_value(issue, attr)
        issue_id = issue.is_a?(Integer) ? issue : issue.id 
        cache_change(issue_id) unless @changes[issue_id]
        @changes[issue_id][attr] || @changes[issue_id][:start_date]
      end

      # Each time we update cache of a child issue, need to update cache of the parent issue
      # by setting start_date to min(parent.all_children) and due_date to max(parent.all_children).
      # Apparently, to do so, first we need to add to cache all child issues of the parent, even if
      # they are not affected by rescheduling.
      def update_parent_start_and_due(issue)
        current_parent_id = issue.parent_id
        unless @parents[current_parent_id]
          # This parent is touched for the first time, let's cache it's children
          @parents[current_parent_id] = [issue.id] # at least the current issue is a child - even if it is not saved yet (is is possible?)
          issue.parent.children.each do |child|
            cache_change(child) unless @changes[child]
            @parents[current_parent_id] << child.id
          end
        end
      end

      def min_parent_start(current_parent_id)
        @parents[current_parent_id].uniq.inject(Date.new(5000)) do |min, child_id| # Someone needs to update this before 01/01/5000
          min = min < (current_child_start = cached_value(child_id, :start_date)) ? min : current_child_start rescue min
        end
      end

      def max_parent_due(current_parent_id)
        @parents[current_parent_id].uniq.inject(Date.new) do |max, child_id|
          max = max > (current_child_due = cached_value(child_id, :due_date)) ? max : current_child_due rescue max
        end
      end

      # Returns the time scheduled for this issue in working days.
      #
      def duration_with_work_days
        if self.start_date && self.due_date
          RedmineBetterGanttChart::Calendar.workdays_between(self.start_date, self.due_date)
        else
          0
        end
      end

      # Changes behaviour of reschedule_on method
      def reschedule_on_with_earlier_date!(date)      
        return if date.nil?

        if start_date.blank? || start_date != date
          self.start_date = date
          if due_date.present?
            self.due_date = RedmineBetterGanttChart::Calendar.workdays_from_date(date, duration - 1)
          end
          save
        end
      end    

      # Modifies validation of soonest start date for a new task:
      # if parent task has dependency, start date cannot be earlier than start date of the parent.
      def soonest_start_with_dependent_parent_validation
        @soonest_start ||= (
          relations_to.collect{|relation| relation.successor_soonest_start} +
          ancestors.collect(&:soonest_start) + 
          [parent_start_constraint]
        ).compact.max
      end

      # Returns [soonest_start_date] if parent task has dependency contstraints
      # or [nil] otherwise
      def parent_start_constraint
        if parent_issue_id && @parent_issue
          @parent_issue.soonest_start
        else
          nil
        end
      end
    end
  end
end
