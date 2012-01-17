require File.expand_path('../../spec_helper', __FILE__)

describe "Duration in workdays" do
  it "should work as normal difference between dates if scheduling on weeknds is enabled" do
    configure_plugin 'schedule_on_weekends' => true
    RedmineBetterGanttChart.workdays_between(Date.today, Date.today + 1.week).should == 8
  end

  it "should count only workdays if scheduling on weeknds is disabled" do
    configure_plugin 'schedule_on_weekends' => false
    RedmineBetterGanttChart.workdays_between(Date.today, Date.today + 1.week).should == 6
  end

  it "should be 1 for the same start and end dates" do
    friday = next_day_of_week(5)
    RedmineBetterGanttChart.workdays_between(friday, friday).should == 1
  end

  it "should calculate the difference if date to is earlier than date from" do
    thursday, friday = next_day_of_week(4), next_day_of_week(5)
    RedmineBetterGanttChart.workdays_between(friday, thursday).should ==
    RedmineBetterGanttChart.workdays_between(thursday, friday).should
  end
end

