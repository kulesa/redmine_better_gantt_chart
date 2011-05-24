module RedmineBetterGanttChart
  module GanttHelperPatch
    def self.included(base) # :nodoc:
      base.send(:include, InstanceMethods)

      base.class_eval do
        alias_method_chain :html_task, :arrows
        alias_method_chain :gantt_issue_compare, :sorting
        alias_method_chain :render_project, :cross_project_issues
        alias_method_chain :number_of_rows_on_project, :cross_project_issues
        alias_method_chain :html_subject, :cross_project_issues
        alias_method_chain :subject_for_issue, :cross_project_issues
      end
    end
  
    module InstanceMethods
      # Adds task div ids and relation attribute attribute, which contains list of related tasks
      def html_task_with_arrows(params, coords, options={})
        output = ''
        # Renders the task bar, with progress and late
        
        if options[:issue]
          issue = options[:issue]          
          issue_id = "#{issue.id}"          
          relations = {}
          issue.relations_to.each do |relation|
            relation_type = relation.relation_type_for(relation.issue_to) 
            (relations[relation_type] ||= []) << relation.issue_from_id
          end
          issue_relations = relations.inject("") {|str,rel| str << " #{rel[0]}='#{rel[1].join(',')}'" }
        end
        
        if coords[:bar_start] && coords[:bar_end]
          if options[:issue]
            output << "<div id='#{issue_id}'#{issue_relations}style='top:#{ params[:top] }px;left:#{ coords[:bar_start] }px;width:#{ coords[:bar_end] - coords[:bar_start] - 2}px;' class='#{options[:css]} task_todo'>&nbsp;</div>"
          else
            output << "<div style='top:#{ params[:top] }px;left:#{ coords[:bar_start] }px;width:#{ coords[:bar_end] - coords[:bar_start] - 2}px;' class='#{options[:css]} task_todo'>&nbsp;</div>"            
          end
          
          if coords[:bar_late_end]
            output << "<div style='top:#{ params[:top] }px;left:#{ coords[:bar_start] }px;width:#{ coords[:bar_late_end] - coords[:bar_start] - 2}px;' class='#{options[:css]} task_late'>&nbsp;</div>"
          end
          if coords[:bar_progress_end]
            output << "<div style='top:#{ params[:top] }px;left:#{ coords[:bar_start] }px;width:#{ coords[:bar_progress_end] - coords[:bar_start] - 2}px;' class='#{options[:css]} task_done'>&nbsp;</div>"
          end
        end
        # Renders the markers
        if options[:markers]
          if coords[:start]
            output << "<div style='top:#{ params[:top] }px;left:#{ coords[:start] }px;width:15px;' class='#{options[:css]} marker starting'>&nbsp;</div>"
          end
          if coords[:end]
            output << "<div style='top:#{ params[:top] }px;left:#{ coords[:end] + params[:zoom] }px;width:15px;' class='#{options[:css]} marker ending'>&nbsp;</div>"
          end
        end
        # Renders the label on the right
        if options[:label]
          output << "<div style='top:#{ params[:top] }px;left:#{ (coords[:bar_end] || 0) + 8 }px;' class='#{options[:css]} label'>"
          output << options[:label]
          output << "</div>"
        end
        # Renders the tooltip
        if options[:issue] && coords[:bar_start] && coords[:bar_end]
          output << "<div class='tooltip' style='position: absolute;top:#{ params[:top] }px;left:#{ coords[:bar_start] }px;width:#{ coords[:bar_end] - coords[:bar_start] }px;height:12px;'>"
          output << '<span class="tip">'
          output << view.render_extended_issue_tooltip(options[:issue])
          output << "</span></div>"
        end
        @lines << output
        output
      end

      # Fixes issues sorting as per http://www.redmine.org/issues/7335
      def gantt_issue_compare_with_sorting(x, y, issues = nil)
        [(x.root.start_date or x.start_date or Date.new()), x.root_id, (x.start_date or Date.new()), x.lft] <=> [(y.root.start_date or y.start_date or Date.new()), y.root_id, (y.start_date or Date.new()), y.lft]
      end

      # Adds cross-project related issues to rendering
      def render_project_with_cross_project_issues(project, options={})
        subject_for_project(project, options) unless options[:only] == :lines
        line_for_project(project, options) unless options[:only] == :subjects
        
        options[:top] += options[:top_increment]
        options[:indent] += options[:indent_increment]
        @number_of_rows += 1
        return if abort?

        issues = project_issues(project).select {|i| i.fixed_version.nil?}
        sort_issues!(issues)
        if issues
          render_issues(issues, options)
          return if abort?
        end
        
        versions = project_versions(project)
        versions.each do |version|
          render_version(project, version, options)
        end

        #project.children.visible.has_module('issue_tracking').each do |project|
          #render_project(project, options)
          #return if abort?
        #end unless project.leaf?
       
        # Remove indent to hit the next sibling
        options[:indent] -= options[:indent_increment]
      end

      # Adds cross-project related issues to counting
      def number_of_rows_on_project_with_cross_project_issues(project)
        count = self.number_of_rows_on_project_without_cross_project_issues(project)

        count += project.cross_project_related_issues

        count
      end

      # Prefixes cross-project related issues with their project name
      def subject_for_issue_with_cross_project_issues(issue, options)
        while @issue_ancestors.any? && !issue.is_descendant_of?(@issue_ancestors.last)
          @issue_ancestors.pop
          options[:indent] -= options[:indent_increment]
        end

        output = case options[:format]
        when :html
          css_classes = ''
          css_classes << ' issue-overdue' if issue.overdue?
          css_classes << ' issue-behind-schedule' if issue.behind_schedule?
          css_classes << ' icon icon-issue' unless Setting.gravatar_enabled? && issue.assigned_to

          subject = "<span class='#{css_classes}'>"
          if issue.assigned_to.present?
            assigned_string = l(:field_assigned_to) + ": " + issue.assigned_to.name
            subject << view.avatar(issue.assigned_to, :class => 'gravatar icon-gravatar', :size => 10, :title => assigned_string).to_s
          end
          subject << "(" + view.link_to_project(issue.project) + ") " if issue.external?
          subject << view.link_to_issue(issue)
          subject << '</span>'
          html_subject(options, subject, :css => "issue-subject", :title => issue.subject, :external => issue.external?) + "\n"
        when :image
          image_subject(options, issue.subject)
        when :pdf
          pdf_new_page?(options)
          pdf_subject(options, issue.subject)
        end

        unless issue.leaf?
          @issue_ancestors << issue
          options[:indent] += options[:indent_increment]
        end

        output
      end

      # Renders subjects of cross-project related issues in italic
      def html_subject_with_cross_project_issues(params, subject, options={})
        style = "position: absolute;top:#{params[:top]}px;left:#{params[:indent]}px;"
        style << "width:#{params[:subject_width] - params[:indent]}px;" if params[:subject_width]
        style << "font-style:italic;" if options[:external]

        output = view.content_tag 'div', subject, :class => options[:css], :style => style, :title => options[:title]
        @subjects << output
        output
      end
    end
  end
end
