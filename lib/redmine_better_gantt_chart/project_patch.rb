module RedmineBetterGanttChart
  module ProjectPatch
    def self.included(base) # :nodoc:
      base.send(:include, InstanceMethods)
    end

    module InstanceMethods
      # Returns the project's related issues belonging to othe projects
      def cross_project_related_issues
        self.issues.each do |issue|
          related_issues = []
          issue.relations.each do |relation|
            related_issue = relation.other_issue(issue)
            related_issue.is_external = true
            related_issues << related_issue unless related_issue.project == issue.project
          end
          return related_issues
        end
      end
    end
  end
end
