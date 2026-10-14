// The list under the nine-dot button: keeps aria-expanded on the button in step with the dialog, and moves
// between the entries with the arrow keys, Home and End. Tab works as well. Escape is the dialog's own.
(function () {
  "use strict";

  function init() {
    var dialog = document.getElementById("thematiq-switcher");
    var button = document.getElementById("dialog-show-thematiq-switcher");
    if (!dialog || !button || dialog.getAttribute("data-thematiq-live") === "1") { return; }
    dialog.setAttribute("data-thematiq-live", "1");

    function sync() { button.setAttribute("aria-expanded", dialog.open ? "true" : "false"); }
    new MutationObserver(sync).observe(dialog, { attributes: true, attributeFilter: ["open"] });
    sync();

    dialog.addEventListener("keydown", function (event) {
      if (["ArrowDown", "ArrowUp", "Home", "End"].indexOf(event.key) === -1) { return; }
      var entries = Array.prototype.slice.call(dialog.querySelectorAll("[data-thematiq-switcher-entry], .thematiq-switcher--manage"));
      if (!entries.length) { return; }
      var index = entries.indexOf(document.activeElement);
      var next;
      if (event.key === "Home") { next = 0; }
      else if (event.key === "End") { next = entries.length - 1; }
      else if (event.key === "ArrowDown") { next = (index + 1) % entries.length; }
      else { next = index <= 0 ? entries.length - 1 : index - 1; }
      event.preventDefault();
      entries[next].focus();
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
  document.addEventListener("turbo:load", init);
})();
