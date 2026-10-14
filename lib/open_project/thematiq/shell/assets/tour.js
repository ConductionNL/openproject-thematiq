// openproject-thematiq: OpenProject's introduction tour on the plugin's project menu.
//
// Core's two-layer menu has a return arrow at the top of a module's submenu. The plugin's project menu opens
// a submenu in place, so the main menu never goes away and the arrow is hidden. The tour still had a step
// that points at it ("Use the return arrow in the top left corner"), drawn at the top left corner of the page
// (first full test, finding 8). This drops the steps whose target is that arrow, and nothing else.
//
// Core is not changed: the tour builds its steps and hands them to window.EnjoyHint, which core defines when
// it loads the tour. This wraps that constructor, so the list of steps is filtered on its way in.
(() => {
  const RETURN_ARROW = /main-menu--arrow-left/;
  const pointsAtTheArrow = (step) => Boolean(step) && Object.keys(step).some((key) => RETURN_ARROW.test(key));
  // The arrow is only hidden where the plugin's menu is in place (see stylesheets/shell/30-nested-menu.css).
  // When the core guard turned the menu off, core's arrow shows and the tour stays as it is.
  const nestedMenu = () => document.querySelector('#main-menu .thematiq-project--initials') !== null;

  const wrap = (Original) => {
    if (typeof Original !== 'function' || Original.thematiqTour) { return Original; }

    function Wrapped(options) {
      const instance = new Original(options);
      const set = instance.set;
      if (typeof set === 'function') {
        instance.set = function setSteps(steps) {
          const keep = Array.isArray(steps) && nestedMenu() ? steps.filter((step) => !pointsAtTheArrow(step)) : steps;
          return set.call(this, keep);
        };
      }
      return instance;
    }
    Wrapped.prototype = Original.prototype;
    Wrapped.thematiqTour = true;
    return Wrapped;
  };

  let current = wrap(window.EnjoyHint);
  try {
    Object.defineProperty(window, 'EnjoyHint', {
      configurable: true,
      get: () => current,
      set: (value) => { current = wrap(value); },
    });
  } catch (error) {
    // Another script made the property fixed. The tour then runs as core wrote it.
  }
})();
