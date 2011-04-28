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

      # Cache changes, and apply them in transaction
      def cache_and_apply_changes(&block)
        @changes = {}
        yield
        # And now, TADA: highly experimental sorting of changes by due_date.
        # It should let pass start_date validations if processed in this order.
        # I'm so tired of this shit.
        ordered_changes = []
        @changes.each {|c| ordered_changes << [[c[1][:due_date]], c]}
        ordered_changes.sort!
        puts ordered_changes.inspect
        transaction do
          ordered_changes.each do |the_changes|
            issue_id = the_changes[0]
            changes = the_changes[1]

            issue = Issue.find(issue_id)
            changes.each_pair do |key, value|
              changes.delete(key) if issue.send(key) == value.to_date
            end
            unless changes.empty?
              puts "Updating #{changes.inspect} of #{issue_id}"
              issue.update_attributes!(changes)
            end
          end
        end
      end

      # Cache changes to be applied later
      # if no attributes to change given, just caches current values
      def cache_change(issue, options = {})
        #puts "cache change called for #{issue.id}, with #{options.inspect}"
        @changes[issue.id] ||= {}
        if options.empty?
          # Just caching current values
          new_start_date = issue.start_date
          new_due_date   = issue.due_date
        elsif options[:start_date] && options[:due_date]
          # Changing both dates
          new_start_date = options[:start_date]
          new_due_date   = options[:due_date]
        elsif options[:start_date]
          # Start date changed => change the due date
          new_start_date = options[:start_date]
          new_due_date   = issue.due_date + (new_start_date - issue.start_date) + 1
        elsif options[:due_date]
          # Due date changed => change the start date
          new_due_date = options[:due_date]
          new_start_date = issue.start_date + (issue.due_date - new_due_date) + 1
        end
        #puts "Going go assign #{new_start_date}, #{new_due_date}"
        @changes[issue.id][:start_date] = new_start_date.to_date
        @changes[issue.id][:due_date]   = new_due_date.to_date
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

      # Prepare changes for all dependent issues
      def reschedule_dependent_issue(issue = self, options = {}) #start_date_to = nil, due_date_to = nil
        #puts "Reschedule called for #{issue.id} with #{options.inspect}"
        cache_change(issue, options)

        # If there is a CHILD issue - update parent's start and due dates
        update_parent_start_and_due(issue) if issue.parent
        #start_date_to_be = issue.children.minimum(:start_date)
        #due_date_to_be = issue.children.maximum(:due_date)
        #if start_date_to_be && due_date_to_be && due_date_to_be < start_date_to_be
          #start_date_to_be, due_date_to_be = due_date_to_be, start_date_to_be
        #end

        # If this is a PARENT issue
        if !issue.leaf?
          issue.leaves.each do |leaf|
            reschedule_dependent_issue(leaf, { :start_date => @changes[issue.id][:start_date]})
          end
        end

        issue.relations_from.each do |relation|
          if relation.issue_to && relation.relation_type == IssueRelation::TYPE_PRECEDES
            reschedule_dependent_issue(relation.issue_to, { :start_date => cached_value(issue, :due_date) + relation.delay })
          end
        end
      end

      def update_parent_start_and_due(issue)
        if cached_value(issue.parent, :start_date) > cached_value(issue, :start_date)
          cache_change(parent, {:start_date => cached_value(issue, :start_date)})
        end

        if cached_value(issue.parent, :due_date) > cached_value(issue, :due_date)
          cache_change(issue.parent, {:due_date => cached_value(issue, :due_date)})
        end
      end

      # Extends behavior of reschedule_after method to also handle
      # cases where start_date > date, that is, when due date of the previous task
      # is changed for an earlier date. 

      def reschedule_after_with_earlier_date(date)      
        return if date.nil?
        if leaf?
          if start_date.nil? || start_date > date
            self.start_date, self.due_date = date, date + duration
            save
          else
            reschedule_after_without_earlier_date(date)
          end
        else
          leaves.each do |leaf|
            leaf.reschedule_after(date)
          end
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
