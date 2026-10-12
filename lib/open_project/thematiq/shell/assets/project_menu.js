// openproject-thematiq: the two-layer project menu.
//
// OpenProject opens and closes a submenu by toggling the class "open" on the row, and marks the
// current link with the class "selected". It sets no ARIA state for either. This script only
// mirrors those classes into aria-expanded, aria-controls and aria-current. It moves nothing and
// hides nothing, so the menu works the same without it.
(() => {
  const sync = () => {
    const menu = document.getElementById('main-menu');
    if (!menu) { return; }

    menu.querySelectorAll('ul.menu_root > li[data-name]').forEach((row) => {
      const toggler = row.querySelector(':scope > .main-item-wrapper > .toggler');
      const list = row.querySelector(':scope > ul.main-menu--children');
      const link = row.querySelector(':scope > .main-item-wrapper > a, :scope > a');

      if (toggler && list) {
        if (!list.id) { list.id = `thematiq-nav-sub-${row.dataset.name.replace(/[^A-Za-z0-9_-]/g, '-')}`; }
        toggler.setAttribute('aria-controls', list.id);
        toggler.setAttribute('aria-expanded', row.classList.contains('open') ? 'true' : 'false');
      }

      const currentChildren = list ? list.querySelectorAll('a.selected') : [];
      currentChildren.forEach((child) => child.setAttribute('aria-current', 'page'));
      if (list) {
        list.querySelectorAll('a[aria-current="page"]:not(.selected)').forEach((child) => child.removeAttribute('aria-current'));
      }

      if (!link) { return; }
      // A parent with a current child contains the current page. It is not the current page itself.
      if (link.classList.contains('selected') && currentChildren.length === 0) {
        link.setAttribute('aria-current', 'page');
      } else {
        link.removeAttribute('aria-current');
      }
    });
  };

  sync();

  if (window.thematiqProjectMenu) { return; }
  window.thematiqProjectMenu = true;

  // Core toggles the classes in its own click handler. Wait for it, then mirror them.
  const later = () => window.setTimeout(sync, 0);
  document.addEventListener('click', (event) => {
    if (event.target instanceof Element && event.target.closest('#main-menu')) { later(); }
  });
  document.addEventListener('turbo:frame-load', later);
  document.addEventListener('turbo:load', later);
  document.addEventListener('DOMContentLoaded', later);
})();
