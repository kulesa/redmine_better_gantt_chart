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
      
      def all_precedes_issues
        dependencies = []
        relations_from.each do |relation|
          next unless relation.relation_type == IssueRelation::TYPE_PRECEDES
          dependencies << relation.issue_to
          dependencies += relation.issue_to.all_dependent_issues
        end
        dependencies
      end
      
    end
  end
end
