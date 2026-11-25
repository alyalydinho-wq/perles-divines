import fs from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
import {sha256} from './import-site/content.mjs';
import {buildNativePages} from './native-pages.mjs';
import {pruneMobileSite} from './prune-mobile-site.mjs';

/// Prépare les pages d'origine de l'application à partir de l'import du site.
///
/// L'édition HTML n'est qu'une étape, dans `tmp/mobile-site` : elle est élaguée
/// selon le catalogue embarqué actuel, puis convertie en blocs natifs
/// (`assets/content/pages.json` et `assets/pages/`). Le catalogue n'est pas
/// modifié : on peut relancer ce script après chaque retouche des textes.
export async function prepareMobilePages({mobileRoot = 'apps/mobile', staging = 'tmp/mobile-site'} = {}) {
  const current = JSON.parse(await fs.readFile('content/current-import.json', 'utf8'));
  const inventory = JSON.parse(await fs.readFile('content/source-inventory.json', 'utf8'));
  await fs.rm(staging, {recursive: true, force: true});
  await fs.mkdir(staging, {recursive: true});
  await fs.cp(`${current.directory}/normalized`, staging, {recursive: true});
  const files = [];
  for (const r of inventory.filter((r) => r.localPath)) {
    files.push({path: r.localPath, sha256: r.normalizedSha256, sizeBytes: r.normalizedSizeBytes});
  }
  const unavailable = await fs.readFile(`${staging}/unavailable.html`);
  files.push({path: 'unavailable.html', sha256: sha256(unavailable), sizeBytes: unavailable.length});
  const home = inventory.find((r) => r.url.endsWith('/sommaire.html'));
  await fs.writeFile(`${staging}/bundle.json`, JSON.stringify({
    version: `initial-2026-09-17-${sha256(JSON.stringify(files)).slice(0, 12)}`,
    home: home.localPath,
    files,
    pages: inventory.filter((r) => r.kind === 'html' && r.localPath).map((r) => ({id: r.id, path: r.localPath, url: r.url, title: r.title, anchors: r.anchors})),
  }, null, 2));
  const pruned = await pruneMobileSite(mobileRoot, staging);
  const catalog = JSON.parse(await fs.readFile(`${mobileRoot}/assets/content/catalog.json`, 'utf8'));
  const pages = await buildNativePages({
    siteDir: staging,
    catalog,
    outJson: `${mobileRoot}/assets/content/pages.json`,
    outImages: `${mobileRoot}/assets/pages`,
  });
  return {pruned, pages, texts: catalog.length};
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const {pages, texts} = await prepareMobilePages();
  console.log(`${pages.pages} pages d'origine et ${pages.images} images (${(pages.imageBytes / 1048576).toFixed(1)} Mo) pour ${texts} textes, ${pages.droppedLinks} liens sans destination retirés.`);
}
