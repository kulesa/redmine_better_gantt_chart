# Redmine - project management software
# Copyright (C) 2006-2011  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

module Redmine
  module Helpers
    # Simple class to handle gantt chart data
    class BetterGantt
      include ERB::Util
      include Redmine::I18n

      # :nodoc:
      # Some utility methods for the PDF export
      class PDF
        MaxCharactorsForSubject = 45
        TotalWidth = 280
        LeftPaneWidth = 100

        def self.right_pane_width
          TotalWidth - LeftPaneWidth
        end
      end

      attr_reader :year_from, :month_from, :date_from, :date_to, :zoom, :months, 
                  :truncated, :max_rows, :work_on_weekends
      attr_accessor :query
      attr_accessor :project
      attr_accessor :view

      def initialize(options={})
        options = options.dup

        if options[:year] && options[:year].to_i >0
          @year_from = options[:year].to_i
          if options[:month] && options[:month].to_i >=1 && options[:month].to_i <= 12
            @month_from = options[:month].to_i
          else
            @month_from = 1
          end
        else
          @month_from ||= Date.today.month
          @year_from ||= Date.today.year
        end

        zoom = (options[:zoom] || User.current.pref[:gantt_zoom]).to_i
        @zoom = (zoom > 0 && zoom < 5) ? zoom : 2
        months = (options[:months] || User.current.pref[:gantt_months]).to_i
        @months = (months > 0 && months < 25) ? months : 6
        @work_on_weekends = RedmineBetterGanttChart.work_on_weekends?
        work_on_weekends = @work_on_weekends

        # Save gantt parameters as user preference (zoom and months count)
        if (User.current.logged? && (@zoom != User.current.pref[:gantt_zoom] || @months != User.current.pref[:gantt_months]))
          User.current.pref[:gantt_zoom], User.current.pref[:gantt_months] = @zoom, @months
          User.current.preference.save
        end

        @date_from = Date.civil(@year_from, @month_from, 1)
        @date_to = (@date_from >> @months) - 1

        @subjects = ''
        @lines = ''
        @calendars = ''
        @number_of_rows = nil

        @issue_ancestors = []

        @truncated = false
        if options.has_key?(:max_rows)
          @max_rows = options[:max_rows]
        else
          @max_rows = Setting.gantt_items_limit.blank? ? nil : Setting.gantt_items_limit.to_i
        end
      end

      def common_params
        { :controller => 'gantts', :action => 'show', :project_id => @project }
      end

      def params
        common_params.merge({  :zoom => zoom, :year => year_from, 
                               :month => month_from, :months => months,
                               :work_on_weekends => work_on_weekends })
      end

      def params_previous
        common_params.merge({:year => (date_from << months).year, 
                             :month => (date_from << months).month, 
                             :zoom => zoom, :months => months, 
                             :work_on_weekends => work_on_weekends })
      end

      def params_next
        common_params.merge({:year => (date_from >> months).year, 
                             :month => (date_from >> months).month, 
                             :zoom => zoom, :months => months, 
                             :work_on_weekends => work_on_weekends })
      end

      # Returns the number of rows that will be rendered on the Gantt chart
      def number_of_rows
        return @number_of_rows if @number_of_rows

        rows = projects.inject(0) {|total, p| total += number_of_rows_on_project(p)}
        rows > @max_rows ? @max_rows : rows
      end

      # Returns the number of rows that will be used to list a project on
      # the Gantt chart.  This will recurse for each subproject.
      # Adds cross-project related issues to counting
      def number_of_rows_on_project(project)
        return 0 unless projects.include?(project)

        count = 1
        count += project_issues(project).size
        count += project_versions(project).size
        count
      end

      # Renders the subjects of the Gantt chart, the left side.
      def subjects(options={})
        render(options.merge(:only => :subjects)) unless @subjects_rendered
        @subjects
      end

      # Renders the lines of the Gantt chart, the right side
      def lines(options={})
        render(options.merge(:only => :lines)) unless @lines_rendered
        @lines
      end

      # Renders the calendars of the Gantt chart, the right side
      def calendars(options={})
        render(options.merge(:only => :calendars)) unless @calendars_rendered
        @calendars
      end

      # Returns issues that will be rendered
      def issues
        @issues ||= @query.issues(
          :include => [:assigned_to, :tracker, :priority, :category, :fixed_version],
          :order => "#{Project.table_name}.lft ASC, #{Issue.table_name}.id ASC",
          :limit => @max_rows
        )
      end

      # Return all the project nodes that will be displayed
      def projects
        return @projects if @projects

        ids = issues.collect(&:project).uniq.collect(&:id)
        if ids.any?
          # All issues projects and their visible ancestors
          @projects = Project.visible.all(
            :joins => "LEFT JOIN #{Project.table_name} child ON #{Project.table_name}.lft <= child.lft AND #{Project.table_name}.rgt >= child.rgt",
            :conditions => ["child.id IN (?)", ids],
            :order => "#{Project.table_name}.lft ASC"
          ).uniq
        else
          @projects = []
        end
      end

      # Returns the issues that belong to +project+
      def project_issues(project)
        @issues_by_project ||= issues.group_by(&:project)
        @issues_by_project[project] || []
      end

      # Returns the distinct versions of the issues that belong to +project+
      def project_versions(project)
        project_issues(project).collect(&:fixed_version).compact.uniq
      end

      # Returns the issues that belong to +project+ and are assigned to +version+
      def version_issues(project, version)
        project_issues(project).select {|issue| issue.fixed_version == version}
      end

      def render(options={})
        options = {:top => 0, :top_increment => 20, :indent_increment => 20, :render => :subject, :format => :html}.merge(options)
        indent = options[:indent] || 4

        if options[:format] == :html
          @subjects = '' unless options[:only] == :lines && options[:only] == :calendars
          @lines = '' unless options[:only] == :subjects && options[:only] == :calendars
          @calendars = '' unless options[:only] == :lines && options[:only] == :subjects
        else
        @subjects = '' unless options[:only] == :lines
        @lines = '' unless options[:only] == :subjects
        end
        @number_of_rows = 0

        Project.project_tree(projects) do |project, level|
          options[:indent] = indent + level * options[:indent_increment]
          render_project(project, options)
          break if abort?
        end

        if options[:format] == :html
          @subjects_rendered = true unless options[:only] == :lines && options[:only] == :calendars
          @lines_rendered = true unless options[:only] == :subjects && options[:only] == :calendars
          @calendars_rendered = true unless options[:only] == :lines && options[:only] == :subjects
        else
        @subjects_rendered = true unless options[:only] == :lines
        @lines_rendered = true unless options[:only] == :subjects
        end

        render_end(options)
      end

      def render_project(project, options={})
        if options[:format] == :html
          subject_for_project(project, options) unless options[:only] == :lines && options[:only] == :calendars
          line_for_project(project, options) unless options[:only] == :subjects && options[:only] == :calendars
          calendar_for_project(project, options) unless options[:only] == :lines && options[:only] == :subjects
        else
        subject_for_project(project, options) unless options[:only] == :lines
        line_for_project(project, options) unless options[:only] == :subjects
        end

        options[:top] += options[:top_increment]
        options[:indent] += options[:indent_increment]
        @number_of_rows += 1
        return if abort?

        issues = project_issues(project).select {|i| i.fixed_version.nil?}
        sort_issues!(issues)
        if issues
          render_issues(issues, options)
          return if abort?
        end

        versions = project_versions(project)
        versions.sort.each do |version|
          render_version(project, version, options)
        end

        # Remove indent to hit the next sibling
        options[:indent] -= options[:indent_increment]
      end

      def render_issues(issues, options={})
        @issue_ancestors = []

        issues.each do |i|
          if options[:format] == :html
            subject_for_issue(i, options) unless options[:only] == :lines && options[:only] == :calendars
            line_for_issue(i, options) unless options[:only] == :subjects && options[:only] == :calendars
            calendar_for_issue(i, options) unless options[:only] == :lines && options[:only] == :subjects
          else
          subject_for_issue(i, options) unless options[:only] == :lines
          line_for_issue(i, options) unless options[:only] == :subjects
          end

          options[:top] += options[:top_increment]
          @number_of_rows += 1
          break if abort?
        end

        options[:indent] -= (options[:indent_increment] * @issue_ancestors.size)
      end

      def render_version(project, version, options={})
        # Version header
        if options[:format] == :html
          subject_for_version(version, options) unless options[:only] == :lines && options[:only] == :calendars
          line_for_version(version, options) unless options[:only] == :subjects && options[:only] == :calendars
          calendar_for_version(version, options) unless options[:only] == :lines && options[:only] == :subjects
        else
        subject_for_version(version, options) unless options[:only] == :lines
        line_for_version(version, options) unless options[:only] == :subjects
        end

        options[:top] += options[:top_increment]
        @number_of_rows += 1
        return if abort?

        issues = version_issues(project, version)
        if issues
          sort_issues!(issues)
          # Indent issues
          options[:indent] += options[:indent_increment]
          render_issues(issues, options)
          options[:indent] -= options[:indent_increment]
        end
      end

      def render_end(options={})
        case options[:format]
        when :pdf
          options[:pdf].Line(15, options[:top], PDF::TotalWidth, options[:top])
        end
      end

      def subject_for_project(project, options)
        case options[:format]
        when :html
          subject = "<span class='icon icon-projects #{project.overdue? ? 'project-overdue' : ''}'>"
          subject << view.link_to_project(project)
          subject << '</span>'
          html_subject(options, subject, :css => "project-name")
        when :image
          image_subject(options, project.name)
        when :pdf
          pdf_new_page?(options)
          pdf_subject(options, project.name)
        end
      end

      def line_for_project(project, options)
        # Skip versions that don't have a start_date or due date
        if project.is_a?(Project) && project.start_date && project.due_date
          options[:zoom] ||= 1
          options[:g_width] ||= (work_days_in(self.date_to, self.date_from) + 1) * options[:zoom]

          coords = coordinates(project.start_date, project.due_date, nil, options[:zoom])
          label = h(project)

          case options[:format]
          when :html
            html_task(options, coords, :css => "project task", :label => label, :markers => true, :id => project.id, :kind => "p")
          when :image
            image_task(options, coords, :label => label, :markers => true, :height => 3)
          when :pdf
            pdf_task(options, coords, :label => label, :markers => true, :height => 0.8)
          end
        else
          ActiveRecord::Base.logger.debug "Gantt#line_for_project was not given a project with a start_date"
          ''
        end
      end

      def subject_for_version(version, options)
        case options[:format]
        when :html
          subject = "<span class='icon icon-package #{version.behind_schedule? ? 'version-behind-schedule' : ''} #{version.overdue? ? 'version-overdue' : ''}'>"
          subject << view.link_to_version(version)
          subject << '</span>'
          html_subject(options, subject, :css => "version-name")
        when :image
          image_subject(options, version.to_s_with_project)
        when :pdf
          pdf_new_page?(options)
          pdf_subject(options, version.to_s_with_project)
        end
      end

      def line_for_version(version, options)
        # Skip versions that don't have a start_date
        if version.is_a?(Version) && version.start_date && version.due_date
          options[:zoom] ||= 1
          options[:g_width] ||= (work_days_in(self.date_to, self.date_from) + 1) * options[:zoom]

          coords = coordinates(version.start_date, version.due_date, version.completed_pourcent, options[:zoom])
          label = "#{h version } #{h version.completed_pourcent.to_i.to_s}%"
          label = h("#{version.project} -") + label unless @project && @project == version.project

          case options[:format]
          when :html
            html_task(options, coords, :css => "version task", :label => label, :markers => true)
            html_task(options, coords, :css => "project task", :label => label, :markers => true, :id => project.id, :kind => "v")
          when :image
            image_task(options, coords, :label => label, :markers => true, :height => 3)
          when :pdf
            pdf_task(options, coords, :label => label, :markers => true, :height => 0.8)
          end
        else
          ActiveRecord::Base.logger.debug "Gantt#line_for_version was not given a version with a start_date"
          ''
        end
      end

      # Prefixes cross-project related issues with their project name
      def subject_for_issue(issue, options)
        while @issue_ancestors.any? && !issue.is_descendant_of?(@issue_ancestors.last)
          @issue_ancestors.pop
          options[:indent] -= options[:indent_increment]
        end

        output = case options[:format]
        when :html
          css_classes = ''
          css_classes << ' issue-overdue' if issue.overdue?
          css_classes << ' issue-behind-schedule' if issue.behind_schedule?
          css_classes << ' icon icon-issue' unless Setting.gravatar_enabled? && issue.assigned_to

          subject = "<span class='#{css_classes}'>"
          if issue.assigned_to.present?
            assigned_string = l(:field_assigned_to) + ": " + issue.assigned_to.name
            subject << view.avatar(issue.assigned_to, :class => 'gravatar icon-gravatar', :size => 10, :title => assigned_string).to_s
          end
          subject << "(" + view.link_to_project(issue.project) + ") " if issue.external?
          subject << view.link_to_issue(issue)
          subject << '</span>'
          html_subject(options, subject, :css => "issue-subject", :title => issue.subject, :external => issue.external?) + "\n"
        when :image
          image_subject(options, issue.subject)
        when :pdf
          pdf_new_page?(options)
          pdf_subject(options, issue.subject)
        end

        unless issue.leaf?
          @issue_ancestors << issue
          options[:indent] += options[:indent_increment]
        end

        output
      end

      def line_for_issue(issue, options)
        return unless issue.is_a?(Issue)
        if issue.due_before
          coords = coordinates(issue.start_date, issue.due_before, issue.done_ratio, options[:zoom])
          label = "#{ issue.status.name }"
          label += " #{ issue.done_ratio }%" if issue.done_ratio > 0 && issue.done_ratio < 100
        else
          coords = coordinates(issue.start_date, issue.start_date, 0, options[:zoom])
          label = "#{ issue.status.name }"
        end

        case options[:format]
        when :html
          html_task(options, coords, :css => "task " + (issue.leaf? ? 'leaf' : 'parent'),
                   :label => label, :issue => issue, :markers => !issue.leaf?, :id => issue.id, :kind => "i")
        when :image
          image_task(options, coords, :label => label)
        when :pdf
          pdf_task(options, coords, :label => label)
        end
      end

      # Generates a gantt image
      # Only defined if RMagick is avalaible
      def to_image(format='PNG')
        date_to = (@date_from >> @months)-1
        show_weeks = @zoom > 1
        show_days = @zoom > 2

        subject_width = 400
        header_height = 18
        # width of one day in pixels
        zoom = @zoom*2
        g_width = (work_days_in(@date_to, @date_from) + 1)*zoom
        g_height = 20 * number_of_rows + 30
        headers_height = (show_weeks ? 2*header_height : header_height)
        height = g_height + headers_height

        imgl = Magick::ImageList.new
        imgl.new_image(subject_width+g_width+1, height)
        gc = Magick::Draw.new

        # Subjects
        gc.stroke('transparent')
        subjects(:image => gc, :top => (headers_height + 20), :indent => 4, :format => :image)

        # Months headers
        month_f = @date_from
        left = subject_width
        @months.times do
          width = ((month_f >> 1) - month_f) * zoom
          gc.fill('white')
          gc.stroke('grey')
          gc.stroke_width(1)
          gc.rectangle(left, 0, left + width, height)
          gc.fill('black')
          gc.stroke('transparent')
          gc.stroke_width(1)
          gc.text(left.round + 8, 14, "#{month_f.year}-#{month_f.month}")
          left = left + width
          month_f = month_f >> 1
        end

        # Weeks headers
        if show_weeks
        	left = subject_width
        	height = header_height
        	if @date_from.cwday == 1
        	    # date_from is monday
                week_f = date_from
        	else
        	    # find next monday after date_from
        		week_f = @date_from + (7 - @date_from.cwday + 1)
        		width = (7 - @date_from.cwday + 1) * zoom
                gc.fill('white')
                gc.stroke('grey')
                gc.stroke_width(1)
                gc.rectangle(left, header_height, left + width, 2*header_height + g_height-1)
        		left = left + width
        	end
        	while week_f <= date_to
        		width = (week_f + 6 <= date_to) ? 7 * zoom : (date_to - week_f + 1) * zoom
                gc.fill('white')
                gc.stroke('grey')
                gc.stroke_width(1)
                gc.rectangle(left.round, header_height, left.round + width, 2*header_height + g_height-1)
                gc.fill('black')
                gc.stroke('transparent')
                gc.stroke_width(1)
                gc.text(left.round + 2, header_height + 14, week_f.cweek.to_s)
        		left = left + width
        		week_f = week_f+7
        	end
        end

        # Days details (week-end in grey)
        if show_days
        	left = subject_width
        	height = g_height + header_height - 1
        	wday = @date_from.cwday
        	(date_to - @date_from + 1).to_i.times do
              width =  zoom
              gc.fill(wday == 6 || wday == 7 ? '#eee' : 'white')
              gc.stroke('#ddd')
              gc.stroke_width(1)
              gc.rectangle(left, 2*header_height, left + width, 2*header_height + g_height-1)
              left = left + width
              wday = wday + 1
              wday = 1 if wday > 7
        	end
        end

        # border
        gc.fill('transparent')
        gc.stroke('grey')
        gc.stroke_width(1)
        gc.rectangle(0, 0, subject_width+g_width, headers_height)
        gc.stroke('black')
        gc.rectangle(0, 0, subject_width+g_width, g_height+ headers_height-1)

        # content
        top = headers_height + 20

        gc.stroke('transparent')
        lines(:image => gc, :top => top, :zoom => zoom, :subject_width => subject_width, :format => :image)

        # today red line
        if Date.today >= @date_from and Date.today <= date_to
          gc.stroke('red')
          x = (Date.today-@date_from+1)*zoom + subject_width
          gc.line(x, headers_height, x, headers_height + g_height-1)
        end

        gc.draw(imgl)
        imgl.format = format
        imgl.to_blob
      end if Object.const_defined?(:Magick)

      def to_pdf
        
        begin
            pdf = ::Redmine::Export::PDF::ITCPDF.new(current_language)
        rescue NameError
            # Compatibility with 1.1.3
            unless ::Redmine::Export::PDF::IFPDF.respond_to?(:alias_nb_pages)
              # Compatibility with 1.1.2
              # TODO: get rid of this dirty hack
              ::Redmine::Export::PDF::IFPDF.class_eval "alias :alias_nb_pages :AliasNbPages; alias :RDMCell :Cell"
            end
            
            pdf = ::Redmine::Export::PDF::IFPDF.new(current_language)
        end

        pdf.SetTitle("#{l(:label_gantt)} #{project}")
        pdf.alias_nb_pages
        pdf.footer_date = format_date(Date.today)
        pdf.AddPage("L")
        pdf.SetFontStyle('B',12)
        pdf.SetX(15)
        pdf.RDMCell(PDF::LeftPaneWidth, 20, project.to_s)
        pdf.Ln
        pdf.SetFontStyle('B',9)

        subject_width = PDF::LeftPaneWidth
        header_height = 5

        headers_height = header_height
        show_weeks = false
        show_days = false

        if self.months < 7
          show_weeks = true
          headers_height = 2*header_height
          if self.months < 3
            show_days = true
            headers_height = 3*header_height
          end
        end

        g_width = PDF.right_pane_width
        zoom = (g_width) / (self.date_to - self.date_from + 1)
        g_height = 120
        t_height = g_height + headers_height

        y_start = pdf.GetY

        # Months headers
        month_f = self.date_from
        left = subject_width
        height = header_height
        self.months.times do
          width = ((month_f >> 1) - month_f) * zoom
          pdf.SetY(y_start)
          pdf.SetX(left)
          pdf.RDMCell(width, height, "#{month_f.year}-#{month_f.month}", "LTR", 0, "C")
          left = left + width
          month_f = month_f >> 1
        end

        # Weeks headers
        if show_weeks
          left = subject_width
          height = header_height
          if self.date_from.cwday == 1
            # self.date_from is monday
            week_f = self.date_from
          else
            # find next monday after self.date_from
            week_f = self.date_from + (7 - self.date_from.cwday + 1)
            width = (7 - self.date_from.cwday + 1) * zoom-1
            pdf.SetY(y_start + header_height)
            pdf.SetX(left)
            pdf.RDMCell(width + 1, height, "", "LTR")
            left = left + width+1
          end
          while week_f <= self.date_to
            width = (week_f + 6 <= self.date_to) ? 7 * zoom : (self.date_to - week_f + 1) * zoom
            pdf.SetY(y_start + header_height)
            pdf.SetX(left)
            pdf.RDMCell(width, height, (width >= 5 ? week_f.cweek.to_s : ""), "LTR", 0, "C")
            left = left + width
            week_f = week_f+7
          end
        end

        # Days headers
        if show_days
          left = subject_width
          height = header_height
          wday = self.date_from.cwday
          pdf.SetFontStyle('B',7)
          (self.date_to - self.date_from + 1).to_i.times do
            width = zoom
            pdf.SetY(y_start + 2 * header_height)
            pdf.SetX(left)
            pdf.RDMCell(width, height, day_name(wday).first, "LTR", 0, "C")
            left = left + width
            wday = wday + 1
            wday = 1 if wday > 7
          end
        end

        pdf.SetY(y_start)
        pdf.SetX(15)
        pdf.RDMCell(subject_width+g_width-15, headers_height, "", 1)

        # Tasks
        top = headers_height + y_start
        options = {
          :top => top,
          :zoom => zoom,
          :subject_width => subject_width,
          :g_width => g_width,
          :indent => 0,
          :indent_increment => 5,
          :top_increment => 5,
          :format => :pdf,
          :pdf => pdf
        }
        render(options)
        pdf.Output
      end

      def edit(pms)
        id = pms[:id]
        kind = id.slice!(0).chr
        begin
          case kind
          when 'i'
            @issue = Issue.find(pms[:id], :include => [:project, :tracker, :status, :author, :priority, :category])
          when 'p'
            @issue = Project.find(pms[:id])
          when 'v'
            @issue = Version.find(pms[:id], :include => [:project])
          end
        rescue ActiveRecord::RecordNotFound
          return "issue not found : #{pms[:id]}", 400
        end

        if !@issue.start_date || !@issue.due_before
          #render :text=>l(:notice_locking_conflict), :status=>400
          return l(:notice_locking_conflict), 400
        end
        @issue.init_journal(User.current)
        date_from = Date.parse(pms[:date_from])
        old_start_date = @issue.start_date
        o = get_issue_position(@issue, pms[:zoom])
        text_for_revert = "#{kind}#{id}=#{format_date(@issue.start_date)},#{@issue.start_date},#{format_date(@issue.due_before)},#{@issue.due_before},#{o[0]},#{o[1]},#{o[2]},#{o[3]}".html_safe

        if pms[:day]
          #bar moved
          duration = work_days_in(@issue.due_before, @issue.start_date)
          @issue.start_date = date_for_workdays(date_from, pms[:day].to_i)
          # convert the duration to workdays and use the resulting date
          @issue.due_date = date_for_workdays(@issue.start_date, duration.to_i) if @issue.due_date
        elsif pms[:start_date]
          #start date changed
          start_date = Date.parse(pms[:start_date])
          if @issue.start_date == start_date
            return "", 200 #nothing has changed
          end
          start_date = ensure_workday(start_date)
          @issue.start_date = start_date
          @issue.due_date = start_date if @issue.due_date && start_date > @issue.due_date
        elsif pms[:due_date]
          #due date changed
          due_date = Date.parse(pms[:due_date])
          if @issue.due_date == due_date
            return "", 200 #nothing has changed
          end
          due_date = ensure_workday(due_date)
          @issue.due_date = due_date
          @issue.start_date = due_date if due_date < @issue.start_date
        end
        fv = @issue.fixed_version
        if fv && fv.effective_date && !@issue.due_date && fv.effective_date < @issue.start_date
          @issue.start_date = old_start_date
        end

        begin
          @issue.save!
          o = get_issue_position(@issue, pms[:zoom])
          text = "#{kind}#{id}=#{format_date(@issue.start_date)},#{@issue.start_date},#{format_date(@issue.due_before)},#{@issue.due_before},#{o[0]},#{o[1]},#{o[2]},#{o[3]}".html_safe

          prj_map = {}
          text = set_project_data(@issue.project, pms[:zoom], text, prj_map)
          version_map = {}
          text = set_version_data(@issue.fixed_version, pms[:zoom], text, version_map)

          #check dependencies
          issues = @issue.all_precedes_issues
          issues.each do |i|
            o = get_issue_position(i, pms[:zoom])
            text += "|i#{i.id}=#{format_date(i.start_date)},#{i.start_date},#{format_date(i.due_before)},#{i.due_before},#{o[0]},#{o[1]},#{o[2]},#{o[3]}".html_safe
            text = set_project_data(i.project, pms[:zoom], text, prj_map)
            text = set_version_data(i.fixed_version, pms[:zoom], text, version_map)
          end

          #check parent
          is = @issue
          while
            pid = is.parent_issue_id
            break if !pid
            i = Issue.find(pid)
            o = get_issue_position(i, pms[:zoom])
            text += "|i#{i.id}=#{format_date(i.start_date)},#{i.start_date},#{format_date(i.due_before)},#{i.due_before},#{o[0]},#{o[1]},#{o[2]},#{o[3]},#{o[4]},#{o[5]}".html_safe
            text = set_project_data(i.project, pms[:zoom], text, prj_map)
            text = set_version_data(i.fixed_version, pms[:zoom], text, version_map)
            is = i
          end
          return text, 200
        rescue => e
          #render :text=>@issue.errors.full_messages.join("\n") + "|" + text_for_revert  , :status=>400
          if @issue.errors.full_messages.to_s == ""
            return e.to_s + "\n" + [$!,$@.join("\n")].join("\n") + "\n" + @issue.errors.full_messages.join("\n") + "|" + text_for_revert, 400
          else
            return @issue.errors.full_messages.join("\n") + "|" + text_for_revert, 400
          end
        end
      end

      # Get the number of work days between two dates. This does not include the 
      # end date, e.g. the result when the start_date equals the end_date is 0.
      # This assumes that the work week is Monday-Friday.
      # TODO: It's probably a bit odd to have date_to as the first parameter here.
      #       I just kept the same order as the original date subtraction code.
      def work_days_in(date_to, date_from)
        if !@work_on_weekends
          date_to = ensure_workday(date_to)
          date_from = ensure_workday(date_from)
        end
        days_in = date_to - date_from
        if @work_on_weekends
          return days_in
        end
        direction = date_to > date_from ? 1 : -1
        weekends_in = (days_in / 7).floor
        weekends_in += direction if date_to.cwday * direction < date_from.cwday * direction
        work_days = days_in - (weekends_in * 2)
        work_days
      end

      private

      def coordinates(start_date, end_date, progress, zoom=nil)
        zoom ||= @zoom

        coords = {}
        if start_date && end_date && start_date < self.date_to && end_date > self.date_from
          if start_date > self.date_from
            coords[:start] = work_days_in(start_date, self.date_from)
            coords[:bar_start] = work_days_in(start_date, self.date_from)
          else
            coords[:bar_start] = 0
          end
          if end_date < self.date_to
            coords[:end] = work_days_in(end_date, self.date_from)
            coords[:bar_end] = work_days_in(end_date, self.date_from) + 1
          else
            coords[:bar_end] = work_days_in(self.date_to, self.date_from) + 1
          end

          if progress
            workdays = work_days_in(end_date, start_date) + 1
            progress_days = workdays * (progress / 100.0)
            progress_date = date_for_workdays(start_date, progress_days)
            if progress_date > self.date_from && progress_date > start_date
              if progress_date < self.date_to
                coords[:bar_progress_end] = work_days_in(progress_date, self.date_from)
              else
                coords[:bar_progress_end] = work_days_in(self.date_to, self.date_from) + 1
              end
            end

            if progress_date < Date.today
              late_date = [Date.today, end_date].min
              if late_date > self.date_from && late_date > start_date
                if late_date < self.date_to
                  coords[:bar_late_end] = work_days_in(late_date, self.date_from) + 1
                else
                  coords[:bar_late_end] = work_days_in(self.date_to, self.date_from) + 1
                end
              end
            end
          end
        end

        # Transforms dates into pixels witdh
        coords.keys.each do |key|
          coords[key] = (coords[key] * zoom).floor
        end
        coords
      end

      # Get the end date for a given start date and duration of workdays.
      # If the number of workdays is 0, the result is equal to the start date.
      # If the number of workdays is 1, the result is equal to the next workday 
      # that follows the start date.
      def date_for_workdays(date_from, workdays)
        if @work_on_weekends
          return date_from + workdays
        end
        direction = workdays > 0 ? 1 : -1
        days_in = date_from + workdays
        workdays_in_week = @work_on_weekends ? 7 : 5
        weekends = (workdays / workdays_in_week).floor
        date_to = date_from + workdays + (weekends * 2) # candidate result (might end on a weekend)
        if (date_to.cwday >= 6) || (date_to.cwday * direction < date_from.cwday * direction)
          weekends += direction
        end
        date_to = date_from + workdays + (weekends * 2) # final result
        date_to
      end
      
      # Ensure that the date falls on a workday. If the given date falls on a
      # weekend, it is moved to the following Monday.
      def ensure_workday(date)
        if !@work_on_weekends
          date += 8 - date.cwday if date.cwday >= 6
        end
        date
      end
      
      # Sorts a collection of issues by start_date, due_date, id for gantt rendering
      def sort_issues!(issues)
        issues.sort! { |a, b| gantt_issue_compare(a, b, issues) }
      end

      def gantt_issue_compare(x, y, issues = nil)
        get_compare_params(x) <=> get_compare_params(y)
      end

      def get_compare_params(issue)
        if RedmineBetterGanttChart.smart_sorting?
          # Smart sorting: issues sorted first by start date of their parent issue, then by id of parent issue, then by start date

          start_date = issue.start_date || Date.new()

          if issue.leaf? && issue.parent.present?
            identifying_id = issue.parent_id || issue.id
            identifying_start = issue.parent.start_date || start_date
            root_start = issue.root.start_date || start_date
          else
            identifying_id = issue.id
            identifying_start = start_date
            root_start = start_date
          end

          [root_start, issue.root_id, identifying_start, start_date, issue.lft]
        else
          # Default Redmine sorting
          [issue.root_id, issue.lft]
        end
      end

      def current_limit
        if @max_rows
          @max_rows - @number_of_rows
        else
          nil
        end
      end

      def abort?
        if @max_rows && @number_of_rows >= @max_rows
          @truncated = true
        end
      end

      def pdf_new_page?(options)
        if options[:top] > 180
          options[:pdf].Line(15, options[:top], PDF::TotalWidth, options[:top])
          options[:pdf].AddPage("L")
          options[:top] = 15
          options[:pdf].Line(15, options[:top] - 0.1, PDF::TotalWidth, options[:top] - 0.1)
        end
      end

      # Renders subjects of cross-project related issues in italic
      def html_subject(params, subject, options={})
        style = "position: absolute;top:#{params[:top]}px;left:#{params[:indent]}px;"
        style << "width:#{params[:subject_width] - params[:indent]}px;" if params[:subject_width]
        style << "font-style:italic;" if options[:external]

        output = view.content_tag 'div', subject.html_safe, :class => options[:css], :style => style, :title => options[:title]
        @subjects << output
        output
      end

      def pdf_subject(params, subject, options={})
        params[:pdf].SetY(params[:top])
        params[:pdf].SetX(15)

        char_limit = PDF::MaxCharactorsForSubject - params[:indent]
        params[:pdf].RDMCell(params[:subject_width]-15, 5, (" " * params[:indent]) +  subject.to_s.sub(/^(.{#{char_limit}}[^\s]*\s).*$/, '\1 (...)'), "LR")

        params[:pdf].SetY(params[:top])
        params[:pdf].SetX(params[:subject_width])
        params[:pdf].RDMCell(params[:g_width], 5, "", "LR")
      end

      def image_subject(params, subject, options={})
        params[:image].fill('black')
        params[:image].stroke('transparent')
        params[:image].stroke_width(1)
        params[:image].text(params[:indent], params[:top] + 2, subject)
      end

      def html_task(params, coords, options={})
        top = (params[:top] + 4).to_s
        text_top = (params[:top] + 1).to_s

        output = ''
        # Renders the task bar, with progress and late
        
        if options[:issue]
          issue = options[:issue]          
          issue_id = "#{issue.id}"          
          relations = {}
          issue.relations_to.each do |relation|
            relation_type = relation.relation_type_for(relation.issue_to) 
            (relations[relation_type] ||= []) << relation.issue_from_id
          end
          issue_relations = relations.inject("") {|str,rel| str << " #{rel[0]}='#{rel[1].join(',')}'" }
        end
        
        # Start rendering draggable area
        #output << "<div id='ev_h#{options[:id]}'>"
        
        if coords[:bar_start] && coords[:bar_end]
          i_width = coords[:bar_end] - coords[:bar_start] - 2
          output << "<div id='ev_#{options[:kind]}#{options[:id]}' style='position:absolute;left:#{coords[:bar_start]}px;top:#{params[:top]}px;padding-top:3px;height:18px;width:#{ i_width + 100}px;z-index:20;' #{options[:kind] == 'i' ? "class='handle'" : ""}>\n"
          
          if options[:issue]
            output << "  <div id='task_todo_#{options[:kind]}#{options[:id]}'#{issue_relations}style='float:left:0px; width:#{ i_width}px;' class='#{options[:css]} task_todo onpage'>&nbsp;</div>\n"
          else
            output << "  <div id='task_todo_#{options[:kind]}#{options[:id]}' style='float:left:0px; width:#{ i_width}px;' class='#{options[:css]} task_todo'>&nbsp;</div>\n"
          end
          
          if coords[:bar_late_end]
            l_width = coords[:bar_late_end] - coords[:bar_start] - 2
            output << "  <div id='task_late_#{options[:kind]}#{options[:id]}' style='float:left:0px; width:#{ l_width}px;' class='#{ l_width == 0 ? options[:css] + " task_none" : options[:css] + " task_late"}'>&nbsp;</div>\n"
          else
            output << "  <div id='task_late_#{options[:kind]}#{options[:id]}' style='float:left:0px; width:0px;' class='#{ options[:css] + " task_none"}'>&nbsp;</div>\n"
          end
          if coords[:bar_progress_end]
            d_width = coords[:bar_progress_end] - coords[:bar_start] - 2
            output << "  <div id='task_done_#{options[:kind]}#{options[:id]}' style='float:left:0px; width:#{ d_width}px;' class='#{ d_width == 0 ? options[:css] + " task_none" : options[:css] + " task_done"}'>&nbsp;</div>\n"
          else
            output << "  <div id='task_done_#{options[:kind]}#{options[:id]}' style='float:left:0px; width:0px;' class='#{ options[:css] + " task_none"}'>&nbsp;</div>\n"
          end
          output << "</div>\n"
        else
          output << "<div id='ev_#{options[:kind]}#{options[:id]}' style='position:absolute;left:0px;top:#{params[:top]}px;padding-top:3px;height:18px;width:0px;' #{options[:kind] == 'i' ? "class='handle'" : ""}>\n"
          output << "  <div id='task_todo_#{options[:kind]}#{options[:id]}' style='float:left:0px; width:0px;' class='#{ options[:css]} task_todo'>&nbsp;</div>\n"
          output << "  <div id='task_late_#{options[:kind]}#{options[:id]}' style='float:left:0px; width:0px;' class='#{ options[:css] + " task_none"}'>&nbsp;</div>\n"
          output << "  <div id='task_done_#{options[:kind]}#{options[:id]}' style='float:left:0px; width:0px;' class='#{ options[:css] + " task_none"}'>&nbsp;</div>\n"
          output << "</div>"
        end

        # Renders the markers
        if options[:markers]
          if coords[:start]
            output << "  <div id='marker_start_#{options[:kind]}#{options[:id]}' style='top:#{ params[:top] + 3 }px;left:#{ coords[:start] }px;width:15px;z-index:35;' class='#{options[:css]} marker starting'>&nbsp;</div>\n"
          end
          if coords[:end]
            output << "  <div id='marker_end_#{options[:kind]}#{options[:id]}' style='top:#{ params[:top] + 3 }px;left:#{ coords[:end] + params[:zoom] }px;width:15px;z-index:35;' class='#{options[:css]} marker ending'>&nbsp;</div>\n"
          end
        end
        # Renders the label on the right
        if options[:label]
          output << "  <div id='label_#{options[:kind]}#{options[:id]}' style='top:#{ params[:top] }px;left:#{ (coords[:bar_end] || 0) + 8 }px;' class='#{options[:css]} label'>"
          output << options[:label]
          output << "  </div>\n"
        end
        # Renders the tooltip
        if options[:issue] && coords[:bar_start] && coords[:bar_end]
          output << "  <div id='tt_#{options[:kind]}#{options[:id]}' class='tooltip' style='position: absolute;top:#{ params[:top] + 3 }px;left:#{ coords[:bar_start] }px;width:#{ coords[:bar_end] - coords[:bar_start] }px;height:6px;'>"
          output << "  <span class='tip'>"
          output << view.render_extended_issue_tooltip(options[:issue])
          output << "  </span></div>\n"
        end

        # Finish rendering draggable area
        if coords[:bar_start] && coords[:bar_end]
          #output << "</div>\n"
          
          output << "<script type='text/javascript'>\n"
          output << "$('#ev_#{options[:kind]}#{options[:id]}').draggable({ \n"
          output << "  axis: 'x', "
          output << "  grid: [#{params[:zoom]}, 0], "
          output << "  stop: function(event, ui) { issue_moved(event.target);},"
          output << "});\n"
          output << "</script>\n"
        end
        
        @lines << output
        output
      end

      ##  for edit gantt
      def set_project_data(prj, zoom, text, prj_map = {})
        if !prj
          return text
        end
        if !prj_map[prj.id]
          o = get_project_position(prj, zoom)
          text += "|p#{prj.id}=#{format_date(prj.start_date)},#{prj.start_date},#{format_date(prj.due_date)},#{prj.due_date},#{o[0]},#{o[1]},#{o[2]},#{o[3]},#{o[4]},#{o[5]}"
          prj_map[prj.id] = prj
        end
        text = set_project_data(prj.parent, zoom, text, prj_map)
      end

      def set_version_data(version, zoom, text, version_map = {})
        if !version
          return text
        end
        if !version_map[version.id]
          o = get_version_position(version, zoom)
          text += "|v#{version.id}=#{format_date(version.start_date)},#{version.start_date},#{format_date(version.due_date)},#{version.due_date},#{o[0]},#{o[1]},#{o[2]},#{o[3]},#{o[4]},#{o[5]}"
          version_map[version.id] = version
        end
        return text
      end

      def get_pos(coords)
        i_left = 0
        i_width = 0
        l_width = 0
        d_width = 0
        if coords[:bar_start]
          i_left = coords[:bar_start]
          if coords[:bar_end]
            i_width = coords[:bar_end] - coords[:bar_start] - 2
            i_width = 0 if i_width < 0
          end
          if coords[:bar_late_end]
            l_width = coords[:bar_late_end] - coords[:bar_start] - 2
          end
          if coords[:bar_progress_end]
            d_width = coords[:bar_progress_end] - coords[:bar_start] - 2
          end
        end
        return i_left, i_width, l_width, d_width
      end

      def get_issue_position(issue, zoom_str)
        z = zoom_str.to_i
        zoom = 1
        z.times { zoom = zoom * 2}
        id = issue.due_before
        if id && @date_to < id
          id = @date_to
        end
        
        coords = coordinates(issue.start_date, id, issue.done_ratio, zoom)

        i_left, i_width, l_width, d_width = get_pos(coords)
        if coords[:end]
          return i_left, i_width, l_width, d_width, coords[:start], coords[:end] + zoom
        else
          return i_left, i_width, l_width, d_width, coords[:start], nil
        end
      end

      def get_project_position(project, zoom_str)
        z = zoom_str.to_i
        zoom = 1
        z.times { zoom = zoom * 2}
        pd = project.due_date
        if pd && @date_to < pd
          pd = @date_to
        end
        coords = coordinates(project.start_date, pd, nil, zoom)
        i_left, i_width, l_width, d_width = get_pos(coords)
        if coords[:end]
          return i_left, i_width, l_width, d_width, coords[:start], coords[:end] + zoom
        else
          return i_left, i_width, l_width, d_width, coords[:start], nil
        end
      end

      def get_version_position(version, zoom_str)
        z = zoom_str.to_i
        zoom = 1
        z.times { zoom = zoom * 2}
        vd = version.due_date
        if vd &&  @date_to < vd
          vd = @date_to
        end
        coords = coordinates(version.start_date, vd, version.completed_pourcent, zoom)
        i_left, i_width, l_width, d_width = get_pos(coords)
        if coords[:end]
          return i_left, i_width, l_width, d_width, coords[:start], coords[:end] + zoom
        else
          return i_left, i_width, l_width, d_width, coords[:start], nil
        end
      end

      def calendar_for_issue(issue, options)
        # Skip issues that don't have a due_before (due_date or version's due_date)
        if issue.is_a?(Issue) && issue.due_before

          case options[:format]
          when :html
            @calendars << "<div style='position: absolute;z-index:50;line-height:1.2em;height:16px;top:#{options[:top]}px;left:4px;overflow:hidden;width:180px;'>"
            start_date = issue.start_date
            if start_date
              @calendars << "<div style='float: left; line-height: 1em; width: 90px;'>"
              @calendars << "<span id='i#{issue.id}_start_date_str'>"
              @calendars << format_date(start_date)
              @calendars << "</span>"
              @calendars << "<input type='hidden' size='12' id='i#{issue.id}_hidden_start_date' value='#{start_date}' />"
              if issue.leaf?
                @calendars << "<input type='hidden' size='12' id='i#{issue.id}_start_date' value='#{start_date}' />#{view.gantt_calendar_for('i' + issue.id.to_s + '_start_date')}"
              else
                @calendars << "<input type='hidden' size='12' id='i#{issue.id}_start_date' value='#{start_date}' />&nbsp;&nbsp;&nbsp;"
              end
              @calendars << observe_date_field("i#{issue.id}", 'start')
              @calendars << "</div>"
            end
            due_date = issue.due_date
            if due_date
              @calendars << "<div style='float: right; line-height: 1em; width: 90px;'>"
              @calendars << "<span id='i#{issue.id}_due_date_str'>"
              @calendars << format_date(due_date)
              @calendars << "</span>"
              @calendars << "<input type='hidden' size='12' id='i#{issue.id}_hidden_due_date' value='#{due_date}' />"
              if issue.leaf?
                @calendars << "<input type='hidden' size='12' id='i#{issue.id}_due_date' value='#{due_date}' />#{view.gantt_calendar_for('i' + issue.id.to_s + '_due_date')}"
              else
                @calendars << "<input type='hidden' size='12' id='i#{issue.id}_due_date' value='#{due_date}' />"
              end
              @calendars << observe_date_field("i#{issue.id}", 'due')
              @calendars << "</div>"
            else
              @calendars << "<div style='float: right; line-height: 1em; width: 90px;'>"
              @calendars << "<span id='i#{issue.id}_due_date_str'>"
              @calendars << "Not set"
              @calendars << "</span>"
              @calendars << "<input type='hidden' size='12' id='i#{issue.id}_hidden_due_date' value='#{start_date}' />"
              if issue.leaf?
                @calendars << "<input type='hidden' size='12' id='i#{issue.id}_due_date' value='#{start_date}' />#{view.gantt_calendar_for('i' + issue.id.to_s + '_due_date')}"
              else
                @calendars << "<input type='hidden' size='12' id='i#{issue.id}_due_date' value='#{start_date}' />"
              end
              @calendars << observe_date_field("i#{issue.id}", 'due')
              @calendars << "</div>"            
            end
            
            @calendars << "</div>"
          when :image
            #nop
          when :pdf
            #nop
          end
        else
          ActiveRecord::Base.logger.debug "GanttHelper#line_for_issue was not given an issue with a due_before"
          ''
        end
      end

      def calendar_for_version(version, options)
        # Skip version that don't have a due_before (due_date or version's due_date)
        if version.is_a?(Version) && version.start_date && version.due_date

          case options[:format]
          when :html
            @calendars << "<div style='position: absolute;z-index:50;line-height:1.2em;height:16px;top:#{options[:top]}px;left:4px;overflow:hidden;'>"
            @calendars << "<span id='v#{version.id}_start_date_str'>"
            @calendars << format_date(version.effective_date)
            @calendars << "</span>"
            @calendars << "</div>"
          when :image
            #nop
          when :pdf
            #nop
          end
        else
          ActiveRecord::Base.logger.debug "GanttHelper#line_for_issue was not given an issue with a due_before"
          ''
        end
      end

      def calendar_for_project(project, options)
        case options[:format]
        when :html
          @calendars << "<div style='position: absolute;z-index:50;line-height:1.2em;height:16px;top:#{options[:top]}px;left:4px;overflow:hidden;width:180px;'>"
          @calendars << "<div style='float:left;width:90px;'>"
          @calendars << "<span id='p#{project.id}_start_date_str'>"
          @calendars << format_date(project.start_date) if project.start_date
          @calendars << "</span>"
          @calendars << "</div>"
          @calendars << "<div style='float:right;width:90px;'>"
          @calendars << "<span id='p#{project.id}_due_date_str'>"
          @calendars << format_date(project.due_date) if project.due_date
          @calendars << "</span>"
          @calendars << "</div>"
          @calendars << "</div>"
        when :image
          # nop
        when :pdf
          # nop
        end
      end

      def observe_date_field(id, type)
        output = ''
        prj_id = ''
        prj_id = @project.to_param if @project
        output << "<script type='text/javascript'>\n"
        output << "//<![CDATA[\n"
        output << "$(function() {\n"
        output << "  $('##{id}_#{type}_date').observe_field(1, function( ) {\n"
        output << "    if (this.value == document.getElementById('#{id}_hidden_#{type}_date').value) {\n"
        output << "      return ;\n"
        output << "    }\n"
        output << "    var jqxhr = $.post('#{view.url_for(:controller=>:gantts, :action => :edit_gantt, :id=>id, :date_from=>self.date_from.strftime("%Y-%m-%d"), :date_to=>self.date_to.strftime("%Y-%m-%d"), :zoom=>self.zoom, :escape => false, :project_id=>prj_id)}', '#{type}_date=' + encodeURIComponent(this.value), null, 'text')"
        output << "    .success(function(request) { change_dates(request); })"
        output << "    .error(function(request) { handle_failure(request.responseText); });"
        output << "  });\n"
        output << "});\n"
        output << "//]]>\n"
        output << "</script>"
      end

      def pdf_task(params, coords, options={})
        height = options[:height] || 2

        # Renders the task bar, with progress and late
        if coords[:bar_start] && coords[:bar_end]
          params[:pdf].SetY(params[:top]+1.5)
          params[:pdf].SetX(params[:subject_width] + coords[:bar_start])
          params[:pdf].SetFillColor(200,200,200)
          params[:pdf].RDMCell(coords[:bar_end] - coords[:bar_start], height, "", 0, 0, "", 1)

          if coords[:bar_late_end]
            params[:pdf].SetY(params[:top]+1.5)
            params[:pdf].SetX(params[:subject_width] + coords[:bar_start])
            params[:pdf].SetFillColor(255,100,100)
            params[:pdf].RDMCell(coords[:bar_late_end] - coords[:bar_start], height, "", 0, 0, "", 1)
          end
          if coords[:bar_progress_end]
            params[:pdf].SetY(params[:top]+1.5)
            params[:pdf].SetX(params[:subject_width] + coords[:bar_start])
            params[:pdf].SetFillColor(90,200,90)
            params[:pdf].RDMCell(coords[:bar_progress_end] - coords[:bar_start], height, "", 0, 0, "", 1)
          end
        end
        # Renders the markers
        if options[:markers]
          if coords[:start]
            params[:pdf].SetY(params[:top] + 1)
            params[:pdf].SetX(params[:subject_width] + coords[:start] - 1)
            params[:pdf].SetFillColor(50,50,200)
            params[:pdf].RDMCell(2, 2, "", 0, 0, "", 1)
          end
          if coords[:end]
            params[:pdf].SetY(params[:top] + 1)
            params[:pdf].SetX(params[:subject_width] + coords[:end] - 1)
            params[:pdf].SetFillColor(50,50,200)
            params[:pdf].RDMCell(2, 2, "", 0, 0, "", 1)
          end
        end
        # Renders the label on the right
        if options[:label]
          params[:pdf].SetX(params[:subject_width] + (coords[:bar_end] || 0) + 5)
          params[:pdf].RDMCell(30, 2, options[:label])
        end
      end

      def image_task(params, coords, options={})
        height = options[:height] || 6

        # Renders the task bar, with progress and late
        if coords[:bar_start] && coords[:bar_end]
          params[:image].fill('#aaa')
          params[:image].rectangle(params[:subject_width] + coords[:bar_start], params[:top], params[:subject_width] + coords[:bar_end], params[:top] - height)

          if coords[:bar_late_end]
            params[:image].fill('#f66')
            params[:image].rectangle(params[:subject_width] + coords[:bar_start], params[:top], params[:subject_width] + coords[:bar_late_end], params[:top] - height)
          end
          if coords[:bar_progress_end]
            params[:image].fill('#00c600')
            params[:image].rectangle(params[:subject_width] + coords[:bar_start], params[:top], params[:subject_width] + coords[:bar_progress_end], params[:top] - height)
          end
        end
        # Renders the markers
        if options[:markers]
          if coords[:start]
            x = params[:subject_width] + coords[:start]
            y = params[:top] - height / 2
            params[:image].fill('blue')
            params[:image].polygon(x-4, y, x, y-4, x+4, y, x, y+4)
          end
          if coords[:end]
            x = params[:subject_width] + coords[:end] + params[:zoom]
            y = params[:top] - height / 2
            params[:image].fill('blue')
            params[:image].polygon(x-4, y, x, y-4, x+4, y, x, y+4)
          end
        end
        # Renders the label on the right
        if options[:label]
          params[:image].fill('black')
          params[:image].text(params[:subject_width] + (coords[:bar_end] || 0) + 5,params[:top] + 1, options[:label])
        end
      end
    end
  end
end
