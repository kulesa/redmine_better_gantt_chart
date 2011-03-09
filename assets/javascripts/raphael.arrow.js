(function() {
  /*
  This plugin draws arrows on Redmine gantt chart.
  */  Raphael.fn.ganttArrow = function(coords, relationType) {
    var arrow, arrowhead, deltaX, deltaY, line, relationDash, triangle, x1, x2, x3, x4, x5, x6, y1, y2, y3, y4, y5, y6, _ref, _ref2, _ref3, _ref4, _ref5, _ref6;
    if (relationType == null) {
      relationType = "follows";
    }
    relationDash = {
      "follows": "",
      "duplicated": "- ",
      "blocked": "-",
      "relates": "."
    };
    line = function(x1, y1, x2, y2) {
      return ["M", x1, y1, "L", x2, y2];
    };
    triangle = function(cx, cy, r) {
      r *= 1.75;
      return "M".concat(cx, ",", cy, "m0-", r * .58, "l", r * .5, ",", r * .87, "-", r, ",0z");
    };
    x1 = coords[0], y1 = coords[1], x6 = coords[2], y6 = coords[3];
    arrow = this.set();
    deltaX = 6;
    deltaY = 8;
    _ref = [x1 + deltaX, y1], x2 = _ref[0], y2 = _ref[1];
    _ref2 = [x6 - deltaX, y6], x5 = _ref2[0], y5 = _ref2[1];
    if (y1 < y6) {
      _ref3 = [x2, y6 - deltaY], x3 = _ref3[0], y3 = _ref3[1];
    } else {
      _ref4 = [x2, y6 + deltaY], x3 = _ref4[0], y3 = _ref4[1];
    }
    if (x1 + deltaX + 7 < x6) {
      _ref5 = [x3, y5], x4 = _ref5[0], y4 = _ref5[1];
    } else {
      _ref6 = [x5, y3], x4 = _ref6[0], y4 = _ref6[1];
    }
    arrow.push(this.path(line(x1, y1, x2, y2)));
    arrow.push(this.path(line(x2, y2, x3, y3)));
    arrow.push(this.path(line(x3, y3, x4, y4)));
    arrow.push(this.path(line(x4, y4, x5, y5)));
    arrow.push(this.path(line(x5, y6, x6, y6)));
    arrowhead = arrow.push(this.path(triangle(x6 + deltaX - 5, y6 + 1, 5)).rotate(90));
    arrow.toFront();
    return arrow.attr({
      fill: "#444",
      stroke: "#222",
      "stroke-dasharray": relationDash[relationType]
    });
  };
  /*
  Draws connection arrows over the gantt chart
  */
  window.redrawGanttArrows = function() {
    var calculateAnchors, paper, relationAttrs;
    paper = Raphael("gantt_lines", "100%", "100%");
    paper.clear;
    window.paper = paper;
    relationAttrs = ["follows", "blocked", "duplicated", "relates"];
    calculateAnchors = function(from, to) {
      var fromOffsetX, fromOffsetY, toOffsetX, toOffsetY, typeOffsetX, _ref, _ref2;
      _ref = from.positionedOffset(), fromOffsetX = _ref[0], fromOffsetY = _ref[1];
      _ref2 = to.positionedOffset(), toOffsetX = _ref2[0], toOffsetY = _ref2[1];
      if (to.hasClassName('parent')) {
        typeOffsetX = 10;
      } else {
        typeOffsetX = 6;
      }
      return [fromOffsetX + from.getWidth() - 1, fromOffsetY + from.getHeight() / 2, toOffsetX - typeOffsetX, toOffsetY + to.getHeight() / 2];
    };
    return $$('div.task_todo').each(function(element) {
      var id, item, related, relationAttribute, _i, _len, _results;
      _results = [];
      for (_i = 0, _len = relationAttrs.length; _i < _len; _i++) {
        relationAttribute = relationAttrs[_i];
        _results.push((function() {
          var _i, _len, _ref, _results;
          if ((related = element.readAttribute(relationAttribute))) {
            _ref = related.split(',');
            _results = [];
            for (_i = 0, _len = _ref.length; _i < _len; _i++) {
              id = _ref[_i];
              _results.push((item = $(id)) ? paper.ganttArrow(calculateAnchors(item, element), relationAttribute) : void 0);
            }
            return _results;
          }
        })());
      }
      return _results;
    });
  };
}).call(this);
