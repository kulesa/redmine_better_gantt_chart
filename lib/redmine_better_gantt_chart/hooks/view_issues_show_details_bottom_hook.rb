module RedmineBetterGanttChart
  module Hooks
    class ViewIssuesShowDetailsBottomHook < Redmine::Hook::ViewListener
      include Redmine::I18n

      render_on(:view_issues_show_details_bottom,
                :partial => 'issues/show_estimated_duration',
                :layout  => false)
    end
  end
end
