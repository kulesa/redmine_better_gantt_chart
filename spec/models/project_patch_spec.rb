require File.dirname(__FILE__) + '/../spec_helper'

describe 'Project Dependency Patch' do

  before(:all) do
    Setting.cross_project_issue_relations = '1'

    # Issue 1 of Project 1 precedes issue 2 of the same project
    # Issue 1 precedes an issue of Project 2
    # Issue 2 precedes an issue of Project 3
    @first_project_issue1, @first_project_issue2 = create_related_issues("precedes")
    @project1 = @first_project_issue1.project
    @project2, @project3 = Factory(:project), Factory(:project)
    @second_project_issue = Factory(:issue, :project => @project2)
    @third_project_issue = Factory(:issue, :project => @project3)
    create_related_issues("precedes", @first_project_issue1, @second_project_issue)
    create_related_issues("precedes", @first_project_issue2, @third_project_issue)
  end

  it 'should find cross project related issues' do
    @project1.cross_project_related_issues.count.should eql(2)
    @project1.cross_project_related_issues.should include(@second_project_issue, @third_project_issue)
  end

  it 'should find cross project related issues of other projects' do
    @project2.cross_project_related_issues.count.should eql(1)
    @project2.cross_project_related_issues.should include(@first_project_issue1)
  end
end
