// The live side of the style editor. It reads the form and writes custom properties on the picture
// of the shell, so a change shows while you type. Nothing is sent and nothing is saved here.
// The server checks every value again on save: this script only decides what the picture shows.
(function () {
  "use strict";

  var PREFIX = "--tqp-";
  var HEX = /^#(?:[0-9a-f]{3}|[0-9a-f]{4}|[0-9a-f]{6}|[0-9a-f]{8})$/;
  var COLOR_FUNCTION = /^(?:rgba?|hsla?|hwb|lab|lch|oklab|oklch)\(([0-9a-z.,%\/\s-]{1,60})\)$/;
  var COLOR_ARGUMENT = /^(?:-?(?:\d{1,4}(?:\.\d{1,4})?|\.\d{1,4})(?:%|deg|turn|rad|grad)?|none)$/;
  var LENGTH = /^(?:0|(?:\d{1,3}(?:\.\d{1,3})?|\.\d{1,3})(?:px|rem|em|%))$/;
  var QUOTED_FAMILY = /^(["'])[A-Za-z0-9 _.-]{1,60}\1$/;
  var BARE_FAMILY = /^-?[A-Za-z_][A-Za-z0-9_-]*(?: [A-Za-z_][A-Za-z0-9_-]*)*$/;

  // The same allow-lists as the plugin's validator. A value that fails is not drawn.
  function clean(kind, raw, named) {
    var text = String(raw).trim();
    if (text.length > 400) { return null; }
    if (kind === "color") {
      text = text.toLowerCase();
      if (HEX.test(text) || named.indexOf(text) !== -1) { return text; }
      var match = COLOR_FUNCTION.exec(text);
      if (!match) { return null; }
      var parts = match[1].trim().split(/\s*[,\/]\s*|\s+/);
      if (parts.length < 3 || parts.length > 4) { return null; }
      return parts.every(function (part) { return COLOR_ARGUMENT.test(part); }) ? text : null;
    }
    if (kind === "length") {
      text = text.toLowerCase();
      return LENGTH.test(text) ? text : null;
    }
    if (kind === "font_family") {
      var families = text.split(",").map(function (family) { return family.trim(); });
      if (families.length > 20) { return null; }
      var fine = families.every(function (family) {
        return QUOTED_FAMILY.test(family) || (family.length <= 60 && BARE_FAMILY.test(family));
      });
      return fine ? families.join(", ") : null;
    }
    return null;
  }

  // [red, green, blue, alpha] for a hex colour or rgb(). null for any other syntax: unknown, not fine.
  function rgba(color) {
    if (typeof color !== "string") { return null; }
    var text = color.trim().toLowerCase();
    var match = /^#([0-9a-f])([0-9a-f])([0-9a-f])$/.exec(text);
    if (match) { return [1, 2, 3].map(function (i) { return parseInt(match[i] + match[i], 16); }).concat([1]); }
    match = /^#([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/.exec(text);
    if (match) { return [1, 2, 3].map(function (i) { return parseInt(match[i], 16); }).concat([1]); }
    match = /^rgba?\(\s*(\d{1,3})\s*[, ]\s*(\d{1,3})\s*[, ]\s*(\d{1,3})\s*(?:[,\/]\s*(\d?\.?\d+)\s*)?\)$/.exec(text);
    if (!match) { return null; }
    var values = [1, 2, 3].map(function (i) { return parseFloat(match[i]); });
    var alpha = match[4] === undefined ? 1 : parseFloat(match[4]);
    var inRange = values.every(function (value) { return value <= 255; }) && alpha >= 0 && alpha <= 1;
    return inRange ? values.concat([alpha]) : null;
  }

  function luminance(channels) {
    var linear = channels.map(function (channel) {
      var value = channel / 255;
      return value <= 0.03928 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4);
    });
    return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2];
  }

  // WCAG 2 contrast, rounded to two places like the server does. null when it cannot be measured.
  function ratio(foreground, background) {
    var back = rgba(background);
    var fore = rgba(foreground);
    if (!back || !fore || back[3] !== 1) { return null; }
    var mixed = [0, 1, 2].map(function (i) { return fore[i] * fore[3] + back[i] * (1 - fore[3]); });
    var a = luminance(mixed);
    var b = luminance(back.slice(0, 3));
    return Math.round(((Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05)) * 100) / 100;
  }

  // The first candidate when it reads, else the one that reads best.
  function bestOn(background, candidates, minimum) {
    var usable = candidates.filter(Boolean);
    if (usable.length && (ratio(usable[0], background) || 0) >= minimum) { return usable[0]; }
    var best = usable[0];
    usable.forEach(function (candidate) {
      if ((ratio(candidate, background) || 0) > (ratio(best, background) || 0)) { best = candidate; }
    });
    return best;
  }

  function sixDigitHex(color) {
    var channels = rgba(color);
    if (!channels || channels[3] !== 1) { return null; }
    return "#" + channels.slice(0, 3).map(function (value) {
      return ("0" + Math.round(value).toString(16)).slice(-2);
    }).join("");
  }

  function plural(texts, count) {
    var text = count === 0 ? texts.zero : (count === 1 ? texts.one : texts.other);
    return String(text).replace("%{count}", String(count));
  }

  function init() {
    var form = document.getElementById("thematiq-editor-form");
    var frame = document.querySelector("[data-thematiq-preview]");
    var data = window.thematiqEditorData;
    var texts = window.thematiqEditorTexts;
    if (!form || !frame || !data || !texts || form.getAttribute("data-thematiq-live") === "1") { return; }
    form.setAttribute("data-thematiq-live", "1");

    var rows = Array.prototype.slice.call(form.querySelectorAll("[data-thematiq-row]")).map(function (element) {
      var input = element.querySelector("input[data-thematiq-token]");
      return {
        element: element,
        input: input,
        key: input.getAttribute("data-thematiq-token"),
        kind: data.kinds[input.getAttribute("data-thematiq-token")],
        base: input.getAttribute("data-thematiq-base") || "",
        swatch: element.querySelector(".thematiq-editor__swatch"),
        badge: element.querySelector("[data-thematiq-badge]"),
        reset: element.querySelector("[data-thematiq-reset]"),
        error: element.querySelector("[data-thematiq-error]"),
        group: element.closest("[data-thematiq-group]"),
        text: element.textContent.toLowerCase() + " " + input.getAttribute("data-thematiq-token"),
        picker: null,
        changed: false,
        invalid: false,
        value: ""
      };
    });

    // What the picture shows for one row: the typed value when it is valid, else the base value.
    function read(row) {
      var typed = row.input.value.trim();
      var cleaned = typed === "" ? null : clean(row.kind, typed, data.named);
      row.invalid = typed !== "" && cleaned === null;
      row.changed = cleaned !== null && cleaned !== row.base;
      row.value = cleaned === null ? row.base : cleaned;
    }

    function values() {
      var map = {};
      rows.forEach(function (row) { map[row.key] = row.value; });
      var white = "#ffffff";
      var dark = "#1b1c1d";
      map["@on-primary"] = bestOn(map.primary, [white, map.ink, dark], data.minimum);
      map["@on-action"] = bestOn(map.action, [white, map.ink, dark], data.minimum);
      map["@on-menu"] = map.menu ? bestOn(map.menu, [map.ink, white, dark], data.minimum) : map.ink;
      map["@on-selected"] = map.menu ? bestOn(map["primary-light"], [map["primary-deep"], white, dark], data.minimum) : map["primary-deep"];
      return map;
    }

    function drawRow(row) {
      row.element.classList.toggle("is-changed", row.changed);
      row.element.classList.toggle("is-invalid", row.invalid);
      if (row.badge) { row.badge.hidden = !row.changed; }
      if (row.reset) { row.reset.hidden = row.input.value.trim() === ""; }
      if (row.error) { row.error.hidden = !row.invalid; }
      if (row.invalid) { row.input.setAttribute("aria-invalid", "true"); } else { row.input.removeAttribute("aria-invalid"); }
      if (row.swatch) { row.swatch.style.setProperty("background", row.value || "#ffffff"); }
      if (row.picker && document.activeElement !== row.picker) {
        var hex = sixDigitHex(row.value);
        if (hex) { row.picker.value = hex; }
      }
    }

    function drawChecks(map) {
      data.checks.forEach(function (check) {
        var foreground = check.foreground.charAt(0) === "#" ? check.foreground : map[check.foreground];
        var background = check.background.charAt(0) === "#" ? check.background : map[check.background];
        var value = check.id === "text-on-menu" && !map.menu ? null : ratio(foreground, background);
        var verdict = value === null ? "unknown" : (value >= data.minimum ? "pass" : "fail");
        Array.prototype.forEach.call(form.querySelectorAll('[data-thematiq-check="' + check.id + '"]'), function (line) {
          line.classList.remove("thematiq-editor__check--pass", "thematiq-editor__check--fail", "thematiq-editor__check--unknown");
          line.classList.add("thematiq-editor__check--" + verdict);
          var target = line.querySelector("[data-thematiq-verdict]");
          if (target) { target.textContent = String(texts.verdicts[verdict]).replace("%{ratio}", value === null ? "" : value.toFixed(2)); }
        });
      });
    }

    function drawCounts() {
      var total = 0;
      Array.prototype.forEach.call(form.querySelectorAll("[data-thematiq-group]"), function (group) {
        var mine = rows.filter(function (row) { return row.group === group; });
        var changed = mine.filter(function (row) { return row.changed; }).length;
        var touched = mine.some(function (row) { return row.input.value.trim() !== ""; });
        total += changed;
        var count = group.querySelector("[data-thematiq-count]");
        if (count) { count.textContent = plural(texts.count, changed); }
        var reset = group.querySelector("[data-thematiq-reset-group]");
        if (reset) { reset.hidden = !touched; }
      });
      var summary = form.querySelector("[data-thematiq-total]");
      if (summary) { summary.textContent = plural(texts.total, total); }
    }

    var search = form.querySelector("[data-thematiq-search]");
    var onlyChanged = form.querySelector("[data-thematiq-only-changed]");
    var noMatch = form.querySelector("[data-thematiq-no-match]");

    function filter() {
      var query = search ? search.value.trim().toLowerCase() : "";
      var only = onlyChanged ? onlyChanged.checked : false;
      var shown = 0;
      rows.forEach(function (row) {
        var show = (query === "" || row.text.indexOf(query) !== -1) && (!only || row.changed || row.invalid);
        row.element.hidden = !show;
        if (show) { shown += 1; }
      });
      Array.prototype.forEach.call(form.querySelectorAll("[data-thematiq-group]"), function (group) {
        group.hidden = !rows.some(function (row) { return row.group === group && !row.element.hidden; });
      });
      if (noMatch) { noMatch.hidden = shown !== 0; }
    }

    function draw() {
      rows.forEach(read);
      var map = values();
      rows.forEach(function (row) {
        frame.style.setProperty(PREFIX + row.key, row.value || "#ffffff");
        drawRow(row);
      });
      ["on-primary", "on-action", "on-menu", "on-selected"].forEach(function (name) {
        if (map["@" + name]) { frame.style.setProperty(PREFIX + name, map["@" + name]); }
      });
      drawChecks(map);
      drawCounts();
      filter();
    }

    rows.forEach(function (row) {
      row.input.addEventListener("input", draw);
      if (row.reset) {
        row.reset.addEventListener("click", function (event) {
          event.preventDefault();
          row.input.value = "";
          draw();
          row.input.focus();
        });
      }
      // A colour picker over the swatch. It writes a hex value into the text field, which stays the one field that is sent.
      if (row.kind === "color" && row.swatch) {
        var picker = document.createElement("input");
        picker.type = "color";
        picker.className = "thematiq-editor__picker";
        picker.setAttribute("aria-label", String(texts.pick).replace("%{token}", row.input.getAttribute("data-thematiq-label") || row.key));
        picker.addEventListener("input", function () {
          row.input.value = picker.value;
          draw();
        });
        row.swatch.removeAttribute("aria-hidden");
        row.swatch.appendChild(picker);
        row.picker = picker;
      }
    });

    Array.prototype.forEach.call(form.querySelectorAll("[data-thematiq-reset-group]"), function (button) {
      button.addEventListener("click", function (event) {
        event.preventDefault();
        var group = button.closest("[data-thematiq-group]");
        rows.forEach(function (row) { if (row.group === group) { row.input.value = ""; } });
        draw();
      });
    });

    if (search) { search.addEventListener("input", filter); }
    if (onlyChanged) { onlyChanged.addEventListener("change", filter); }
    var tools = form.querySelector("[data-thematiq-tools]");
    if (tools) { tools.hidden = false; }
    form.classList.add("is-live");
    draw();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
  document.addEventListener("turbo:load", init);
})();
