(function() {
  /*
  This plugin draws arrows on Redmine gantt chart.
  */  Raphael.fn.ganttArrow = function(x1, y1, x6, y6) {
    var arrow, arrowhead, deltaX, deltaY, line, triangle, x2, x3, x4, x5, y2, y3, y4, y5, _ref, _ref2, _ref3, _ref4, _ref5, _ref6;
    line = function(x1, y1, x2, y2) {
      return ["M", x1, y1, "L", x2, y2];
    };
    triangle = function(cx, cy, r) {
      r *= 1.75;
      return "M".concat(cx, ",", cy, "m0-", r * .58, "l", r * .5, ",", r * .87, "-", r, ",0z");
    };
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
      _ref5 = [x3, y3], x4 = _ref5[0], y4 = _ref5[1];
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
      fill: "#222",
      stroke: "#222"
    });
  };
  /*
  Draws connection arrows over the gantt chart
  */
  window.redrawGanttArrows = function() {
    var calculateAnchors, paper;
    paper = Raphael("gantt_lines", "100%", "100%");
    window.paper = paper;
    calculateAnchors = function(from, to) {
      var fromOffsetX, fromOffsetY, toOffsetX, toOffsetY, typeOffsetX, _ref, _ref2;
      _ref = Element.positionedOffset(from), fromOffsetX = _ref[0], fromOffsetY = _ref[1];
      _ref2 = Element.positionedOffset(to), toOffsetX = _ref2[0], toOffsetY = _ref2[1];
      if (to.hasClassName('parent')) {
        typeOffsetX = 9;
      } else {
        typeOffsetX = 5;
      }
      return [fromOffsetX + from.getWidth(), fromOffsetY + from.getHeight() / 2, toOffsetX - typeOffsetX, toOffsetY + to.getHeight() / 2];
    };
    console.log("total: " + ($$('div.task_todo').size()));
    return $$('div.task_todo').each(function(element) {
      var follows, id, item, x1, x2, y1, y2, _i, _len, _ref, _ref2, _results;
      if ((follows = Element.readAttribute(element, 'follows'))) {
        _ref = follows.split(',');
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          id = _ref[_i];
          _results.push((item = $(id)) ? ((_ref2 = calculateAnchors(item, element), x1 = _ref2[0], y1 = _ref2[1], x2 = _ref2[2], y2 = _ref2[3], _ref2), paper.ganttArrow(x1, y1, x2, y2)) : void 0);
        }
        return _results;
      }
    });
  };
  /*
  Fired on full load of the page
  */
  document.observe("dom:loaded", function() {
    return window.redrawGanttArrows();
  });
}).call(this);
