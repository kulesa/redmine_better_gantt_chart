module RedmineBetterGanttChart
  module IssueDependencyPatch
    def self.included(base) # :nodoc:
      base.send(:include, InstanceMethods)

      base.class_eval do
        alias_method_chain :reschedule_following_issues, :fast_update
        alias_method_chain :reschedule_after, :earlier_date
        alias_method_chain :soonest_start, :dependent_parent_validation
      end
    end
  
    module InstanceMethods

      # Redefined to work without recursion on AR objects
      def reschedule_following_issues_with_fast_update
        if start_date_changed? || due_date_changed?
          cache_and_apply_changes do
            reschedule_dependent_issue
          end
        end
      end

      # Prepare changes for all dependent issues
      def reschedule_dependent_issue(issue = self, options = {}) #start_date_to = nil, due_date_to = nil
        cache_change(issue, options)

        # If this is a PARENT issue
        if !issue.leaf?
          childs_with_nil_start_dates = []

          issue.leaves.each do |leaf|
            # if parent task has start == nil, change to start date of the child
            start_date =       cached_value(issue, :start_date) 
            child_start_date = cached_value(leaf, :start_date)

            if start_date.nil?
              cache_change(issue, :start_date => child_start_date)
            end

            if (start_date > child_start_date) or
               (start_date < child_start_date and issue.start_date == leaf.start_date)
              reschedule_dependent_issue(leaf, :start_date => start_date)
            end
          end
        end

        issue.relations_from.each do |relation|
          if relation.issue_to && relation.relation_type == IssueRelation::TYPE_PRECEDES
            if due_date = cached_value(issue, :due_date)
              reschedule_dependent_issue(relation.issue_to, :start_date => due_date + relation.delay + 1)
            end
          end
        end

        # If this is a CHILD issue - update parent's start and due dates
        update_parent_start_and_due(issue) if issue.parent_id
      end

      # Cache changes, and apply them in transaction
      def cache_and_apply_changes(&block)
        @changes = {} # a hash of changes to be applied later, will contain values like this: { issue_id => {:start_date => ..., :end_date => ...}}
        @parents = {} # a hash of children for any affected parent issue
        yield
        # Align parents start and end dates
        reschedule_parents()
        # Sorting of cached changes by due_date should let pass start_date validations if issues are updated in this order.
        ordered_changes = []
        @changes.each {|c| ordered_changes << [c[1][:due_date] || c[1][:start_date], c]}
        ordered_changes.sort!
        # Let's disable all calbacks for now
        Issue.with_all_callbacks_disabled do
          transaction do
            ordered_changes.each do |the_changes|
              issue_id, changes = the_changes[1]
              issue = Issue.find(issue_id)
              changes.each_pair do |key, value|
                changes.delete(key) if issue.send(key) == value.to_date
              end
              unless changes.empty?
                issue.update_attributes(changes)
              end
            end
          end
        end
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
        if options.empty?
          # Just caching current values, if issue cache doesn't exist yet
          new_start_date = issue.start_date unless @changes[issue_id][:start_date]
          new_due_date   = issue.due_date unless @changes[issue_id][:due_date]

        elsif options[:start_date] && options[:due_date]
          # Changing both dates
          new_start_date = options[:start_date]
          new_due_date   = options[:due_date]

        elsif options[:start_date]
          # Start date changed => change the due date
          new_start_date = options[:start_date]
          if options[:parent]
            new_due_date = issue.due_date
          else
            new_due_date = issue.due_date + (new_start_date - issue.start_date)
          end
        elsif options[:due_date]
          # Due date changed => change the start date
          new_due_date = options[:due_date]
          if options[:parent]
            new_start_date = issue.start_date
          else
            new_start_date = issue.start_date + (issue.due_date - new_due_date)
          end
        end
        @changes[issue_id][:start_date] = new_start_date.to_date if new_start_date
        @changes[issue_id][:due_date]   = new_due_date.to_date if new_due_date
      end

      # Returns cached value or caches it if it hasn't been cached yet
      def cached_value(issue, attr)
        if issue.is_a?(Integer)
          issue_id = issue
        else
          issue_id = issue.id
        end
        cache_change(issue_id) unless @changes[issue_id]
        case attr
        when :start_date
          @changes[issue_id][:start_date]
        when :due_date
          @changes[issue_id][:due_date] || @changes[issue_id][:start_date]
        end
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

      # Changes behaviour of reschedule_after method
      def reschedule_after_with_earlier_date(date)      
        return if date.nil?
        if start_date.nil? || start_date != date
          if leaf?
            self.start_date, self.due_date = date, date + duration
          else
            self.start_date = date
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
