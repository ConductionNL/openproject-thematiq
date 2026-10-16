import { ICON_TARGETS } from './targets';
import {
  DRAWN_ATTRIBUTE, fillRuleCss, readPack, redrawIconData, redrawServerIcons,
} from './apply';

// Draws the page's icon pack. Runs when the bundle is evaluated, before Angular renders its first icon: an icon
// component reads its drawing once, so a later change would not reach it. Without a pack, core's icons stay.
export function installIconPack(doc:Document):void {
  const pack = readPack(doc);
  if (!pack) {
    return;
  }
  redrawIconData(pack, ICON_TARGETS);

  const css = fillRuleCss(pack);
  if (css) {
    const style = doc.createElement('style');
    style.id = 'thematiq-icon-pack-rules';
    style.textContent = css;
    doc.head.appendChild(style);
  }

  const redrawPage = () => redrawServerIcons(doc, pack);
  if (doc.readyState === 'loading') {
    doc.addEventListener('DOMContentLoaded', redrawPage, { once: true });
  } else {
    redrawPage();
  }
  // Turbo and Angular add server rendered markup later: dialogs, frames, the next page.
  new MutationObserver((records) => {
    records.forEach((record) => record.addedNodes.forEach((node) => {
      if (node instanceof Element) {
        redrawServerIcons(node, pack);
      }
    }));
  }).observe(doc.documentElement, { childList: true, subtree: true });

  doc.documentElement.setAttribute(DRAWN_ATTRIBUTE, pack.pack);
}
