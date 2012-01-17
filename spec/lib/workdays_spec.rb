require 'active_support'
require File.expand_path('../../helpers', __FILE__)
require File.expand_path('../../../lib/redmine_better_gantt_chart/redmine_better_gantt_chart', __FILE__)

describe "Duration in workdays" do
  include Helpers
  it "should work as normal difference between dates if scheduling on weeknds is enabled" do
    RedmineBetterGanttChart.stub(:schedule_on_weekends?).and_return(true)
    RedmineBetterGanttChart.workdays_between(Date.today, Date.today + 1.week).should == 8
  end

  it "should count only workdays if scheduling on weeknds is disabled" do
    RedmineBetterGanttChart.stub(:schedule_on_weekends?).and_return(false)
    RedmineBetterGanttChart.workdays_between(Date.today, Date.today + 1.week).should == 6
  end

  it "should be 1 for the same start and end dates" do
    RedmineBetterGanttChart.stub(:schedule_on_weekends?).and_return(true)
    friday = next_day_of_week(5)
    RedmineBetterGanttChart.workdays_between(friday, friday).should == 1
  end

  it "should calculate the difference if date to is earlier than date from" do
    RedmineBetterGanttChart.stub(:schedule_on_weekends?).and_return(true)
    thursday, friday = next_day_of_week(4), next_day_of_week(5)
    RedmineBetterGanttChart.workdays_between(friday, thursday).should ==
    RedmineBetterGanttChart.workdays_between(thursday, friday).should
  end

  it "should let calculate finish date" do
  end
end

