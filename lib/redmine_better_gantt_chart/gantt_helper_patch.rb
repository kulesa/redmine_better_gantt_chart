module RedmineBetterGanttChart
  module GanttHelperPatch
    def self.included(base) # :nodoc:
      base.send(:include, InstanceMethods)

      base.class_eval do
        alias_method_chain :html_task, :arrows
        alias_method_chain :gantt_issue_compare, :sorting
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
    end
  end
end
