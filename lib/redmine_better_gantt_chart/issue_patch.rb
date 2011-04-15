module RedmineBetterGanttChart
  module IssuePatch
    def self.included(base) # :nodoc:
      base.send(:include, InstanceMethods)
    end

    module InstanceMethods
      # Defines whether this issue is marked as external from the current project
      def external=(flag)
        @external = flag
      end

       # Returns whether this issue is marked as external from the current project
      def external?
        !!@external
      end
    end
  end
end
