// The account menu under the avatar (Shell::AccountMenu): a button and a panel of links, as in Nextcloud.
// Click opens and closes it and keeps it open. The pointer opens it after a short pause and closes it when it
// leaves, unless a click opened it. Escape closes it and puts the focus back on the button. A click outside or
// the focus leaving it closes it. The arrow keys, Home and End move between the links; Tab works as well.
// OpenProject does not work without scripts, so neither does this menu.
(function () {
  "use strict";

  var OPEN_DELAY = 150;
  var CLOSE_DELAY = 300;

  function init() {
    var root = document.querySelector("[data-thematiq-account-menu]");
    if (!root || root.getAttribute("data-thematiq-live") === "1") { return; }
    root.setAttribute("data-thematiq-live", "1");
    var button = root.querySelector(".thematiq-account-menu--button");
    var panel = document.getElementById(button.getAttribute("aria-controls"));
    if (!button || !panel) { return; }

    var pinned = false;
    var timer = null;
    var hoverable = window.matchMedia && window.matchMedia("(hover: hover) and (pointer: fine)").matches;

    function entries() { return Array.prototype.slice.call(panel.querySelectorAll("[data-thematiq-account-entry]")); }
    function isOpen() { return button.getAttribute("aria-expanded") === "true"; }
    function later(fn, delay) { clearTimeout(timer); timer = setTimeout(fn, delay); }

    function open(byClick) {
      clearTimeout(timer);
      pinned = pinned || byClick;
      panel.hidden = false;
      button.setAttribute("aria-expanded", "true");
      root.classList.add("is-open");
    }

    function close(focusButton) {
      clearTimeout(timer);
      pinned = false;
      panel.hidden = true;
      button.setAttribute("aria-expanded", "false");
      root.classList.remove("is-open");
      if (focusButton) { button.focus(); }
    }

    button.addEventListener("click", function () {
      if (isOpen() && pinned) { close(false); } else { open(true); }
    });

    if (hoverable) {
      root.addEventListener("mouseenter", function () { if (!isOpen()) { later(function () { open(false); }, OPEN_DELAY); } else { clearTimeout(timer); } });
      root.addEventListener("mouseleave", function () {
        if (!isOpen()) { clearTimeout(timer); return; }
        if (!pinned) { later(function () { close(false); }, CLOSE_DELAY); }
      });
    }

    root.addEventListener("keydown", function (event) {
      if (event.key === "Escape" && isOpen()) {
        event.preventDefault();
        event.stopPropagation();
        close(true);
        return;
      }
      var list = entries();
      if (!list.length) { return; }
      var index = list.indexOf(document.activeElement);
      var next = null;
      if (event.key === "ArrowDown") {
        if (!isOpen()) { open(true); }
        next = index < 0 ? 0 : (index + 1) % list.length;
      } else if (event.key === "ArrowUp") {
        if (!isOpen()) { open(true); }
        next = index <= 0 ? list.length - 1 : index - 1;
      } else if (isOpen() && index >= 0 && event.key === "Home") {
        next = 0;
      } else if (isOpen() && index >= 0 && event.key === "End") {
        next = list.length - 1;
      }
      if (next === null) { return; }
      event.preventDefault();
      list[next].focus();
    });

    // The focus leaving the menu closes it, for keyboard users who Tab past the last link.
    root.addEventListener("focusout", function (event) {
      if (isOpen() && event.relatedTarget && !root.contains(event.relatedTarget)) { close(false); }
    });

    document.addEventListener("click", function (event) {
      if (isOpen() && !root.contains(event.target)) { close(false); }
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
  document.addEventListener("turbo:load", init);
})();
