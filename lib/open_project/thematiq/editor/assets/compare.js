// The apply dialog. The boxes repaint the picture of the shell after the switch: a value left unticked keeps the value
// of now. Apply sends the form and, when the answer comes, puts the new style sheets in the page's own style tags, so the
// page repaints without a reload. Without this script the form posts and the page loads again, with the same result.
(function () {
  "use strict";

  var PREFIX = "--tqp-";

  function init() {
    var form = document.getElementById("thematiq-compare-form");
    if (!form || form.getAttribute("data-thematiq-live") === "1") { return; }
    form.setAttribute("data-thematiq-live", "1");
    var texts = window.thematiqCompareTexts || {};
    var after = document.querySelector("[data-thematiq-after] [data-thematiq-preview]");
    var boxes = Array.prototype.slice.call(form.querySelectorAll("input[data-thematiq-take]"));

    // Only the light values of the roles are in the picture.
    function draw() {
      if (!after) { return; }
      boxes.forEach(function (box) {
        if (box.getAttribute("data-thematiq-layer") !== "light") { return; }
        var name = PREFIX + box.getAttribute("data-thematiq-key");
        // A value of the vocabulary has no property in the picture.
        if (after.style.getPropertyValue(name) === "") { return; }
        var value = box.checked ? box.getAttribute("data-thematiq-to") : box.getAttribute("data-thematiq-from");
        if (value) { after.style.setProperty(name, value); }
      });
    }

    boxes.forEach(function (box) { box.addEventListener("change", draw); });
    Array.prototype.forEach.call(document.querySelectorAll("[data-thematiq-select]"), function (button) {
      button.addEventListener("click", function () {
        var all = button.getAttribute("data-thematiq-select") === "all";
        boxes.forEach(function (box) { if (!box.disabled) { box.checked = all; } });
        draw();
      });
    });
    var tools = document.querySelector("[data-thematiq-compare-tools]");
    if (tools) { tools.hidden = false; }

    // Puts each style sheet in its tag. An empty one removes the tag; a tag the page lacks is added to the head.
    function swap(styles) {
      Object.keys(styles).forEach(function (id) {
        var element = document.getElementById(id);
        var css = styles[id];
        if (!css) {
          if (element) { element.parentNode.removeChild(element); }
          return;
        }
        if (!element) {
          element = document.createElement("style");
          element.id = id;
          element.setAttribute("data-turbo-track", "reload");
          document.head.appendChild(element);
        }
        element.textContent = css;
      });
    }

    form.addEventListener("submit", function (event) {
      if (!window.fetch || !window.FormData) { return; }
      event.preventDefault();
      var button = form.querySelector("[data-thematiq-apply]");
      if (button) { button.disabled = true; }
      window.fetch(form.action, {
        method: "POST",
        body: new FormData(form),
        credentials: "same-origin",
        headers: { Accept: "application/json" }
      }).then(function (response) {
        if (!response.ok) { throw new Error(String(response.status)); }
        return response.json();
      }).then(function (answer) {
        swap(answer.styles || {});
        var done = document.querySelector("[data-thematiq-applied]");
        var text = document.querySelector("[data-thematiq-applied-text]");
        if (text) { text.textContent = answer.notice; }
        var compare = document.querySelector("[data-thematiq-compare]");
        if (compare) { compare.hidden = true; }
        if (done) {
          done.hidden = false;
          done.setAttribute("tabindex", "-1");
          done.focus();
        }
      }).catch(function () {
        // Without an answer the page cannot repaint itself: send the form the plain way.
        if (button) { button.disabled = false; }
        if (texts.failed) { form.setAttribute("data-thematiq-failed", texts.failed); }
        HTMLFormElement.prototype.submit.call(form);
      });
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
  document.addEventListener("turbo:load", init);
})();
