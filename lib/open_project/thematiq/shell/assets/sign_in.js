// The sign-in page (Shell::SignIn): puts the line that says who signs in here under the card's heading.
// Without the script it stays above the card, which reads the same.
(function () {
  "use strict";

  function place() {
    var lead = document.querySelector("[data-thematiq-sign-in-lead]");
    var heading = document.querySelector("#login-form > h1");
    if (!lead || !heading || heading.nextElementSibling === lead) { return; }
    heading.insertAdjacentElement("afterend", lead);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", place);
  } else {
    place();
  }
  document.addEventListener("turbo:load", place);
})();
