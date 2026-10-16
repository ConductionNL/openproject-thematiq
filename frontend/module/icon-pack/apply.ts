// The icon pack on OpenProject's own icons. Kept free of imports, so its tests run in Node without Angular.

// The data object @openproject/octicons-angular exports per icon: per natural height, the width and the paths.
// The icon component and toDOMString both read this one object, so redrawing it redraws every use.
export type IconData = Record<string, { width:number, paths:string[] }>;

export interface PackIcon {
  width:number;
  height:number;
  paths:string[];
  fill_rule:string;
}

export interface Pack {
  pack:string;
  icons:Record<string, PackIcon>;
}

// The element the head hook renders, with the pack as JSON (IconPacks.payload).
export const PACK_ELEMENT_ID = 'thematiq-icon-pack';
// On <html> once the pack is drawn, and on each server rendered icon the module redrew.
export const DRAWN_ATTRIBUTE = 'data-thematiq-icon-pack';

function isIcon(value:unknown):value is PackIcon {
  const icon = value as PackIcon;
  return typeof icon === 'object' && icon !== null
    && Number.isFinite(icon.width) && icon.width > 0
    && Number.isInteger(icon.height) && icon.height > 0
    && Array.isArray(icon.paths) && icon.paths.length > 0 && icon.paths.every((path) => typeof path === 'string' && path.length > 0)
    && (icon.fill_rule === 'nonzero' || icon.fill_rule === 'evenodd');
}

export function isPack(value:unknown):value is Pack {
  const pack = value as Pack;
  return typeof pack === 'object' && pack !== null
    && typeof pack.pack === 'string' && /^[a-z0-9-]{1,40}$/.test(pack.pack)
    && typeof pack.icons === 'object' && pack.icons !== null
    && Object.values(pack.icons).every(isIcon);
}

// The pack the page names, or null when it names none or the JSON is not a pack.
export function readPack(doc:Document):Pack|null {
  const element = doc.getElementById(PACK_ELEMENT_ID);
  if (!element || element.getAttribute('type') !== 'application/json') {
    return null;
  }
  try {
    const value:unknown = JSON.parse(element.textContent || '');
    return isPack(value) ? value : null;
  } catch {
    return null;
  }
}

// Replaces the drawing of each mapped icon in place. Returns the names it redrew.
export function redrawIconData(pack:Pack, targets:Record<string, IconData>):string[] {
  const redrawn:string[] = [];
  Object.entries(pack.icons).forEach(([name, icon]) => {
    const target = targets[name];
    if (!target) {
      return;
    }
    Object.keys(target).forEach((height) => { delete target[height]; });
    target[String(icon.height)] = { width: icon.width, paths: [...icon.paths] };
    redrawn.push(name);
  });
  return redrawn;
}

// CSS for the icons drawn with the even-odd rule: the octicon component draws bare paths, so the rule comes from CSS.
export function fillRuleCss(pack:Pack):string {
  return Object.entries(pack.icons)
    .filter(([, icon]) => icon.fill_rule === 'evenodd')
    .map(([name]) => `svg[${name}-icon] path, svg.octicon-${name} path { fill-rule: evenodd; }`)
    .join('\n');
}

const SVG_NAMESPACE = 'http://www.w3.org/2000/svg';

// Icons the server renders (Primer::Beta::Octicon) carry the class octicon-<name>. Redraws those the pack maps.
// Returns how many it redrew.
export function redrawServerIcons(root:Document|Element, pack:Pack):number {
  let count = 0;
  const icons = Array.from(root.querySelectorAll('svg.octicon'));
  if ('matches' in root && root.matches('svg.octicon')) {
    icons.unshift(root);
  }
  icons.forEach((svg) => {
    if (svg.hasAttribute(DRAWN_ATTRIBUTE)) {
      return;
    }
    const name = Array.from(svg.classList).find((value) => value.startsWith('octicon-'))?.slice('octicon-'.length);
    const icon = name ? pack.icons[name] : undefined;
    if (!icon) {
      return;
    }
    const doc = svg.ownerDocument;
    svg.querySelectorAll('path').forEach((path) => path.remove());
    icon.paths.forEach((d) => {
      const path = doc.createElementNS(SVG_NAMESPACE, 'path');
      path.setAttribute('d', d);
      if (icon.fill_rule === 'evenodd') {
        path.setAttribute('fill-rule', 'evenodd');
      }
      svg.appendChild(path);
    });
    svg.setAttribute('viewBox', `0 0 ${icon.width} ${icon.height}`);
    svg.setAttribute(DRAWN_ATTRIBUTE, pack.pack);
    count += 1;
  });
  return count;
}
