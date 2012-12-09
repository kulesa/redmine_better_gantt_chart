###
This plugin draws arrows on Redmine gantt chart.
###

# Draws an arrow 
# Original here: http://taitems.tumblr.com/post/549973287/drawing-arrows-in-raphaeljs
Raphael.fn.ganttArrow = (coords, relationType = "follows") ->
  # Strokes for relation types
  relationDash =
    "follows": ""
    "duplicated": "- "
    "blocked": "-"
    "relates": "."
  
  # Shorthand functions for formatting SVG commands
  cmd = (cmd, a...) ->  cmd.concat(" ", a.join(" "), " ")
  M = (x, y) -> cmd("M", x, y)
  m = (x, y) -> cmd("m", x, y)
  L1 = (x1, y1) -> cmd("L", x1, y1)
  l2 = (x1, y1, x2, y2) -> cmd("l", x1, y1, x2, y2)

  line = (x1, y1, x2, y2) ->
    M(x1, y1) + L1(x2, y2)

  triangle = (cx, cy, r) ->
    r *= 1.5
    "".concat(M(cx,cy), m(0,-1*r*.58), l2(r*.5, r*.87, -r, 0), " z")

  [x1, y1, x6, y6] = coords
  x1 += 3

  arrow = @set()
  
  deltaX = 7
  deltaY = 8
  
  [x2, y2] = [x1 + deltaX - 3, y1]
  [x5, y5] = [x6 - deltaX, y6]
  
  if y1 < y6
    [x3, y3] = [x2, y6 - deltaY]
  else
    [x3, y3] = [x2, y6 + deltaY]

  if x1 + deltaX + 7 < x6
    [x4, y4] = [x3, y5]
  else
    [x4, y4] = [x5, y3]

  arrow.push @path(line(x1, y1, x2, y2))
  arrow.push @path(line(x2, y2, x3, y3))
  arrow.push @path(line(x3, y3, x4, y4))
  arrow.push @path(line(x4, y4, x5, y5))
  arrow.push @path(line(x5, y6, x6, y6))
  arrowhead = arrow.push(@path(triangle(x6 + deltaX - 5, y6 + 1, 5)).rotate(90))
  arrow.toFront()
  arrow.attr({fill: "#444", stroke: "#222", "stroke-dasharray": relationDash[relationType]})
###
Draws connection arrows over the gantt chart
###
window.redrawGanttArrows = () ->
  if window.paper?
    # remove old paper if it exists
    paperDom = paper.canvas
    paperDom.parentNode.removeChild(paperDom)
  @paper = Raphael("gantt-container", "100%", "100%")
  window.paper = paper
  paper.clear
  # Keep arrows above the "today" marker
  paper.canvas.style.position = "absolute"
  paper.canvas.style.zIndex = "10"

  # Relation attributes
  relationAttrs = ["follows", "blocked", "duplicated", "relates"]
  
  # Calculates arrow coordinates
  calculateAnchors = (from, to) ->
    paperX = $(paper.canvas).offset().left
    paperY = $(paper.canvas).offset().top
    [fromOffsetX, fromOffsetY] = [from.offset().left-paperX, from.offset().top-paperY]
    [toOffsetX, toOffsetY]     = [to.offset().left-paperX, to.offset().top-paperY]
    if to.hasClass('parent')
      typeOffsetX = 10
    else
      typeOffsetX = 6
    anchors = [fromOffsetX + from.width() - 1, fromOffsetY + from.height()/2, toOffsetX - typeOffsetX, toOffsetY + to.height()/2]
    anchors

  # Draw arrows for all tasks, which have dependencies
  $('div.task_todo').each (element) ->
    element = this
    for relationAttribute in relationAttrs
      if (related = element.getAttribute(relationAttribute))
        for id in related.split(',')
          if (item = $('#task_todo_i'+id))
            from = item
            to = $('#'+element.id)
            if from.offset()? and to.offset()?
              paper.ganttArrow calculateAnchors(from, to), relationAttribute
