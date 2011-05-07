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
          issue.leaves.each do |leaf|
            # Tricky thing: if start date of an issue equals to the parent's start date, I *assume* that change of parent's start date
            # must trigger change of the child's start date. That might NOT be the case.
            if (cached_value(issue, :start_date) > cached_value(leaf, :start_date)) or
               (cached_value(issue, :start_date) < cached_value(leaf, :start_date) and issue.start_date == leaf.start_date)
              reschedule_dependent_issue(leaf, :start_date => cached_value(issue, :start_date))
            end
          end
        end

        issue.relations_from.each do |relation|
          if relation.issue_to && relation.relation_type == IssueRelation::TYPE_PRECEDES
            reschedule_dependent_issue(relation.issue_to, :start_date => cached_value(issue, :due_date) + relation.delay + 1)
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
        # And now, TADA: highly experimental sorting of changes by due_date.
        # It should let pass start_date validations if issues are updated in this order.
        ordered_changes = []
        @changes.each {|c| ordered_changes << [c[1][:due_date], c]}
        ordered_changes.sort!
        # Let's disable all calbacks for now because this will change only dates
        Issue.with_all_callbacks_disabled do
          transaction do
            ordered_changes.each do |the_changes|
              issue_id = the_changes[1][0]
              changes = the_changes[1][1]
              issue = Issue.find(issue_id)
              changes.each_pair do |key, value|
                changes.delete(key) if issue.send(key) == value.to_date
              end
              unless changes.empty?
                issue.update_attributes!(changes)
              end
            end
          end
        end
      end

      # Cache changes to be applied later
      # if no attributes to change given, just caches current values
      # use :parent => true to just change one date without changing the other.
      #
      # If no options is provided existing, issue cache is initialized, that is,
      # an cache will not be updated.
      def cache_change(issue, options = {})
        @changes[issue.id] ||= {}
        if options.empty?
          # Just caching current values, if issue cache doesn't exist yet
          new_start_date = issue.start_date unless @changes[issue.id][:start_date]
          new_due_date   = issue.due_date unless @changes[issue.id][:due_date]

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
        @changes[issue.id][:start_date] = new_start_date.to_date if new_start_date
        @changes[issue.id][:due_date]   = new_due_date.to_date if new_due_date
      end

      def cached_value(issue, attr)
        cache_change(issue) unless @changes[issue.id]
        case attr
        when :start_date
          @changes[issue.id][:start_date]
        when :due_date
          @changes[issue.id][:due_date] || @changes[issue.id][:start_date]
        end
      end


      # So what fucking now...
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

        if cached_value(issue, :start_date) < min_parent_start(current_parent_id)
          cache_change(issue.parent, :start_date => cached_value(issue, :start_date), :parent => true)
        end

        if cached_value(issue, :due_date) > max_parent_due(current_parent_id)
          cache_change(issue.parent, :due_date => cached_value(issue, :due_date), :parent => true)
        end
      end

      def min_parent_start(current_parent_id)
        min = nil
        @parents[current_parent_id].uniq.each do |child_id|
          current_child_start = cached_value(Issue.find(child_id), :start_date) #@changes[child_id][:start_date]
          min ||= current_child_start
          min = current_child_start if current_child_start < min
        end
        min
      end

      def max_parent_due(current_parent_id)
        max = nil
        @parents[current_parent_id].each do |child_id|
          current_child_due = @changes[child_id][:due_date]
          max ||= current_child_due
          max = current_child_due if current_child_due > max
        end
        max
      end

      # Extends behavior of reschedule_after method to also handle
      # cases where start_date > date, that is, when due date of the previous task
      # is changed for an earlier date. 

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
