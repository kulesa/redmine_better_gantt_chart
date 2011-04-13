module RedmineBetterGanttChart
  module IssuePatch
    def self.included(base) # :nodoc:
      base.send(:include, InstanceMethods)
    end

    module InstanceMethods
      # Defines whether this issue is marked as external from the current project
      def is_external=(flag)
        @external = flag
      end

       # Returns whether this issue is marked as external from the current project
      def is_external
        if @external == nil
          return false
        end
        @external
      end
    end
  end
end
