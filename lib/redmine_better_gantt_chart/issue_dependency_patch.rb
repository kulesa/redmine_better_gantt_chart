module RedmineBetterGanttChart
  module IssueDependencyPatch
    def self.included(base) # :nodoc:
      base.send(:include, InstanceMethods)

      base.class_eval do
        alias_method_chain :reschedule_after, :earlier_date
        alias_method_chain :soonest_start, :dependent_parent_validation
      end
    end
  
    module InstanceMethods
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
