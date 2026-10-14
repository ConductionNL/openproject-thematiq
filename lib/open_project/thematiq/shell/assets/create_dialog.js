/* Every create action of a project opens core's create dialog instead of a page. See Shell::CreateDialog.
 *
 * Core's dialog comes from /projects/:id/work_packages/dialog/new as a Turbo stream, the way core's own
 * "async-dialog" links fetch it. The form inside, its validation and its save are core's. On success core
 * redirects back to the page the dialog was opened on, so the view reloads with the new work package.
 * A click with a modifier key, or a middle click, still opens core's page in a new tab. */
(function () {
  "use strict";

  if (!document.body) { return; }
  document.body.classList.add("thematiq-create-dialog");
  // The body is new on each Turbo visit; the listener on the document is bound once.
  if (window.thematiqCreateDialogBound) { return; }
  window.thematiqCreateDialogBound = true;

  var DIALOG_ID = "create-work-package-dialog";
  var opener = null;

  function kit() { return window.thematiqCreateDialog; }

  function active() {
    return kit() && document.body.classList.contains("thematiq-create-dialog") && window.Turbo && typeof window.Turbo.renderStreamMessage === "function";
  }

  function currentProject() {
    var meta = document.querySelector('meta[name="current_project"]');
    return meta ? { identifier: meta.getAttribute("data-project-identifier"), name: meta.getAttribute("data-project-name") } : null;
  }

  // The create pages of a project: /projects/:id/work_packages/new and the split view .../create_new of any module.
  function dialogRequest(href) {
    var url;
    try { url = new URL(href, window.location.href); } catch (e) { return null; }
    if (url.origin !== window.location.origin) { return null; }
    var root = kit().root || "";
    var path = url.pathname;
    if (root && path.indexOf(root + "/") === 0) { path = path.slice(root.length); }
    var match = /^\/projects\/([^\/]+)\/(?:work_packages\/new|(?:[^\/]+\/)*create_new)\/?$/.exec(path);
    if (!match) { return null; }
    var params = new URLSearchParams();
    var type = url.searchParams.get("type") || url.searchParams.get("type_id");
    if (type) { params.set("type_id", type); }
    if (url.searchParams.get("parent_id")) { params.set("parent_id", url.searchParams.get("parent_id")); }
    return { project: decodeURIComponent(match[1]), params: params, fallback: url.href };
  }

  function requestFor(target) {
    if (target.matches("button.add-work-package")) {
      // The page's Create button: the dialog has a type field of its own, so it opens without the list of types.
      var project = currentProject();
      if (!project || target.disabled) { return null; }
      return { project: project.identifier, params: new URLSearchParams(), fallback: null };
    }
    return dialogRequest(target.getAttribute("href"));
  }

  // Focus goes back to a control that is still on screen: a menu entry is gone once its menu closes.
  function returnTarget(target) {
    var popover = target.closest("[popover]");
    if (popover && popover.id) {
      var button = document.querySelector('[popovertarget="' + popover.id + '"], [aria-controls="' + popover.id + '"]');
      if (button) { return button; }
    }
    var menu = target.closest("action-menu");
    if (menu) { return menu.querySelector("button[aria-haspopup]") || menu.querySelector("button"); }
    if (target.closest(".op-context-menu--overlay")) { return document.querySelector("wp-create-button button.add-work-package"); }
    return target;
  }

  function closeMenus(target) {
    var popover = target.closest("[popover]");
    if (popover && typeof popover.hidePopover === "function") {
      try { popover.hidePopover(); } catch (e) { /* already closed */ }
    }
    if (target.closest(".op-context-menu--overlay")) {
      document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }));
    }
  }

  function decorate(dialog, projectIdentifier) {
    var texts = kit().texts || {};
    var title = dialog.querySelector(".Overlay-title");
    if (title && texts.title) { title.textContent = texts.title; }
    var submit = dialog.querySelector('.Overlay-footer button[type="submit"] .Button-label');
    if (submit && texts.submit) { submit.textContent = texts.submit; }
    var project = currentProject();
    var wrap = dialog.querySelector(".Overlay-titleWrap");
    if (wrap && project && project.identifier === projectIdentifier && project.name && !wrap.querySelector(".thematiq-create__project")) {
      var eyebrow = document.createElement("p");
      eyebrow.className = "thematiq-create__project";
      eyebrow.textContent = project.name;
      wrap.insertBefore(eyebrow, wrap.firstChild);
    }
    if (!dialog.hasAttribute("data-thematiq-bound")) {
      dialog.setAttribute("data-thematiq-bound", "");
      dialog.addEventListener("close", function () {
        var back = opener;
        opener = null;
        if (back && back.isConnected) { setTimeout(function () { back.focus(); }, 0); }
      });
    }
  }

  function open(request, back) {
    var path = (kit().root || "") + "/projects/" + encodeURIComponent(request.project) + "/work_packages/dialog/new";
    var query = request.params.toString();
    opener = back;
    window.fetch(path + (query ? "?" + query : ""), {
      headers: { Accept: "text/vnd.turbo-stream.html" },
      credentials: "same-origin"
    }).then(function (response) {
      var type = response.headers.get("Content-Type") || "";
      if (!response.ok || type.indexOf("text/vnd.turbo-stream.html") < 0) { throw new Error("no dialog: " + response.status); }
      return response.text();
    }).then(function (html) {
      window.Turbo.renderStreamMessage(html);
      var tries = 0;
      (function find() {
        var dialog = document.getElementById(DIALOG_ID);
        if (dialog) { decorate(dialog, request.project); return; }
        if (tries++ < 40) { setTimeout(find, 25); }
      })();
    }).catch(function (error) {
      if (window.console) { window.console.warn("[thematiq] create dialog:", error); }
      // Core's own page, as without the plugin.
      if (request.fallback) { window.location.href = request.fallback; }
    });
  }

  document.addEventListener("click", function (event) {
    if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) { return; }
    if (!active()) { return; }
    var target = event.target.closest && event.target.closest("a[href], button.add-work-package");
    if (!target || (target.target && target.target !== "_top" && target.target !== "_self")) { return; }
    var request = requestFor(target);
    if (!request) { return; }
    event.preventDefault();
    event.stopImmediatePropagation();
    var back = returnTarget(target);
    closeMenus(target);
    open(request, back);
  }, true);
})();
