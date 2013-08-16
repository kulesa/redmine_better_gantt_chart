module RedmineBetterGanttChart
  module IssuesHelperPatch

      # Renders an extended HTML/CSS tooltip: includes information on related tasks
      #
      # To use, a trigger div is needed.  This is a div with the class of "tooltip"
      # that contains this method wrapped in a span with the class of "tip"
      #
      #    <div class="tooltip"><%= link_to_issue(issue) %>
      #      <span class="tip"><%= render_issue_tooltip(issue) %></span>
      #    </div>
      #
      def render_extended_issue_tooltip(issue)
        @cached_label_status ||= l(:field_status)
        @cached_label_start_date ||= l(:field_start_date)
        @cached_label_due_date ||= l(:field_due_date)
        @cached_label_assigned_to ||= l(:field_assigned_to)
        @cached_label_priority ||= l(:field_priority)
        @cached_label_project ||= l(:field_project)
        @cached_label_follows ||= l(:label_follows)
        @cached_label_precedes ||= l(:label_precedes)
        @cached_label_delay ||= l(:field_delay)        

        content = link_to_issue(issue) + (
          "<br /><br />" +
          "<strong>#{@cached_label_project}</strong>: #{link_to_project(issue.project)}<br />" +
          "<strong>#{@cached_label_status}</strong>: #{issue.status.name}<br />" +
          "<strong>#{@cached_label_start_date}</strong>: #{format_date(issue.start_date)}<br />" +
          "<strong>#{@cached_label_due_date}</strong>: #{format_date(issue.due_date)}<br />" +
          "<strong>#{@cached_label_assigned_to}</strong>: #{issue.assigned_to}<br />" +
          "<strong>#{@cached_label_priority}</strong>: #{issue.priority.name}"
        ).html_safe

        display_limit = 4 # That's max for a sane tooltip

        relation_from_link = lambda do |rel|
          "<strong>#{l(rel.label_for(issue))}</strong>: #{link_to_issue(rel.issue_from)}"
        end

        relation_to_link = lambda do |rel|
          "<strong>#{l(rel.label_for(issue))}</strong>: #{link_to_issue(rel.issue_to)}"
        end

        unless issue.relations_to.empty?
          content += ("<br />" + issue.relations_to.first(display_limit).map(&relation_from_link).join('<br />')).html_safe
          display_limit -= issue.relations_to.count
        end

        unless issue.relations_from.empty?
          new_limit = display_limit < 0 ? 0 : display_limit
          content += ("<br />" + issue.relations_from.first(new_limit).map(&relation_to_link).join('<br />')).html_safe
          display_limit -= issue.relations_from.count
        end

        content += "<br /><i>There are #{0-display_limit} more relations</i>" if display_limit < 0
        content
      end
    end

end
