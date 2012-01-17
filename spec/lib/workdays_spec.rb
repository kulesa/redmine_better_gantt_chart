require 'active_support'
require File.expand_path('../../helpers', __FILE__)
require File.expand_path('../../../lib/redmine_better_gantt_chart/redmine_better_gantt_chart', __FILE__)

describe "Duration in workdays" do
  include Helpers

  before(:each) do
    RedmineBetterGanttChart.stub(:schedule_on_weekends?).and_return(true)
  end

  let!(:thursday) { RedmineBetterGanttChart.next_day_of_week(4) }
  let!(:friday)   { RedmineBetterGanttChart.next_day_of_week(5) }
  let!(:saturday) { RedmineBetterGanttChart.next_day_of_week(6) }

  it "should tell next requested day of week" do
    yesterday_date_of_week = Date.yesterday.wday
    RedmineBetterGanttChart.next_day_of_week(yesterday_date_of_week).should == Date.today + 6.days
  end

  it "should work as normal difference between dates if scheduling on weeknds is enabled" do
    RedmineBetterGanttChart.workdays_between(Date.today, Date.today + 1.week).should == 8
  end

  it "should count only workdays if scheduling on weeknds is disabled" do
    RedmineBetterGanttChart.stub(:schedule_on_weekends?).and_return(false)
    RedmineBetterGanttChart.workdays_between(Date.today, Date.today + 1.week).should == 6
  end

  it "should be 1 for the same start and end dates" do
    RedmineBetterGanttChart.workdays_between(friday, friday).should == 1
  end

  it "should calculate the difference if date to is earlier than date from" do
    RedmineBetterGanttChart.workdays_between(friday, thursday).should ==
    RedmineBetterGanttChart.workdays_between(thursday, friday).should
  end

  it "should tell next working day is friday if today is friday" do
    RedmineBetterGanttChart.next_working_day(friday).should == friday
  end

  it "should tell next working day is saturday if today is saturday and scheduling on weekends is enabled" do
    RedmineBetterGanttChart.stub(:schedule_on_weekends?).and_return(true)
    RedmineBetterGanttChart.next_working_day(saturday).should == saturday
  end

  it "should tell next working day is monday if today is saturday and scheduling on weekends is disabled" do
    RedmineBetterGanttChart.stub(:schedule_on_weekends?).and_return(false)
    RedmineBetterGanttChart.next_working_day(saturday).should == saturday + 2.days
  end

  it "should let calculate finish date based on duration and start date with scheduling on weekends" do
    RedmineBetterGanttChart.stub(:schedule_on_weekends?).and_return(true)
    RedmineBetterGanttChart.workdays_from_date(Date.today, 7).should == Date.today + 1.week
  end

  it "should let calculate finish date based on duration and start date without scheduling on weekends" do
    RedmineBetterGanttChart.stub(:schedule_on_weekends?).and_return(false)
    RedmineBetterGanttChart.workdays_from_date(Date.today, 5).should == Date.today + 1.week
  end

  it "should calculate start date based on duration and finish date" do
    RedmineBetterGanttChart.should_receive(:workdays_from_date).with(Date.today, -5)
    RedmineBetterGanttChart.workdays_before_date(Date.today, 5)
  end
end
