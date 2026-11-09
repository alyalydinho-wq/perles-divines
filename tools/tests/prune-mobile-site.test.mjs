import assert from 'node:assert/strict';
import test from 'node:test';
import {planSitePrune, readNavigationRules} from '../prune-mobile-site.mjs';

const id = (n) => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const page = (n) => `pages/${id(n)}.html`;
const asset = (n, ext) => `assets/${id(n)}.${ext}`;
const link = (n) => `<a href="${id(n)}.html">x</a>`;
const img = (n) => `<img src="../assets/${id(n)}.gif">`;

function plan(pages, catalog, {extra = {}, updated = [], legacy = []} = {}) {
  const contents = {...pages, ...extra};
  const files = Object.keys(contents).map((p) => ({path: p, sha256: 'x', sizeBytes: 1}));
  for (const n of [10, 11, 12]) files.push({path: asset(n, 'gif'), sha256: 'x', sizeBytes: 1});
  return planSitePrune({
    bundle: {
      version: 'initial-2026-09-17-abc123',
      home: page(9),
      files,
      pages: Object.keys(pages).map((p) => ({path: p})),
    },
    catalog,
    read: (p) => contents[p],
    updatedDuaIds: new Set(updated),
    legacyPageIds: new Set(legacy),
  });
}

const paths = (result) => result.bundle.files.map((f) => f.path);

test('une page liée reste, une page sans chemin d’accès part avec ses images', () => {
  const result = plan({
    [page(1)]: link(2) + img(10),
    [page(2)]: img(11),
    [page(3)]: img(12),
    [page(9)]: '',
    'unavailable.html': '',
  }, [{id: id(1), kind: 'namaz', arabic: '', pagePath: page(1)}]);
  assert.deepEqual(result.removed.map((f) => f.path).sort(), [asset(12, 'gif'), page(3)].sort());
});

test('un lien vers une lecture native ou l’ancien sommaire n’ouvre pas la page', () => {
  const result = plan({
    [page(1)]: link(2) + link(3) + link(4),
    [page(2)]: img(10),
    [page(3)]: img(11),
    [page(4)]: img(12),
    [page(9)]: link(4),
    'unavailable.html': '',
  }, [
    {id: id(1), kind: 'namaz', arabic: '', pagePath: page(1)},
    {id: id(2), kind: 'ziyarat', arabic: 'ع', pagePath: ''},
    {id: id(3), kind: 'dua', arabic: 'ع', pagePath: ''},
  ], {legacy: [id(4)]});
  assert.ok(!paths(result).includes(page(2)));
  assert.ok(!paths(result).includes(page(4)));
  // Une doua hors de la liste « mise à jour » s’ouvre encore en page HTML.
  assert.ok(paths(result).includes(page(3)));
  assert.ok(paths(result).includes(asset(11, 'gif')));
});

test('seul le WOFF d’une police est gardé, et la page de secours reste', () => {
  const font = `@font-face{src:url("../assets/${id(20)}.eot");src:url("../assets/${id(21)}.svg#x") format('svg'),url("../assets/${id(22)}.woff") format('woff'),url("../assets/${id(23)}.ttf") format('truetype');}`;
  const result = plan({
    [page(1)]: font,
    [page(9)]: '',
    'unavailable.html': '',
    [asset(20, 'eot')]: '',
    [asset(21, 'svg')]: '',
    [asset(22, 'woff')]: '',
    [asset(23, 'ttf')]: '',
  }, [{id: id(1), kind: 'dua', arabic: '', pagePath: page(1)}]);
  const kept = paths(result);
  assert.ok(kept.includes(asset(22, 'woff')));
  for (const gone of [asset(20, 'eot'), asset(21, 'svg'), asset(23, 'ttf')]) assert.ok(!kept.includes(gone));
  assert.ok(kept.includes(page(9)));
  assert.ok(kept.includes('unavailable.html'));
});

test('la version change avec le contenu', () => {
  const pages = {[page(1)]: '', [page(3)]: '', [page(9)]: '', 'unavailable.html': ''};
  const catalog = [{id: id(1), kind: 'dua', arabic: '', pagePath: page(1)}];
  const first = plan(pages, catalog);
  assert.notEqual(first.bundle.version, 'initial-2026-09-17-abc123');
  assert.match(first.bundle.version, /^initial-2026-09-17-[0-9a-f]{12}$/);
  assert.ok(first.bundle.pages.every((p) => p.path !== page(3)));
});

test('une page du catalogue absente de l’édition arrête l’élagage', () => {
  assert.throws(() => plan({[page(9)]: '', 'unavailable.html': ''}, [
    {id: id(1), kind: 'dua', arabic: '', pagePath: page(1)},
  ]), /absente/);
});

test('les règles de navigation se lisent dans le code de l’application', async () => {
  const rules = await readNavigationRules('apps/mobile');
  assert.ok(rules.updatedDuaIds.size > 0);
  assert.ok(rules.legacyPageIds.size > 0);
});
