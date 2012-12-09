# Patching GanttsController to use our own gantt helper
module RedmineBetterGanttChart
  module GanttsControllerPatch
    def self.included(base)
     base.send(:include, InstanceMethods) 

     base.class_eval do 
       alias_method_chain :show, :custom_helper
     end
    end

    module InstanceMethods
      def show_with_custom_helper
        @gantt = Redmine::Helpers::BetterGantt.new(params)
        @gantt.project = @project
        retrieve_query
        @query.group_by = nil
        @gantt.query = @query if @query.valid?

        basename = (@project ? "#{@project.identifier}-" : '') + 'gantt'

        respond_to do |format|
          format.html { render :action => "show", :layout => !request.xhr? }
          format.png  { send_data(@gantt.to_image, :disposition => 'inline', :type => 'image/png', :filename => "#{basename}.png") } if @gantt.respond_to?('to_image')
          format.pdf  { send_data(@gantt.to_pdf, :type => 'application/pdf', :filename => "#{basename}.pdf") }
        end
      end
      
      def edit_gantt
        date_from = Date.parse(params[:date_from])
        date_to = Date.parse(params[:date_to])
        months = date_to.month - date_from.month + 1
        params[:year] = date_from.year
        params[:month] = date_from.month
        params[:months] = months
        @gantt = Redmine::Helpers::BetterGantt.new(params)
        @gantt.project = @project
        text, status = @gantt.edit(params)
        render :text=>text, :status=>status
      end

      def find_optional_project
        begin
          if params[:action] && params[:action].to_s == "edit_gantt"
            @project = Project.find(params[:project_id]) unless params[:project_id].blank?
            allowed = User.current.allowed_to?(:edit_issues, @project, :global => true)
            if allowed
              return true
            else
              render :text => l(:text_edit_gantt_lack_of_permission), :status=>403
            end
          else
            super
          end
        rescue => e
          return e.to_s + "\n===\n" + [$!,$@.join("\n")].join("\n")
        end
      end
      
    end
  end
end
