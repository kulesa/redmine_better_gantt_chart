module Helpers
  def create_related_issues(relation_type, from_issue = Factory(:issue), to_issue = Factory(:issue))
    from_issue.relations << IssueRelation.create!(:issue_from => from_issue, :issue_to => to_issue, :relation_type => relation_type)
    from_issue.save!
    [from_issue, to_issue].map(&:reload)
  end

  def relate_issues(from_issue, to_issue, relation_type = 'precedes')
   from_issue.relations <<  IssueRelation.create!(:issue_from => from_issue, :issue_to => to_issue, :relation_type => relation_type)
   from_issue.save!
   [from_issue, to_issue].map(&:reload)
  end

  def work_on_weekends(wow)
    RedmineBetterGanttChart.stub(:work_on_weekends?).and_return(wow)
  end
  
  # Useful for debugging - draws ASCII gantt chart
  def draw_tasks(start, *tasks)
    tasks.each { |t| t.reload }
    tasks.each { |task| draw_from_date(start, task) }
  end

  def draw_from_date(date_from, issue)
    start_date = issue.start_date
    due_date = issue.due_date || issue.start_date
  end
end
