/**
 * 타임라인 이벤트 요약 라벨: 막대 밖 확장·행 단위 겹침 방지
 */
(function (global) {
  'use strict';

  var TIME_LEAD_RE = /^(?:(?:새벽|오전|오후|밤|낮|저녁|아침)\s*)?\d{1,2}\s*시(?:\s*\d{1,2}\s*분)?(?:\s*(?:경|쯤|반|무렵|쯤경|전후))?/i;
  var TIME_LEAD_RE2 = /^(?:새벽|오전|오후|밤|낮|저녁|아침)\s*\d{1,2}시(?:\d{1,2}분|경|쯤|반|무렵)?(?:\s*~?\s*(?:새벽|오전|오후|밤)?\s*\d{1,2}시(?:\d{1,2}분|경|쯤)?)?[\s,.·\-—]*/i;

  function nvl(s) {
    return s == null ? '' : String(s);
  }

  /** 차트용 짧은 요약 (상세는 클릭 시 시트) */
  function eventDisplaySummary(ev, maxLen) {
    maxLen = maxLen || 22;
    var label = nvl(ev.label).trim();
    var timeText = nvl(ev.timeText).trim();
    var quote = nvl(ev.quote).trim();

    if (!label || label === '이벤트') {
      label = timeText || quote;
    }
    if (timeText && label.indexOf(timeText) === 0) {
      label = label.slice(timeText.length).replace(/^[\s,.·\-—]+/, '').trim();
    }
    label = label.replace(TIME_LEAD_RE2, '').replace(TIME_LEAD_RE, '').trim();
    label = label.replace(/^\d{1,2}:\d{2}(?::\d{2})?\s*[\-—~]\s*\d{1,2}:\d{2}\s*/, '');
    label = label.replace(/^\d{1,2}\/\d{1,2}(?:\s+\d{1,2}:\d{2})?\s*/, '').trim();

    if (!label && timeText) label = timeText;
    if (!label && quote) label = quote;
    if (!label) return '';

    var clause = label.split(/[,.;。!?]|\s+그리고\s+|\s+또한\s+|\s+또\s+/)[0].trim();
    if (clause.length >= 2) label = clause;

    label = label.replace(/\s+/g, ' ').trim();
    if (label.length <= maxLen) return label;

    var sub = label.slice(0, maxLen);
    var sp = sub.lastIndexOf(' ');
    if (sp > maxLen * 0.45) return sub.slice(0, sp) + '…';
    return sub.slice(0, Math.max(1, maxLen - 1)) + '…';
  }

  function eventBarWidth(d, xScale) {
    var end = d.end ? new Date(d.end) : new Date(d.start);
    var x0 = xScale(new Date(d.start));
    var x1 = xScale(end);
    var pad = d.end ? 0 : (d.timeUncertain ? 5 : 6);
    return Math.max(d.timeUncertain ? 8 : 6, x1 - x0 + pad);
  }

  /**
   * @param {Array} plotEvents
   * @param {Function} xScale d3 time scale
   * @param {Object} layout timelineLaneLayout
   * @param {number} chartWidth inner plot width
   * @param {Object} opts { charWidth, maxExtend, summaryMax, minBarChars, labelY(ev), blockHeight(ev) }
   */
  function computeLayouts(plotEvents, xScale, layout, chartWidth, opts) {
    opts = opts || {};
    var charW = opts.charWidth != null ? opts.charWidth : 6.2;
    var maxExtend = opts.maxExtend != null ? opts.maxExtend : 120;
    var summaryMax = opts.summaryMax != null ? opts.summaryMax : 22;
    var minInsideChars = opts.minInsideChars != null ? opts.minInsideChars : 5;
    var padL = opts.padLeft != null ? opts.padLeft : 4;
    var labelYFn = opts.labelY;
    var blockHFn = opts.blockHeight;

    var items = [];
    (plotEvents || []).forEach(function (d) {
      if (!labelYFn || !blockHFn) return;
      var bh = blockHFn(d);
      if (bh < 10) return;
      var summary = eventDisplaySummary(d, summaryMax);
      if (!summary) return;
      var x0 = xScale(new Date(d.start));
      var bw = eventBarWidth(d, xScale);
      var row = d._stackRow || 0;
      items.push({
        id: d.id,
        ev: d,
        x0: x0,
        bw: bw,
        rowKey: (d.laneId || '') + ':' + row,
        labelY: labelYFn(d),
        summary: summary,
        prefix: d.timeUncertain ? '~ ' : ''
      });
    });

    var groups = {};
    items.forEach(function (it) {
      if (!groups[it.rowKey]) groups[it.rowKey] = [];
      groups[it.rowKey].push(it);
    });

    var labelLineStep = opts.labelLineStep != null ? opts.labelLineStep : 15;
    var labelGap = opts.labelGap != null ? opts.labelGap : 4;

    Object.keys(groups).forEach(function (key) {
      var row = groups[key].sort(function (a, b) { return a.x0 - b.x0; });
      row.forEach(function (it, i) {
        var text = it.prefix + it.summary;
        var startX = it.x0 + padL;
        var insideRoom = Math.max(0, it.bw - padL * 2);
        var insideChars = Math.floor(insideRoom / charW);
        var useOutside = insideChars < minInsideChars;
        var availRight = i < row.length - 1 ? row[i + 1].x0 - labelGap : chartWidth;
        var extendCap = it.x0 + it.bw + maxExtend;
        var maxRight = Math.min(availRight, extendCap, chartWidth);
        var maxPx = Math.max(charW * 4, maxRight - startX);
        var maxChars = Math.max(4, Math.floor(maxPx / charW));
        it.displayText = text.length > maxChars ? text.slice(0, Math.max(1, maxChars - 1)) + '…' : text;
        it.useOutside = useOutside;
        it.labelX = startX;
        it.labelClass = useOutside ? 'evt-label evt-label-outside' : 'evt-label evt-label-inside';
        it.maxPx = maxPx;
        it.charWidth = charW;
        it.textWidth = it.displayText.length * charW;
        it.labelEndX = startX + it.textWidth + 6;
      });

      assignLabelRows(row, labelLineStep);
    });

    return items;
  }

  /** 겹치는 요약 라벨을 서로 다른 줄(세로 오프셋)에 배치 */
  function assignLabelRows(row, lineStep) {
    var occupied = [];
    row.forEach(function (it) {
      var left = it.labelX;
      var right = it.labelEndX;
      var lr = 0;
      while (true) {
        var conflict = false;
        for (var j = 0; j < occupied.length; j++) {
          var o = occupied[j];
          if (o.lr !== lr) continue;
          if (left < o.right && o.left < right) {
            conflict = true;
            break;
          }
        }
        if (!conflict) break;
        lr++;
      }
      it.labelRow = lr;
      occupied.push({ lr: lr, left: left, right: right });
    });
    var maxRow = 0;
    row.forEach(function (it) {
      if (it.labelRow > maxRow) maxRow = it.labelRow;
    });
    var center = (maxRow) / 2;
    row.forEach(function (it) {
      it.labelYOffset = (it.labelRow - center) * lineStep;
      it.labelYDraw = it.labelY + it.labelYOffset;
    });
  }

  function drawLabelGroups(chartG, layouts) {
    var labelG = chartG.selectAll('.layer-evt-label-g').data(layouts, function (d) { return d.id; }).join('g')
      .attr('class', 'layer-evt-label-g')
      .attr('pointer-events', 'none');

    labelG.each(function (d) {
      var g = d3.select(this);
      g.selectAll('*').remove();
      var yDraw = d.labelYDraw != null ? d.labelYDraw : d.labelY;
      if (d.useOutside) {
        var w = Math.min(d.textWidth + 8, d.maxPx + 8);
        g.append('rect')
          .attr('class', 'evt-label-bg')
          .attr('x', d.labelX - 4)
          .attr('y', yDraw - 10)
          .attr('width', w)
          .attr('height', 18)
          .attr('rx', 4);
      }
      g.append('text')
        .attr('class', d.labelClass)
        .attr('x', d.labelX)
        .attr('y', yDraw)
        .attr('text-anchor', 'start')
        .attr('dominant-baseline', 'middle')
        .text(d.displayText);
    });
  }

  /** 이벤트 구간이 차트 너비의 일정 비율을 쓰도록 초기 줌 */
  function applyInitialZoom(svg, zoomBehavior, plotEvents, baseXScale, innerW) {
    if (!svg || !zoomBehavior || !plotEvents || !plotEvents.length || !baseXScale) return;
    var times = [];
    plotEvents.forEach(function (e) {
      var t = new Date(e.start).getTime();
      if (!isNaN(t)) times.push(t);
      if (e.end) {
        var te = new Date(e.end).getTime();
        if (!isNaN(te)) times.push(te);
      }
    });
    if (!times.length) return;
    var minT = Math.min.apply(null, times);
    var maxT = Math.max.apply(null, times);
    var x0 = baseXScale(new Date(minT));
    var x1 = baseXScale(new Date(maxT));
    var spanPx = Math.max(40, x1 - x0);
    var targetPx = innerW * 0.72;
    var k = Math.min(4, Math.max(1.15, targetPx / spanPx));
    var mid = (x0 + x1) / 2;
    var tx = innerW / 2 - mid * k;
    var t = d3.zoomIdentity.translate(tx, 0).scale(k);
    svg.call(zoomBehavior.transform, t);
  }

  global.TimelineLabels = {
    eventDisplaySummary: eventDisplaySummary,
    eventBarWidth: eventBarWidth,
    computeLayouts: computeLayouts,
    drawLabelGroups: drawLabelGroups,
    applyInitialZoom: applyInitialZoom
  };
})(typeof window !== 'undefined' ? window : this);
