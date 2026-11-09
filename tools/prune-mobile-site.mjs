import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';
import {pathToFileURL} from 'node:url';

const uuid = '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}';
const pageLink = new RegExp(`(${uuid})\\.html`, 'gi');
const assetLink = new RegExp(`assets/(${uuid}\\.[a-z0-9]+)`, 'gi');
const bareAsset = new RegExp(`(${uuid}\\.[a-z0-9]+)`, 'gi');
const fontFace = /@font-face\s*\{[^}]*\}/gi;

/// Android et iOS lisent le WOFF : les autres formats d'une même police ne sont jamais chargés.
function withoutUnusedFontFormats(text) {
  return text.replace(fontFace, (block) => {
    if (!/\.woff\b/i.test(block)) return block;
    return block.replace(/url\([^)]*\.(eot|svg|ttf)[^)]*\)/gi, '');
  });
}

/// Règle de `opensUpdatedReading` (dua.dart) : ce lien ouvre la lecture native, pas la page.
function opensNativeReading(item, updatedDuaIds) {
  return Boolean(item.arabic?.trim())
    && !item.pagePath
    && (item.kind === 'quran'
      || item.kind === 'ziyarat'
      || (item.kind === 'dua' && updatedDuaIds.has(item.id)));
}

/// Calcule ce que l'application peut réellement afficher, sans toucher au disque.
export function planSitePrune({bundle, catalog, read, updatedDuaIds, legacyPageIds}) {
  const items = new Map(catalog.map((item) => [item.id, item]));
  const parsed = new Map();
  for (const file of bundle.files.filter((f) => f.path.endsWith('.html') || f.path.endsWith('.css'))) {
    const text = withoutUnusedFontFormats(read(file.path));
    parsed.set(file.path, {
      links: [...new Set([...text.matchAll(pageLink)].map((m) => m[1].toLowerCase()))],
      assets: file.path.endsWith('.css')
        ? [...new Set([...text.matchAll(bareAsset)].map((m) => `assets/${m[1]}`))]
        : [...new Set([...text.matchAll(assetLink)].map((m) => `assets/${m[1]}`))],
    });
  }
  const entries = catalog.filter((item) => item.pagePath).map((item) => item.pagePath);
  for (const entry of entries) {
    if (!parsed.has(entry)) throw new Error(`Page du catalogue absente de l'édition : ${entry}`);
  }
  const pages = new Set();
  const queue = [...entries];
  while (queue.length) {
    const page = queue.pop();
    if (pages.has(page) || !parsed.has(page)) continue;
    pages.add(page);
    for (const id of parsed.get(page).links) {
      if (legacyPageIds.has(id)) continue;
      const item = items.get(id);
      if (item && opensNativeReading(item, updatedDuaIds)) continue;
      queue.push(`pages/${id}.html`);
    }
  }
  // L'accueil reste la page de secours de `_startFile` ; la page d'erreur reste liée par le site.
  const keep = new Set([bundle.home, 'unavailable.html', ...pages]);
  for (const page of [...keep]) {
    for (const asset of parsed.get(page)?.assets ?? []) {
      keep.add(asset);
      for (const nested of parsed.get(asset)?.assets ?? []) keep.add(nested);
    }
  }
  const files = bundle.files.filter((file) => keep.has(file.path));
  const removed = bundle.files.filter((file) => !keep.has(file.path));
  const hash = crypto.createHash('sha256').update(JSON.stringify(files)).digest('hex').slice(0, 12);
  return {
    bundle: {
      ...bundle,
      version: bundle.version.replace(/[0-9a-f]+$/, hash),
      files,
      pages: bundle.pages.filter((page) => keep.has(page.path)),
    },
    removed,
  };
}

/// Lit dans le code Dart les deux listes qui décident où mènent les liens.
export async function readNavigationRules(mobileRoot) {
  const dua = await fs.readFile(path.join(mobileRoot, 'lib/features/duas/dua.dart'), 'utf8');
  const reader = await fs.readFile(path.join(mobileRoot, 'lib/features/reader/reader_screen.dart'), 'utf8');
  const ids = (source, name) => {
    const body = source.match(new RegExp(`${name}\\s*=\\s*\\{([\\s\\S]*?)\\}`))?.[1];
    const found = [...(body ?? '').matchAll(new RegExp(`'(${uuid})(?:\\.html)?'`, 'gi'))].map((m) => m[1].toLowerCase());
    if (!found.length) throw new Error(`Liste ${name} introuvable : élagage refusé.`);
    return new Set(found);
  };
  return {
    updatedDuaIds: ids(dua, '_updatedAamalDuaIds'),
    legacyPageIds: ids(reader, 'legacySommairePageNames'),
  };
}

export async function pruneMobileSite(mobileRoot = 'apps/mobile') {
  const site = path.join(mobileRoot, 'assets/site');
  const bundle = JSON.parse(await fs.readFile(path.join(site, 'bundle.json'), 'utf8'));
  const catalog = JSON.parse(await fs.readFile(path.join(mobileRoot, 'assets/content/catalog.json'), 'utf8'));
  const rules = await readNavigationRules(mobileRoot);
  const texts = new Map();
  for (const file of bundle.files.filter((f) => f.path.endsWith('.html') || f.path.endsWith('.css'))) {
    texts.set(file.path, await fs.readFile(path.join(site, file.path), 'utf8'));
  }
  const plan = planSitePrune({bundle, catalog, read: (p) => texts.get(p), ...rules});
  for (const file of plan.removed) await fs.rm(path.join(site, file.path), {force: true});
  await fs.writeFile(path.join(site, 'bundle.json'), JSON.stringify(plan.bundle, null, 2));
  const bytes = plan.removed.reduce((sum, file) => sum + file.sizeBytes, 0);
  console.log(`${plan.removed.length} fichiers inaccessibles retirés (${(bytes / 1048576).toFixed(1)} Mo), ${plan.bundle.files.length} conservés.`);
  return plan;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await pruneMobileSite();
}
