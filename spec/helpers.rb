module Helpers
  
  # Useful for debugging - draws ASCII gantt chart
  def draw_tasks(start, tasks)
    tasks.each { |t| t.reload }
    tasks.each { |task| draw_from_date(start, task) }
  end

  def draw_from_date(date_from, issue)
    start_date = issue.start_date
    due_date = issue.due_date || issue.start_date
    puts " "*(start_date - date_from) + "#"*(due_date - start_date)
  end

  # Returns nearest requested day of week, for example
  # next_day_of_week(5) will return next Friday
  def next_day_of_week(wday)
    Date.today + wday - Date.today.wday
  end

end
