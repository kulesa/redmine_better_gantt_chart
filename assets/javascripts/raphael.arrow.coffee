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
 
  line = (x1, y1, x2, y2) ->
    ["M", x1, y1, "L", x2, y2]

  triangle = (cx, cy, r) ->
    r *= 1.75
    "M".concat(cx, ",", cy, "m0-", r * .58, "l", r * .5, ",", r * .87, "-", r, ",0z")

  [x1, y1, x6, y6] = coords

  arrow = @set()
  
  deltaX = 6
  deltaY = 8
  
  [x2, y2] = [x1 + deltaX, y1]
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
  paper = Raphael("gantt_lines", "100%", "100%") # check out 'gantt_lines' div, margin-right: -2048px FTW!
  paper.clear
  window.paper = paper

  # Relation attributes
  relationAttrs = ["follows", "blocked", "duplicated", "relates"]
  
  # Calculates arrow coordinates
  calculateAnchors = (from, to) ->
    [fromOffsetX, fromOffsetY] = from.positionedOffset()
    [toOffsetX, toOffsetY]     = to.positionedOffset()
    if to.hasClassName('parent')
      typeOffsetX = 10
    else
      typeOffsetX = 6
    [fromOffsetX + from.getWidth() - 1, fromOffsetY + from.getHeight()/2, toOffsetX - typeOffsetX, toOffsetY + to.getHeight()/2]

  # Draw arrows for all tasks, which have dependencies
  $$('div.task_todo').each (element) ->
    for relationAttribute in relationAttrs
      if (related = element.readAttribute(relationAttribute))
        for id in related.split(',')
          if (item = $(id))
            paper.ganttArrow calculateAnchors(item, element), relationAttribute
