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
    end
  end
end
