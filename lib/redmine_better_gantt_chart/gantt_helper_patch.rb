module RedmineBetterGanttChart
  module GanttHelperPatch
    def self.included(base) # :nodoc:
      base.send(:include, InstanceMethods)

      base.class_eval do
        alias_method_chain :html_task, :arrows
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
          i_width = coords[:bar_end] - coords[:bar_start] - 2
          output << "<div id='ev_#{options[:kind]}#{options[:id]}' style='position:absolute;left:#{coords[:bar_start]}px;top:#{params[:top]}px;padding-top:3px;height:18px;width:#{ i_width + 100}px;' #{options[:kind] == 'i' ? "class='handle'" : ""}>"
          
          if options[:issue]
            output << "<div id='task_todo_#{options[:kind]}#{options[:id]}'#{issue_relations}style='float:left:0px; width:#{ i_width}px;' class='#{options[:css]} task_todo onpage'>&nbsp;</div>"
          else
             output << "<div id='task_todo_#{options[:kind]}#{options[:id]}' style='float:left:0px; width:#{ i_width}px;' class='#{options[:css]} task_todo'>&nbsp;</div>"
          end
          
          if coords[:bar_late_end]
            l_width = coords[:bar_late_end] - coords[:bar_start] - 2
            output << "<div id='task_late_#{options[:kind]}#{options[:id]}' style='float:left:0px; width:#{ l_width}px;' class='#{ l_width == 0 ? options[:css] + " task_none" : options[:css] + " task_late"}'>&nbsp;</div>"
          else
            output << "<div id='task_late_#{options[:kind]}#{options[:id]}' style='float:left:0px; width:0px;' class='#{ options[:css] + " task_none"}'>&nbsp;</div>"
          end
          if coords[:bar_progress_end]
            d_width = coords[:bar_progress_end] - coords[:bar_start] - 2
            output << "<div id='task_done_#{options[:kind]}#{options[:id]}' style='float:left:0px; width:#{ d_width}px;' class='#{ d_width == 0 ? options[:css] + " task_none" : options[:css] + " task_done"}'>&nbsp;</div>"
          else
            output << "<div id='task_done_#{options[:kind]}#{options[:id]}' style='float:left:0px; width:0px;' class='#{ options[:css] + " task_none"}'>&nbsp;</div>"
          end
          output << "</div>"
        else
          output << "<div id='ev_#{options[:kind]}#{options[:id]}' style='position:absolute;left:0px;top:#{params[:top]}px;padding-top:3px;height:18px;width:0px;' #{options[:kind] == 'i' ? "class='handle'" : ""}>"
          output << "<div id='task_todo_#{options[:kind]}#{options[:id]}' style='float:left:0px; width:0px;' class='#{ options[:css]} task_todo'>&nbsp;</div>"
          output << "<div id='task_late_#{options[:kind]}#{options[:id]}' style='float:left:0px; width:0px;' class='#{ options[:css] + " task_none"}'>&nbsp;</div>"
          output << "<div id='task_done_#{options[:kind]}#{options[:id]}' style='float:left:0px; width:0px;' class='#{ options[:css] + " task_none"}'>&nbsp;</div>"
          output << "</div>"
        end
        # Renders the markers
        if options[:markers]
          if coords[:start]
            output << "<div id='marker_start_#{options[:kind]}#{options[:id]}' style='top:#{ params[:top] }px;left:#{ coords[:start] }px;width:15px;' class='#{options[:css]} marker starting'>&nbsp;</div>"
          end
          if coords[:end]
            output << "<div id='marker_end_#{options[:kind]}#{options[:id]}' style='top:#{ params[:top] }px;left:#{ coords[:end] + params[:zoom] }px;width:15px;' class='#{options[:css]} marker ending'>&nbsp;</div>"
          end
        end
        # Renders the label on the right
        if options[:label]
          output << "<div id='label_#{options[:kind]}#{options[:id]}' style='top:#{ params[:top] }px;left:#{ (coords[:bar_end] || 0) + 8 }px;' class='#{options[:css]} label'>"
          output << options[:label]
          output << "</div>"
        end
        # Renders the tooltip
        if options[:issue] && coords[:bar_start] && coords[:bar_end]
          output << "<div id='tt_#{options[:kind]}#{options[:id]}' class='tooltip' style='position: absolute;top:#{ params[:top] }px;left:#{ coords[:bar_start] }px;width:#{ coords[:bar_end] - coords[:bar_start] }px;height:12px;'>"
          output << '<span class="tip">'
          output << view.render_extended_issue_tooltip(options[:issue])
          output << "</span></div>"

          output << view.draggable_element("ev_#{options[:kind]}#{options[:id]}", :revert =>false, :scroll=>"'gantt-container'", :constraint => "'horizontal'", :snap=>params[:zoom],:onEnd=>'function( draggable, event )  {issue_moved(draggable.element);}')
        end
        @lines << output
        output
      end
    end
  end
end
