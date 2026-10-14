// The live side of the style editor. It reads the form and writes custom properties on the picture
// of the shell, so a change shows while you type. Nothing is sent and nothing is saved here.
// The server checks every value again on save: this script only decides what the picture shows.
(function () {
  "use strict";

  var PREFIX = "--tqp-";
  var HEX = /^#(?:[0-9a-f]{3}|[0-9a-f]{4}|[0-9a-f]{6}|[0-9a-f]{8})$/;
  var COLOR_FUNCTION = /^(?:rgba?|hsla?|hwb|lab|lch|oklab|oklch)\(([0-9a-z.,%\/\s-]{1,60})\)$/;
  var COLOR_ARGUMENT = /^(?:-?(?:\d{1,4}(?:\.\d{1,4})?|\.\d{1,4})(?:%|deg|turn|rad|grad)?|none)$/;
  var LENGTH = /^(?:0|(?:\d{1,3}(?:\.\d{1,4})?|\.\d{1,4})(?:px|rem|em|%))$/;
  var QUOTED_FAMILY = /^(["'])[A-Za-z0-9 _.-]{1,60}\1$/;
  var BARE_FAMILY = /^-?[A-Za-z_][A-Za-z0-9_-]*(?: [A-Za-z_][A-Za-z0-9_-]*)*$/;
  // The kinds of the vocabulary, the same patterns as the validator.
  var SIZE = /^(?:0|(?:\d{1,4}(?:\.\d{1,4})?|\.\d{1,4})(?:px|rem|em|%))$/;
  var PLAIN = {
    font_weight: /^(?:[1-9]\d{0,2}|1000|normal|bold)$/,
    number: /^(?:\d{1,4}(?:\.\d{1,4})?|\.\d{1,4})$/,
    duration: /^(?:\d{1,5}(?:\.\d{1,3})?|\.\d{1,3})(?:ms|s)$/,
    text_transform: /^(?:none|uppercase|lowercase|capitalize)$/
  };
  var RGB_TRIPLET = /^(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})$/;
  var FILTER_FUNCTION = /^(?:(?:brightness|contrast|grayscale|invert|opacity|saturate|sepia)\((?:\d{1,3}(?:\.\d{1,3})?|\.\d{1,3})%?\)|hue-rotate\(-?\d{1,3}(?:\.\d{1,3})?deg\))$/;
  var BORDER = /^(\S{1,12})\s+(solid|dashed|dotted|double)\s+(.{1,80})$/;

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
    if (PLAIN[kind]) {
      text = text.toLowerCase();
      return PLAIN[kind].test(text) ? text : null;
    }
    if (kind === "size") {
      text = text.toLowerCase();
      return SIZE.test(text) ? text : null;
    }
    if (kind === "offset") {
      text = text.toLowerCase();
      return text === "auto" ? text : clean("length", text, named);
    }
    if (kind === "rgb_triplet") {
      var channels = RGB_TRIPLET.exec(text);
      if (!channels) { return null; }
      var numbers = [1, 2, 3].map(function (i) { return parseInt(channels[i], 10); });
      return numbers.every(function (value) { return value <= 255; }) ? numbers.join(", ") : null;
    }
    if (kind === "filter") {
      text = text.toLowerCase();
      if (text === "none") { return text; }
      var functions = text.split(/\s+/);
      if (text.length > 200 || functions.length > 6) { return null; }
      return functions.every(function (part) { return FILTER_FUNCTION.test(part); }) ? functions.join(" ") : null;
    }
    if (kind === "border") {
      text = text.toLowerCase();
      if (text === "0" || text === "none") { return text; }
      var border = BORDER.exec(text);
      if (!border) { return null; }
      var width = clean("length", border[1], named);
      var colour = clean("color", border[3], named);
      return width && colour ? width + " " + border[2] + " " + colour : null;
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

  function hexByte(value) {
    return ("0" + Math.round(value).toString(16)).slice(-2);
  }

  function sixDigitHex(color) {
    var channels = rgba(color);
    if (!channels || channels[3] !== 1) { return null; }
    return "#" + channels.slice(0, 3).map(hexByte).join("");
  }

  // The colour without its transparency, as #rrggbb, and the transparency in percent. null for a syntax not read here.
  function hexAndAlpha(color) {
    var text = typeof color === "string" ? color.trim().toLowerCase() : "";
    var long = /^#([0-9a-f]{6})([0-9a-f]{2})$/.exec(text);
    if (long) { return { hex: "#" + long[1], alpha: Math.round(parseInt(long[2], 16) / 255 * 100) }; }
    var short = /^#([0-9a-f])([0-9a-f])([0-9a-f])([0-9a-f])$/.exec(text);
    if (short) {
      return { hex: "#" + short[1] + short[1] + short[2] + short[2] + short[3] + short[3],
               alpha: Math.round(parseInt(short[4] + short[4], 16) / 255 * 100) };
    }
    var channels = rgba(text);
    if (!channels) { return null; }
    return { hex: "#" + channels.slice(0, 3).map(hexByte).join(""), alpha: Math.round(channels[3] * 100) };
  }

  // At full opacity #rrggbb, below it #rrggbbaa, the way thematiq writes it.
  function withAlpha(hex, alpha) {
    return alpha >= 100 ? hex : hex + hexByte(Math.max(0, alpha) / 100 * 255);
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

    // The dark field of a colour row, when it has one. Its value is checked like the light one and never drawn in the picture.
    function darkPart(element) {
      var block = element.querySelector("[data-thematiq-dark-row]");
      var input = block ? block.querySelector("input[data-thematiq-dark]") : null;
      if (!input) { return null; }
      return { input: input, base: input.getAttribute("data-thematiq-base") || "", swatch: block.querySelector(".thematiq-editor__swatch"),
               badge: block.querySelector("[data-thematiq-dark-badge]"), error: block.querySelector("[data-thematiq-dark-error]"),
               controls: null, changed: false, invalid: false, value: "" };
    }

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
        dark: darkPart(element),
        text: element.textContent.toLowerCase() + " " + input.getAttribute("data-thematiq-token"),
        controls: null,
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
      if (row.dark) {
        var darkTyped = row.dark.input.value.trim();
        var darkCleaned = darkTyped === "" ? null : clean("color", darkTyped, data.named);
        row.dark.invalid = darkTyped !== "" && darkCleaned === null;
        row.dark.changed = darkCleaned !== null && darkCleaned !== row.dark.base;
        row.dark.value = darkCleaned === null ? row.dark.base : darkCleaned;
      }
    }

    // How many values of a row differ: the light one and the dark one count apart, as on the server.
    function changedCount(row) {
      return (row.changed ? 1 : 0) + (row.dark && row.dark.changed ? 1 : 0);
    }

    function touched(row) {
      return row.input.value.trim() !== "" || (row.dark !== null && row.dark.input.value.trim() !== "");
    }

    function invalid(row) {
      return row.invalid || (row.dark !== null && row.dark.invalid);
    }

    // A swatch shows its colour over a checkerboard, so a colour with transparency shows as such. No colour: the checkerboard.
    function paintSwatch(swatch, colour) {
      if (!swatch) { return; }
      swatch.style.setProperty("background", colour ? "linear-gradient(" + colour + ", " + colour + "), " + data.checkerboard : data.checkerboard);
    }

    // The colour picker and the opacity control follow the field, unless one of them is being used.
    function syncControls(controls, value) {
      if (!controls) { return; }
      var parts = hexAndAlpha(value);
      if (!parts) { return; }
      if (document.activeElement !== controls.picker) { controls.picker.value = parts.hex; }
      if (document.activeElement !== controls.opacity) { controls.opacity.value = String(parts.alpha); }
      controls.opacity.setAttribute("aria-valuetext", parts.alpha + "%");
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
      row.element.classList.toggle("is-changed", changedCount(row) > 0);
      row.element.classList.toggle("is-invalid", invalid(row));
      if (row.badge) { row.badge.hidden = !row.changed; }
      if (row.reset) { row.reset.hidden = !touched(row); }
      if (row.error) { row.error.hidden = !row.invalid; }
      if (row.invalid) { row.input.setAttribute("aria-invalid", "true"); } else { row.input.removeAttribute("aria-invalid"); }
      paintSwatch(row.swatch, row.value || "#ffffff");
      syncControls(row.controls, row.value);
      if (row.dark) {
        var dark = row.dark;
        if (dark.badge) { dark.badge.hidden = !dark.changed; }
        if (dark.error) { dark.error.hidden = !dark.invalid; }
        if (dark.invalid) { dark.input.setAttribute("aria-invalid", "true"); } else { dark.input.removeAttribute("aria-invalid"); }
        paintSwatch(dark.swatch, dark.value || null);
        syncControls(dark.controls, dark.value);
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
        var changed = mine.reduce(function (sum, row) { return sum + changedCount(row); }, 0);
        var anyTouched = mine.some(touched);
        total += changed;
        var count = group.querySelector("[data-thematiq-count]");
        if (count) { count.textContent = plural(texts.count, changed); }
        var reset = group.querySelector("[data-thematiq-reset-group]");
        if (reset) { reset.hidden = !anyTouched; }
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
        var show = (query === "" || row.text.indexOf(query) !== -1) && (!only || changedCount(row) > 0 || invalid(row));
        row.element.hidden = !show;
        if (show) { shown += 1; }
      });
      Array.prototype.forEach.call(form.querySelectorAll("[data-thematiq-group]"), function (group) {
        var any = rows.some(function (row) { return row.group === group && !row.element.hidden; });
        group.hidden = !any;
        // A closed group of the vocabulary opens when a search or the filter finds a value in it, and hides when it finds none.
        var more = group.closest("[data-thematiq-more]");
        if (more) {
          more.hidden = !any;
          if (any && (query !== "" || only)) { more.open = true; }
        }
      });
      if (noMatch) { noMatch.hidden = shown !== 0; }
    }

    function draw() {
      rows.forEach(read);
      var map = values();
      rows.forEach(function (row) {
        // The picture of the shell only reads the roles. A value of the vocabulary is checked, not drawn there.
        if (data.preview.indexOf(row.key) !== -1) { frame.style.setProperty(PREFIX + row.key, row.value || "#ffffff"); }
        drawRow(row);
      });
      ["on-primary", "on-action", "on-menu", "on-selected"].forEach(function (name) {
        if (map["@" + name]) { frame.style.setProperty(PREFIX + name, map["@" + name]); }
      });
      drawChecks(map);
      drawCounts();
      filter();
    }

    // A colour picker over the swatch and an opacity control beside it. Both write into the text field, which stays
    // the one field that is sent. The picker keeps the opacity; the opacity control keeps the colour.
    function attachControls(input, swatch, fallback) {
      var label = input.getAttribute("data-thematiq-label") || input.getAttribute("data-thematiq-token") || "";
      var current = function () {
        return hexAndAlpha(clean("color", input.value, data.named) || fallback() || "#ffffff") || { hex: "#ffffff", alpha: 100 };
      };
      var picker = document.createElement("input");
      picker.type = "color";
      picker.className = "thematiq-editor__picker";
      picker.setAttribute("aria-label", String(texts.pick).replace("%{token}", label));
      picker.addEventListener("input", function () {
        input.value = withAlpha(picker.value, current().alpha);
        draw();
      });
      swatch.removeAttribute("aria-hidden");
      swatch.appendChild(picker);

      var opacity = document.createElement("input");
      opacity.type = "range";
      opacity.min = "0";
      opacity.max = "100";
      opacity.step = "1";
      opacity.value = "100";
      opacity.className = "thematiq-editor__opacity";
      opacity.setAttribute("aria-label", String(texts.opacity).replace("%{token}", label));
      opacity.setAttribute("data-thematiq-opacity", "");
      opacity.addEventListener("input", function () {
        input.value = withAlpha(current().hex, parseInt(opacity.value, 10));
        draw();
      });
      swatch.parentNode.insertBefore(opacity, swatch.nextSibling);
      return { picker: picker, opacity: opacity };
    }

    rows.forEach(function (row) {
      row.input.addEventListener("input", draw);
      if (row.dark) { row.dark.input.addEventListener("input", draw); }
      if (row.reset) {
        row.reset.addEventListener("click", function (event) {
          event.preventDefault();
          row.input.value = "";
          if (row.dark) { row.dark.input.value = ""; }
          draw();
          row.input.focus();
        });
      }
      if (row.kind === "color" && row.swatch) {
        row.controls = attachControls(row.input, row.swatch, function () { return row.base; });
      }
      if (row.dark && row.dark.swatch) {
        var dark = row.dark;
        dark.controls = attachControls(dark.input, dark.swatch, function () { return dark.base || row.value; });
      }
    });

    Array.prototype.forEach.call(form.querySelectorAll("[data-thematiq-reset-group]"), function (button) {
      button.addEventListener("click", function (event) {
        event.preventDefault();
        var group = button.closest("[data-thematiq-group]");
        rows.forEach(function (row) {
          if (row.group !== group) { return; }
          row.input.value = "";
          if (row.dark) { row.dark.input.value = ""; }
        });
        draw();
      });
    });

    // The preview as a module's design system: the top bar and the menu keep the instance's values, the content follows the form.
    var scope = document.querySelector("[data-thematiq-scope]");
    var scopeTools = document.querySelector("[data-thematiq-scope-tools]");
    function drawScope() {
      var module = scope && scope.value === "module";
      Array.prototype.forEach.call(frame.querySelectorAll(".thematiq-shell__bar, .thematiq-shell__side"), function (part) {
        Object.keys(data.instance || {}).forEach(function (name) {
          if (name.indexOf(PREFIX) !== 0) { return; }
          if (module) { part.style.setProperty(name, data.instance[name]); } else { part.style.removeProperty(name); }
        });
      });
      frame.setAttribute("data-thematiq-scope-shown", module ? "module" : "page");
      Array.prototype.forEach.call(document.querySelectorAll("[data-thematiq-scope-hint]"), function (hint) {
        hint.hidden = hint.getAttribute("data-thematiq-scope-hint") !== (module ? "module" : "page");
        if (!hint.hidden && scope) { scope.setAttribute("aria-describedby", hint.id || ""); }
      });
    }
    if (scope && data.instance) {
      scope.addEventListener("change", drawScope);
      if (scopeTools) { scopeTools.hidden = false; }
      drawScope();
    }

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
