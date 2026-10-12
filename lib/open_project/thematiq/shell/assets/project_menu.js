// openproject-thematiq: the two-layer project menu.
//
// OpenProject opens and closes a submenu by toggling the class "open" on the row, and marks the
// current link with the class "selected". It sets no ARIA state for either. This script mirrors
// those classes into aria-expanded, aria-controls, aria-label and aria-current.
//
// It also shortens a long submenu: more than LONG entries show the first SHOWN and a "Show all"
// button. Nothing is removed from the page, and the current entry is never hidden. Without this
// script every entry shows.
//
// The texts come from window.thematiqProjectMenuTexts, which the page sets from the locale file.
(() => {
  const LONG = 8;
  const SHOWN = 6;
  const HIDDEN = 'thematiq-nav-hidden';

  const text = (key, values) => {
    const template = (window.thematiqProjectMenuTexts || {})[key] || '';
    return Object.keys(values).reduce((result, name) => result.replace(`%{${name}}`, values[name]), template);
  };

  const nameOf = (link) => {
    const label = link && link.querySelector('.op-menu--item-title .ellipsis');
    return (label || link)?.textContent.trim() || '';
  };

  // The entries of a submenu: links in a module's frame, or plain menu children.
  const entriesOf = (list) => {
    const inFrame = list.querySelectorAll('.op-submenu--item');
    return inFrame.length > 0 ? [...inFrame] : [...list.querySelectorAll(':scope > li:not(.partial):not(.thematiq-nav-show-all)')];
  };

  const shorten = (list) => {
    if (list.dataset.thematiqShown === 'all' || list.querySelector('[role="tree"]')) { return; }

    const entries = entriesOf(list);
    list.querySelector(':scope > .thematiq-nav-show-all')?.remove();
    entries.forEach((entry) => entry.classList.remove(HIDDEN));
    if (entries.length <= LONG) { return; }

    entries.slice(SHOWN).forEach((entry) => {
      if (!entry.querySelector('a.selected')) { entry.classList.add(HIDDEN); }
    });

    const row = document.createElement('li');
    row.className = 'thematiq-nav-show-all';
    const button = document.createElement('button');
    button.type = 'button';
    button.setAttribute('aria-expanded', 'false');
    button.textContent = text('show_all', { count: entries.length });
    button.addEventListener('click', () => {
      list.dataset.thematiqShown = 'all';
      const firstHidden = entries.find((entry) => entry.classList.contains(HIDDEN));
      entries.forEach((entry) => entry.classList.remove(HIDDEN));
      row.remove();
      firstHidden?.querySelector('a')?.focus();
    });
    row.append(button);
    list.append(row);
  };

  const sync = () => {
    const menu = document.getElementById('main-menu');
    if (!menu || !menu.querySelector('.thematiq-project--initials')) { return; }

    menu.querySelectorAll('ul.menu_root > li[data-name]').forEach((row) => {
      const toggler = row.querySelector(':scope > .main-item-wrapper > .toggler');
      const list = row.querySelector(':scope > ul.main-menu--children');
      const link = row.querySelector(':scope > .main-item-wrapper > a, :scope > a');
      const open = row.classList.contains('open');

      if (toggler && list) {
        if (!list.id) { list.id = `thematiq-nav-sub-${row.dataset.name.replace(/[^A-Za-z0-9_-]/g, '-')}`; }
        toggler.setAttribute('aria-controls', list.id);
        toggler.setAttribute('aria-expanded', open ? 'true' : 'false');
        const label = text(open ? 'collapse' : 'expand', { name: nameOf(link) });
        if (label) { toggler.setAttribute('aria-label', label); }
        if (open) { shorten(list); }
      }

      const currentChildren = list ? list.querySelectorAll('a.selected') : [];
      currentChildren.forEach((child) => child.setAttribute('aria-current', 'page'));
      if (list) {
        list.querySelectorAll('a[aria-current="page"]:not(.selected)').forEach((child) => child.removeAttribute('aria-current'));
      }
      // The wiki's page tree is a tree view. It marks its current page itself.
      const currentInTree = list ? list.querySelector('[role="treeitem"][aria-current="true"]') : null;

      if (!link) { return; }
      // A parent with a current child contains the current page. It is not the current page itself.
      if (link.classList.contains('selected') && currentChildren.length === 0 && !currentInTree) {
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
