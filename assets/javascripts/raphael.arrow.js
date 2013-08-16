(function() {
  /*
  This plugin draws arrows on Redmine gantt chart.
  */  var __slice = Array.prototype.slice;
  Raphael.fn.ganttArrow = function(coords, relationType) {
    var L1, M, arrow, arrowhead, cmd, deltaX, deltaY, l2, line, m, relationDash, triangle, x1, x2, x3, x4, x5, x6, y1, y2, y3, y4, y5, y6, _ref, _ref2, _ref3, _ref4, _ref5, _ref6;
    if (relationType == null) {
      relationType = "follows";
    }
    relationDash = {
      "follows": "",
      "duplicated": "- ",
      "blocked": "-",
      "relates": "."
    };
    cmd = function() {
      var a, cmd;
      cmd = arguments[0], a = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
      return cmd.concat(" ", a.join(" "), " ");
    };
    M = function(x, y) {
      return cmd("M", x, y);
    };
    m = function(x, y) {
      return cmd("m", x, y);
    };
    L1 = function(x1, y1) {
      return cmd("L", x1, y1);
    };
    l2 = function(x1, y1, x2, y2) {
      return cmd("l", x1, y1, x2, y2);
    };
    line = function(x1, y1, x2, y2) {
      return M(x1, y1) + L1(x2, y2);
    };
    triangle = function(cx, cy, r) {
      r *= 1.5;
      return "".concat(M(cx, cy), m(0, -1 * r * .58), l2(r * .5, r * .87, -r, 0), " z");
    };
    x1 = coords[0], y1 = coords[1], x6 = coords[2], y6 = coords[3];
    x1 += 3;
    arrow = this.set();
    deltaX = 7;
    deltaY = 8;
    _ref = [x1 + deltaX - 3, y1], x2 = _ref[0], y2 = _ref[1];
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
    paper.canvas.style.position = "absolute";
    paper.canvas.style.zIndex = "24";
    relationAttrs = ["follows", "blocked", "duplicated", "relates"];
    calculateAnchors = function(from, to) {
      var anchors, fromOffsetX, fromOffsetY, toOffsetX, toOffsetY, typeOffsetX, _ref, _ref2;
      _ref = [from.position().left, from.position().top], fromOffsetX = _ref[0], fromOffsetY = _ref[1];
      _ref2 = [to.position().left, to.position().top], toOffsetX = _ref2[0], toOffsetY = _ref2[1];
      if (to.hasClass('parent')) {
        typeOffsetX = 10;
      } else {
        typeOffsetX = 6;
      }
      anchors = [fromOffsetX + from.width() - 1, fromOffsetY + from.height() / 2, toOffsetX - typeOffsetX, toOffsetY + to.height() / 2];
      return anchors;
    };
    return $('div.task_todo').each(function(element) {
      var from, id, item, related, relationAttribute, to, _i, _len, _results;
      element = this;
      _results = [];
      for (_i = 0, _len = relationAttrs.length; _i < _len; _i++) {
        relationAttribute = relationAttrs[_i];
        _results.push((function() {
          var _i, _len, _ref, _results;
          if ((related = element.getAttribute(relationAttribute))) {
            _ref = related.split(',');
            _results = [];
            for (_i = 0, _len = _ref.length; _i < _len; _i++) {
              id = _ref[_i];
              _results.push((item = $('#' + id)) ? (from = item, to = $('#' + element.id), (from.position() != null) && (to.position() != null) ? paper.ganttArrow(calculateAnchors(from, to), relationAttribute) : void 0) : void 0);
            }
            return _results;
          }
        })());
      }
      return _results;
    });
  };
}).call(this);
