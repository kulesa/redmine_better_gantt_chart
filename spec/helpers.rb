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

end
