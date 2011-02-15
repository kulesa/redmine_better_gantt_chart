module RedmineIssueDependency
  module IssueDependencyPatch
    def self.included(base) # :nodoc:
      base.send(:include, InstanceMethods)

      base.class_eval do
        alias_method_chain :reschedule_after, :earlier_date
      end
    end
  
    module InstanceMethods
      # Extends behavior of reschedule_after method to also handle
      # cases where start_date > date, that is, when due date of the previous task decreased 
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
    end
  end
end