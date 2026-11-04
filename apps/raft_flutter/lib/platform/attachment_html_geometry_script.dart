import 'dart:convert';

/// Host-only evaluation derived from the pinned preview reporter's bounded
/// describe/locate routines. No postMessage, channel, URL or app object exists.
String attachmentHtmlGeometryScript(Map<String, dynamic> command) =>
    '(() => {\nconst command = ${jsonEncode(command)};\n$_geometry\n})()';

const _geometry = r'''
    var MAX_QUOTE = 200;
    var normalizeText = function (value) {
      return (typeof value === "string" ? value : "").replace(/\s+/g, " ").trim();
    };
    var isBoundary = function (ch) {
      return ch === "\n" || ch === "\r" || ch === "." || ch === "!" || ch === "?"
        || ch === "。" || ch === "！" || ch === "？" || ch === ";" || ch === "；";
    };
    var snippetFromTextNode = function (node, offset) {
      var raw = typeof (node && node.textContent) === "string" ? node.textContent : "";
      if (!normalizeText(raw)) return "";
      var i = typeof offset === "number" && isFinite(offset)
        ? Math.max(0, Math.min(raw.length, Math.floor(offset)))
        : 0;
      while (i < raw.length && /\s/.test(raw.charAt(i))) i++;
      if (i >= raw.length) {
        i = Math.max(0, Math.min(raw.length - 1, (typeof offset === "number" ? Math.floor(offset) : raw.length) - 1));
        while (i > 0 && /\s/.test(raw.charAt(i))) i--;
      }
      var start = i;
      while (start > 0 && !isBoundary(raw.charAt(start - 1)) && i - start < 40) start--;
      while (start < raw.length && /\s/.test(raw.charAt(start))) start++;
      var end = Math.max(i, start + 1);
      while (end < raw.length && !isBoundary(raw.charAt(end)) && end - start < MAX_QUOTE) end++;
      return normalizeText(raw.slice(start, end)).slice(0, MAX_QUOTE);
    };
    var snippetFromCaretPoint = function (clientX, clientY) {
      try {
        var pos = document.caretPositionFromPoint ? document.caretPositionFromPoint(clientX, clientY) : null;
        if (pos && pos.offsetNode && pos.offsetNode.nodeType === 3) {
          var byPosition = snippetFromTextNode(pos.offsetNode, pos.offset);
          if (byPosition) return byPosition;
        }
      } catch (e) {}
      try {
        var range = document.caretRangeFromPoint ? document.caretRangeFromPoint(clientX, clientY) : null;
        if (range && range.startContainer && range.startContainer.nodeType === 3) {
          var byRange = snippetFromTextNode(range.startContainer, range.startOffset);
          if (byRange) return byRange;
        }
      } catch (e) {}
      return "";
    };
    var rectIntersects = function (a, b) {
      return a && b && a.right > b.left && a.left < b.right && a.bottom > b.top && a.top < b.bottom;
    };
    var joinSnippets = function (parts) {
      var out = "";
      for (var i = 0; i < parts.length; i++) {
        var part = normalizeText(parts[i]);
        if (!part) continue;
        if (out && (out.indexOf(part) !== -1 || part.indexOf(out) !== -1)) continue;
        var next = out ? out + " ... " + part : part;
        if (next.length <= MAX_QUOTE) {
          out = next;
          continue;
        }
        if (!out) return next.slice(0, MAX_QUOTE);
        var remaining = MAX_QUOTE - out.length - 5;
        if (remaining > 20) out += " ... " + part.slice(0, remaining);
        return out.slice(0, MAX_QUOTE);
      }
      return out;
    };
    var textFromCaretScan = function (left, top, width, height) {
      var right = left + Math.max(1, width);
      var bottom = top + Math.max(1, height);
      var stepX = Math.max(8, Math.min(24, Math.max(1, width) / 4));
      var stepY = Math.max(8, Math.min(24, Math.max(1, height) / 4));
      var checked = 0;
      for (var y = top + 1; y <= bottom && checked < 400; y += stepY) {
        for (var x = left + 1; x <= right && checked < 400; x += stepX) {
          checked++;
          var text = snippetFromCaretPoint(x, y);
          if (text) return text;
        }
      }
      return snippetFromCaretPoint(left + 1, top + 1) || snippetFromCaretPoint(left + width / 2, top + height / 2);
    };
    var textFromIntersectingRects = function (left, top, width, height) {
      var query = {
        left: left,
        top: top,
        right: left + Math.max(1, width),
        bottom: top + Math.max(1, height)
      };
      var candidates = [];
      try {
        var root = document.body || document.documentElement;
        var walker = document.createTreeWalker(root, 4, null);
        var node, seen = 0;
        while ((node = walker.nextNode()) && seen < 5000) {
          seen++;
          if (!normalizeText(node.textContent || "")) continue;
          var range = document.createRange();
          range.selectNodeContents(node);
          var rects = range.getClientRects ? range.getClientRects() : [];
          var nodeScore = Infinity;
          for (var i = 0; i < rects.length; i++) {
            var r = rects[i];
            if (!rectIntersects(r, query)) continue;
            var score = Math.max(0, r.top - query.top) * 100000 + Math.max(0, r.left - query.left);
            if (score < nodeScore) nodeScore = score;
          }
          if (nodeScore < Infinity) {
            var text = snippetFromTextNode(node, 0);
            if (text) candidates.push({ score: nodeScore, text: text });
          }
          if (range.detach) range.detach();
        }
      } catch (e) {}
      candidates.sort(function (a, b) { return a.score - b.score; });
      var parts = [];
      for (var j = 0; j < candidates.length; j++) parts.push(candidates[j].text);
      return joinSnippets(parts);
    };
    var fallbackTextFromPoint = function (left, top, width, height) {
      var points = [
        [left + 1, top + 1],
        [left + width / 2, top + height / 2]
      ];
      for (var i = 0; i < points.length; i++) {
        try {
          var hit = document.elementFromPoint(points[i][0], points[i][1]);
          var cur = hit;
          while (cur && cur !== document.documentElement) {
            var text = normalizeText(cur.innerText || cur.textContent || "");
            if (text) return text.slice(0, MAX_QUOTE);
            cur = cur.parentElement;
          }
        } catch (e) {}
      }
      return "";
    };
    var describeRegion = function (x, y, w, h) {
      var left = x - window.scrollX;
      var top = y - window.scrollY;
      var width = Math.max(0, w);
      var height = Math.max(0, h);
      var isRegion = width >= 4 && height >= 4;
      return (isRegion ? textFromIntersectingRects(left, top, width, height) : "")
        || textFromCaretScan(left, top, width, height)
        || (!isRegion ? textFromIntersectingRects(left, top, width, height) : "")
        || fallbackTextFromPoint(left, top, width, height);
    };

    var normalize = function(v) { return typeof v === 'string' ? v.replace(/\s+/g, ' ').trim() : ''; };
    var geometry = function() {
      var root = document.documentElement, body = document.body, visual = window.visualViewport;
      return { viewportWidth: window.innerWidth, viewportHeight: window.innerHeight,
        visibleWidth: visual ? visual.width : window.innerWidth,
        visibleHeight: visual ? visual.height : window.innerHeight,
        scrollX: window.scrollX + (visual ? visual.offsetLeft : 0),
        scrollY: window.scrollY + (visual ? visual.offsetTop : 0),
        documentWidth: Math.max(root.scrollWidth, root.clientWidth, body ? body.scrollWidth : 0),
        documentHeight: Math.max(root.scrollHeight, root.clientHeight, body ? body.scrollHeight : 0) };
    };
    var locate = function(quote, nearY) {
      var wanted = normalize(quote); if (!wanted) return null;
      var walker = document.createTreeWalker(document.body || document.documentElement, NodeFilter.SHOW_ELEMENT, null);
      var el, candidates = [], seen = 0;
      while ((el = walker.nextNode()) && seen++ < 5000) {
        if (normalize(el.textContent || '').indexOf(wanted) >= 0) candidates.push(el);
      }
      var best = null, distance = Infinity;
      for (var i = 0; i < candidates.length; i++) {
        var candidate = candidates[i], minimal = true;
        for (var j = 0; j < candidates.length; j++) {
          if (i !== j && candidate.contains(candidates[j])) { minimal = false; break; }
        }
        if (!minimal) continue;
        var rect = candidate.getBoundingClientRect();
        if (!rect || (rect.width <= 0 && rect.height <= 0)) continue;
        var score = Math.abs(rect.top + window.scrollY + rect.height / 2 - nearY);
        if (score < distance) { distance = score; best = rect; }
      }
      return best ? {x: Math.round(best.left + window.scrollX), y: Math.round(best.top + window.scrollY), w: Math.round(best.width), h: Math.round(best.height)} : null;
    };
    try {
      var g = geometry(), region = null;
      if (command.operation === 'capture') {
        var r = command.rect, host = command.host;
        var x = Math.round(g.scrollX + r[0] * g.visibleWidth / host[0]);
        var y = Math.round(g.scrollY + r[1] * g.visibleHeight / host[1]);
        var w = Math.round(r[2] * g.visibleWidth / host[0]);
        var h = Math.round(r[3] * g.visibleHeight / host[1]);
        var quote = ''; try { quote = describeRegion(x, y, w, h); } catch (_) {}
        region = {x:Math.max(0,x),y:Math.max(0,y),w:w,h:h,viewportWidth:g.viewportWidth,documentWidth:g.documentWidth,documentHeight:g.documentHeight};
        if (quote) region.quote = quote;
      } else if (command.operation === 'jump') {
        var stored = command.region, found = null;
        try { found = locate(stored.quote, stored.y + stored.h / 2); } catch (_) {}
        region = found || {x:stored.x,y:stored.y,w:stored.w,h:stored.h};
        window.scrollTo(Math.max(0, region.x - g.visibleWidth / 2), Math.max(0, region.y - g.visibleHeight / 3));
        g = geometry();
        region.viewportWidth = g.viewportWidth; region.documentWidth = g.documentWidth; region.documentHeight = g.documentHeight;
        if (stored.quote) region.quote = stored.quote;
      } else if (command.operation === 'scroll') {
        var d = command.delta;
        window.scrollBy(d[0] * g.visibleWidth / command.host[0], d[1] * g.visibleHeight / command.host[1]);
        g = geometry();
      }
      var packet = JSON.stringify({version:1, request:command.request, geometry:g, region:region});
      return typeof packet === 'string' && packet.length <= 16384 ? packet : '';
    } catch (_) { return ''; }
''';
