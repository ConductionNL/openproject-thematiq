// Unit tests of the frontend module's icon pack logic. Run with bin/test-frontend (Node of the OpenProject image).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  fillRuleCss, isPack, PACK_ELEMENT_ID, readPack, redrawIconData, type IconData, type Pack,
} from '../../frontend/module/icon-pack/apply.ts';

const pack:Pack = {
  pack: 'dsfr',
  icons: {
    gear: { width: 24, height: 24, paths: ['M1 1h22v22H1z'], fill_rule: 'nonzero' },
    search: { width: 24, height: 25, paths: ['M2 2h20v20H2z', 'M4 4h2v2H4z'], fill_rule: 'evenodd' },
    'not-in-the-bundle': { width: 24, height: 24, paths: ['M0 0h1v1H0z'], fill_rule: 'nonzero' },
  },
};

function octicon():IconData {
  return { 16: { width: 16, paths: ['M8 0a8 8 0 1 1 0 16'] }, 24: { width: 24, paths: ['M12 0a12 12 0 1 1 0 24'] } };
}

test('redraws each mapped icon in place, with the pack\'s size as its only drawing', () => {
  const gear = octicon();
  const search = octicon();
  const untouched = octicon();
  const targets = { gear, search, x: untouched };

  const redrawn = redrawIconData(pack, targets);

  assert.deepEqual(redrawn.sort(), ['gear', 'search']);
  assert.equal(targets.gear, gear, 'the same object, so every component that holds it draws the pack');
  assert.deepEqual(gear, { 24: { width: 24, paths: ['M1 1h22v22H1z'] } });
  assert.deepEqual(search, { 25: { width: 24, paths: ['M2 2h20v20H2z', 'M4 4h2v2H4z'] } });
  assert.deepEqual(untouched, octicon(), 'an icon the pack does not map keeps core\'s drawing');
});

test('the pack\'s paths are copied, so the page cannot change them afterwards', () => {
  const gear = octicon();
  redrawIconData(pack, { gear });
  pack.icons.gear.paths.push('M9 9z');
  assert.deepEqual(gear[24].paths, ['M1 1h22v22H1z']);
  pack.icons.gear.paths.pop();
});

test('only even-odd icons get a fill rule, for the Angular and the server rendered form', () => {
  assert.equal(fillRuleCss(pack), 'svg[search-icon] path, svg.octicon-search path { fill-rule: evenodd; }');
});

test('a pack must be well formed to count', () => {
  assert.equal(isPack(pack), true);
  assert.equal(isPack(null), false);
  assert.equal(isPack({ pack: 'dsfr' }), false);
  assert.equal(isPack({ pack: '../x', icons: {} }), false);
  const broken = (icon:object) => ({ pack: 'dsfr', icons: { gear: { ...pack.icons.gear, ...icon } } });
  assert.equal(isPack(broken({ height: 24.5 })), false, 'the component finds a drawing by a whole height');
  assert.equal(isPack(broken({ width: 0 })), false);
  assert.equal(isPack(broken({ paths: [] })), false);
  assert.equal(isPack(broken({ paths: [''] })), false);
  assert.equal(isPack(broken({ fill_rule: 'inherit' })), false);
});

function page(element:{ type:string, text:string }|null):Document {
  return {
    getElementById: (id:string) => (id === PACK_ELEMENT_ID && element
      ? { getAttribute: (name:string) => (name === 'type' ? element.type : null), textContent: element.text }
      : null),
  } as unknown as Document;
}

test('reads the pack from the page, and nothing from a page without one or with a broken one', () => {
  assert.deepEqual(readPack(page({ type: 'application/json', text: JSON.stringify(pack) })), pack);
  assert.equal(readPack(page(null)), null);
  assert.equal(readPack(page({ type: 'application/json', text: '{' })), null);
  assert.equal(readPack(page({ type: 'text/javascript', text: JSON.stringify(pack) })), null);
  assert.equal(readPack(page({ type: 'application/json', text: '{"pack":"dsfr"}' })), null);
});
