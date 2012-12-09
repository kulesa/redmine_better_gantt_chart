module RedmineBetterGanttChart
  module ApplicationHelperPatch

    def gantt_calendar_for(field_id)
      include_calendar_headers_tags
      javascript_tag("$(function() { $('##{field_id}').datepicker(datepickerOptions); });")
    end
    
  end
end
