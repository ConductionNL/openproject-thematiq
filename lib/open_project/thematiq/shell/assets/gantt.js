/* The Gantt page as the OpGantt board draws it. See Shell::Gantt.
 *
 * Core's Gantt is Angular and redraws itself often, so every step here is idempotent: one pass, at most once per
 * frame, checks what is missing and adds it. Nothing of core is removed; what the board replaces (core's three
 * zoom buttons, core's dependency lines) is hidden by the stylesheet and still works underneath. */
(function () {
  "use strict";

  var kit = window.thematiqGantt;
  if (!kit || !document.body) { return; }
  var T = kit.texts || {};
  var LEVELS = ["days", "weeks", "months", "quarters", "years"];
  var PX_PER_DAY = { days: 30, weeks: 15 };
  var SVG = "http://www.w3.org/2000/svg";

  document.body.classList.add("thematiq-gantt");

  function el(tag, attrs, text) {
    var node = document.createElement(tag);
    Object.keys(attrs || {}).forEach(function (key) { node.setAttribute(key, attrs[key]); });
    if (text) { node.textContent = text; }
    return node;
  }

  function icon(path) {
    var svg = document.createElementNS(SVG, "svg");
    svg.setAttribute("viewBox", "0 0 24 24");
    svg.setAttribute("aria-hidden", "true");
    svg.setAttribute("class", "thematiq-gantt__icon");
    var p = document.createElementNS(SVG, "path");
    p.setAttribute("d", path);
    svg.appendChild(p);
    return svg;
  }

  var ICONS = {
    download: "M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3",
    table: "M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01",
    board: "M4 5h16v14H4zM9 5v14M15 5v14",
    gantt: "M3 5h8M7 12h10M11 19h10M3 3v18"
  };

  /* ---- the zoom level core applies, also when the view says "auto" ---- */
  function headerInner() { return document.querySelector(".wp-table-timeline--header-inner"); }

  function appliedLevel() {
    var inner = headerInner();
    if (!inner) { return null; }
    var stated = inner.getAttribute("data-current-zoom-level");
    if (LEVELS.indexOf(stated) >= 0) { return stated; }
    if (inner.querySelector(".wp-timeline--header-day-element")) { return "days"; }
    if (document.querySelector(".wp-timeline--non-working-day")) { return "weeks"; }
    var middle = inner.querySelector(".wp-timeline--header-middle-element");
    if (!middle) { return null; }
    var width = parseFloat(middle.style.width) || middle.getBoundingClientRect().width;
    if (width < 20) { return "years"; }
    if (width <= 45) { return "months"; }
    return "quarters";
  }

  /* ---- dates under a pixel, read from core's today line: core puts it at (days since the start + hour / 24) * px per day ---- */
  function dayAt(level) {
    var line = document.getElementById("wp-timeline-static-element-today-line");
    var perDay = PX_PER_DAY[level];
    if (!line || !perDay) { return null; }
    var todayIndex = Math.floor(parseFloat(line.style.left) / perDay);
    var now = new Date();
    return function (x) {
      var offset = Math.round(x / perDay) - todayIndex;
      return new Date(now.getFullYear(), now.getMonth(), now.getDate() + offset);
    };
  }

  var locale = (document.documentElement.lang || "en").indexOf("en") === 0 ? "en-GB" : document.documentElement.lang;
  var weekFormat = new Intl.DateTimeFormat(locale, { day: "numeric", month: "short" });
  var dayFormat = new Intl.DateTimeFormat(locale, { weekday: "narrow" });

  /* The board's header: the first day of each week over one letter per day. Core's own text stays for months and up. */
  function relabelHeader() {
    var inner = headerInner();
    var level = appliedLevel();
    document.body.setAttribute("data-tq-gantt-zoom", level || "");
    if (!inner || (level !== "days" && level !== "weeks")) { return; }
    var at = dayAt(level);
    if (!at) { return; }
    var weekTop = level === "days" ? "13px" : "15px";
    var dayTop = level === "days" ? "23px" : "25px";
    Array.prototype.forEach.call(inner.children, function (cell) {
      if (cell.hasAttribute("data-tq-row")) { return; }
      var left = parseFloat(cell.style.left) || 0;
      if (cell.classList.contains("wp-timeline--header-top-bold-element") || cell.classList.contains("wp-timeline--header-day-element")) {
        cell.setAttribute("data-tq-row", "hidden");
      } else if (cell.style.top === weekTop) {
        cell.setAttribute("data-tq-row", "week");
        cell.textContent = weekFormat.format(at(left));
      } else if (cell.style.top === dayTop) {
        var date = at(left);
        cell.setAttribute("data-tq-row", "day");
        cell.setAttribute("title", date.toLocaleDateString(locale));
        cell.textContent = level === "days" ? dayFormat.format(date) + " " + date.getDate() : dayFormat.format(date);
      }
    });
  }

  function todayLine() {
    var line = document.getElementById("wp-timeline-static-element-today-line");
    if (line && line.getAttribute("data-label") !== T.today) { line.setAttribute("data-label", T.today); }
    return line;
  }

  /* ---- zoom: core's own buttons do the work, the list only says where to go ---- */
  function stepZoom(target, select) {
    var tries = 0;
    (function step() {
      var current = appliedLevel();
      if (!current || current === target || tries++ > 8) {
        if (select && current) { select.value = current; }
        return;
      }
      var inward = LEVELS.indexOf(target) < LEVELS.indexOf(current);
      var button = document.getElementById(inward ? "work-packages-timeline-zoom-in-button" : "work-packages-timeline-zoom-out-button");
      if (!button || button.disabled) { return; }
      button.click();
      setTimeout(step, 250);
    })();
  }

  function scrollToToday() {
    var line = todayLine();
    var side = document.querySelector(".work-packages-tabletimeline--timeline-side");
    if (!line || !side) { return; }
    side.scrollLeft = Math.max(0, parseFloat(line.style.left) - side.clientWidth / 4);
  }

  /* Export PDF opens core's export dialog, the entry "Export" of core's "More actions" menu. */
  function openExport() {
    var more = document.getElementById("work-packages-settings-button");
    if (!more) { return; }
    more.click();
    setTimeout(function () {
      var target = document.querySelector(".op-context-menu--overlay .icon-export");
      var item = target && target.closest("a, button");
      if (item) { item.click(); }
    }, 50);
  }

  function menuHref(name) {
    var link = document.querySelector('#main-menu li[data-name="' + name + '"] a.main-menu--parent-node, #main-menu li[data-name="' + name + '"] .main-item-wrapper > a');
    return link ? link.getAttribute("href") : null;
  }

  function currentChip() {
    var params = new URLSearchParams(window.location.search);
    if (params.get("query_id")) { return null; }
    return params.get("name") || "all_open";
  }

  function buildBar() {
    var bar = el("div", { "class": "thematiq-gantt__bar", "data-test-selector": "thematiq-gantt-bar" });

    var chips = el("nav", { "class": "thematiq-gantt__chips", "aria-label": T.chips_label });
    (kit.chips || []).forEach(function (chip) {
      var link = el("a", { "class": "thematiq-gantt__chip", href: chip.href, "data-chip": chip.key }, T[chip.key]);
      if (chip.count !== null && chip.count !== undefined) {
        link.appendChild(el("span", { "class": "thematiq-gantt__count" }, String(chip.count)));
      }
      chips.appendChild(link);
    });
    bar.appendChild(chips);
    bar.appendChild(el("span", { "class": "thematiq-gantt__spacer" }));

    var today = el("button", { type: "button", "class": "thematiq-gantt__button", "data-test-selector": "thematiq-gantt-today" }, T.today);
    today.addEventListener("click", scrollToToday);
    bar.appendChild(today);

    var label = el("label", { "class": "thematiq-gantt__zoom" }, T.zoom);
    var select = el("select", { "class": "thematiq-gantt__select", "data-test-selector": "thematiq-gantt-zoom" });
    LEVELS.forEach(function (level) { select.appendChild(el("option", { value: level }, T["zoom_levels_" + level])); });
    select.addEventListener("change", function () { stepZoom(select.value, select); });
    label.appendChild(select);
    bar.appendChild(label);

    var views = el("div", { role: "group", "class": "thematiq-gantt__views", "aria-label": T.view });
    [["work_packages", "view_table", ICONS.table], ["boards", "view_board", ICONS.board]].forEach(function (entry) {
      var href = menuHref(entry[0]);
      if (!href) { return; }
      var link = el("a", { href: href, "class": "thematiq-gantt__view", "aria-label": T[entry[1]], title: T[entry[1]] });
      link.appendChild(icon(entry[2]));
      views.appendChild(link);
    });
    var gantt = el("a", { href: window.location.pathname, "class": "thematiq-gantt__view", "aria-current": "page", "aria-label": T.view_gantt, title: T.view_gantt });
    gantt.appendChild(icon(ICONS.gantt));
    views.appendChild(gantt);
    bar.appendChild(views);
    return bar;
  }

  function ensureBar() {
    var toolbar = document.querySelector(".work-packages-partitioned-query-space--container > .toolbar-container");
    if (!toolbar) { return; }
    // Inside core's toolbar container, after the title row: the page around it is a grid of fixed rows.
    var bar = document.querySelector(".thematiq-gantt__bar");
    if (!bar || bar.parentElement !== toolbar) {
      if (bar) { bar.remove(); }
      bar = buildBar();
      toolbar.appendChild(bar);
    }
    var chip = currentChip();
    Array.prototype.forEach.call(bar.querySelectorAll(".thematiq-gantt__chip"), function (link) {
      if (link.getAttribute("data-chip") === chip) { link.setAttribute("aria-current", "page"); } else { link.removeAttribute("aria-current"); }
    });
    var select = bar.querySelector("select");
    var level = appliedLevel();
    if (level && select && document.activeElement !== select && select.value !== level) { select.value = level; }

    var items = toolbar.querySelector(".toolbar-items");
    if (items && !items.querySelector(".thematiq-gantt__export")) {
      var li = el("li", { "class": "toolbar-item thematiq-gantt__export" });
      var button = el("button", { type: "button", "class": "button thematiq-gantt__button", "data-test-selector": "thematiq-gantt-export" });
      button.appendChild(icon(ICONS.download));
      button.appendChild(el("span", {}, T.export_pdf));
      button.addEventListener("click", openExport);
      li.appendChild(button);
      items.insertBefore(li, items.firstChild);
    }
  }

  function swatch(kind) {
    var span = el("span", { "class": "thematiq-gantt__swatch thematiq-gantt__swatch--" + kind, "aria-hidden": "true" });
    if (kind === "follows") {
      var svg = document.createElementNS(SVG, "svg");
      svg.setAttribute("viewBox", "0 0 28 12");
      var p = document.createElementNS(SVG, "path");
      p.setAttribute("d", "M1 6h22M19 2l4 4-4 4");
      svg.appendChild(p);
      span.appendChild(svg);
    }
    return span;
  }

  function colourMilestoneSwatch() {
    var swatchEl = document.querySelector(".thematiq-gantt__swatch--milestone");
    if (!swatchEl || swatchEl.className.indexOf("__hl_background_type_") >= 0) { return; }
    var diamond = document.querySelector(".timeline-element.milestone .diamond");
    var match = diamond && /__hl_background_type_\d+/.exec(diamond.className);
    if (match) { swatchEl.classList.add(match[0]); }
  }

  function ensureLegend() {
    var chart = document.querySelector("wp-list-view wp-table.work-packages-split-view--tabletimeline-content");
    if (!chart || (chart.nextElementSibling && chart.nextElementSibling.classList.contains("thematiq-gantt__legend"))) { return; }
    var old = document.querySelector(".thematiq-gantt__legend");
    if (old) { old.remove(); }
    var legend = el("ul", { "class": "thematiq-gantt__legend", "aria-label": T.legend_label, "data-test-selector": "thematiq-gantt-legend" });
    [["bar", T.legend_bar], ["parent", T.legend_parent], ["milestone", T.legend_milestone], ["follows", T.legend_follows]].forEach(function (entry) {
      var li = el("li", {});
      li.appendChild(swatch(entry[0]));
      li.appendChild(document.createTextNode(entry[1]));
      legend.appendChild(li);
    });
    chart.insertAdjacentElement("afterend", legend);
  }

  /* ---- dependency lines, drawn from the bars where they are on screen ---- */
  function barOf(id) {
    var cell = document.querySelector(".wp-row-" + id + "-timeline");
    if (!cell || cell.offsetParent === null) { return null; }
    var shape = cell.querySelector(".timeline-element.milestone .diamond") || cell.querySelector(".timeline-element.bar");
    if (!shape || shape.closest(".timeline-element").style.visibility === "hidden") { return null; }
    return { cell: cell.getBoundingClientRect(), shape: shape.getBoundingClientRect() };
  }

  var lastSignature = "";

  function drawRelations() {
    var container = document.querySelector(".wp-table-timeline--container");
    if (!container) { return; }
    var pairs = {};
    Array.prototype.forEach.call(container.querySelectorAll(".relation-line"), function (segment) {
      var ids = [];
      segment.classList.forEach(function (name) {
        var match = /^__tl-relation-(\d+)$/.exec(name);
        if (match) { ids.push(match[1]); }
      });
      // Core names the follower first and the one it follows second (TimelineRelationElement#classNames).
      if (ids.length === 2) { pairs[ids[1] + ">" + ids[0]] = ids; }
    });
    var origin = container.getBoundingClientRect();
    var paths = [];
    Object.keys(pairs).forEach(function (key) {
      var before = barOf(pairs[key][1]);
      var after = barOf(pairs[key][0]);
      if (!before || !after) { return; }
      var sx = before.shape.right - origin.left;
      var sy = before.cell.top + before.cell.height / 2 - origin.top;
      var tx = after.shape.left - origin.left;
      var ty = after.cell.top + after.cell.height / 2 - origin.top;
      var d;
      if (tx - sx >= 24) {
        var mx = sx + Math.min(17, (tx - sx) / 2);
        d = "M" + sx + " " + sy + "H" + mx + "V" + ty + "H" + (tx - 3);
      } else {
        var edge = ty > sy ? ty - after.cell.height / 2 : ty + after.cell.height / 2;
        d = "M" + sx + " " + sy + "H" + (sx + 8) + "V" + edge + "H" + (tx - 12) + "V" + ty + "H" + (tx - 3);
      }
      d += "M" + (tx - 8) + " " + (ty - 5) + "L" + (tx - 3) + " " + ty + "L" + (tx - 8) + " " + (ty + 5);
      paths.push(d);
    });
    var signature = paths.join("|");
    var svg = container.querySelector(".thematiq-gantt__relations");
    if (signature === lastSignature && svg) { return; }
    lastSignature = signature;
    if (!svg) {
      svg = document.createElementNS(SVG, "svg");
      svg.setAttribute("class", "thematiq-gantt__relations");
      svg.setAttribute("aria-hidden", "true");
      container.appendChild(svg);
    }
    svg.setAttribute("width", container.scrollWidth);
    svg.setAttribute("height", container.scrollHeight);
    while (svg.firstChild) { svg.removeChild(svg.firstChild); }
    paths.forEach(function (d) {
      var p = document.createElementNS(SVG, "path");
      p.setAttribute("d", d);
      svg.appendChild(p);
    });
  }

  function ensureTimelineLabel() {
    var side = document.querySelector(".work-packages-tabletimeline--timeline-side");
    if (side && !side.hasAttribute("aria-label")) { side.setAttribute("aria-label", T.timeline_label); }
  }

  var queued = false;
  function pass() {
    queued = false;
    if (!document.body.classList.contains("thematiq-gantt")) { return; }
    try {
      ensureBar();
      ensureLegend();
      colourMilestoneSwatch();
      ensureTimelineLabel();
      todayLine();
      relabelHeader();
      drawRelations();
    } catch (error) {
      if (window.console) { window.console.warn("[thematiq] Gantt:", error); }
    }
  }
  function queue() {
    if (queued) { return; }
    queued = true;
    window.requestAnimationFrame(pass);
  }

  var observer = new MutationObserver(queue);
  observer.observe(document.body, { childList: true, subtree: true });
  window.addEventListener("resize", queue);
  // A Turbo visit swaps the body: this script runs again on the next Gantt page, and stops here.
  document.addEventListener("turbo:before-render", function stop() {
    observer.disconnect();
    window.removeEventListener("resize", queue);
    document.removeEventListener("turbo:before-render", stop);
  });
  queue();
})();
