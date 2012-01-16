module RedmineBetterGanttChart
  module Hooks
    class ViewIssuesFormDetailsBottomHook < Redmine::Hook::ViewListener
      render_on(:view_issues_form_details_bottom,
                :partial => "issues/edit_estimated_duration",
                :layout  => false)
    end
  end
end
