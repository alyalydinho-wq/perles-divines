import fs from 'node:fs/promises';
import path from 'node:path';
import { extractSections, indexButtons } from './import-site/devotional.mjs';
import { applyAudioAssociations } from './audio-match.mjs';

const INDEXES = [
  { url: 'https://www.perlesdivines.fr/doua.html', kind: 'dua' },
  { url: 'https://www.perlesdivines.fr/zyaraate.html', kind: 'ziyarat' },
  { url: 'https://www.perlesdivines.fr/quran.html', kind: 'quran' },
  { url: 'https://www.perlesdivines.fr/namaz.html', kind: 'namaz' },
  { url: 'https://www.perlesdivines.fr/specifique.html', kind: 'aamal' },
  { url: 'https://www.perlesdivines.fr/aamal.html', kind: 'aamal' },
];

function pageFile(href, fromPath) {
  if (!href || href.includes('unavailable.html') || href.startsWith('../assets/')) return null;
  const name = path.posix.basename(href);
  if (!name.endsWith('.html')) return null;
  return path.posix.join(path.posix.dirname(fromPath), name);
}

export async function extractCatalog({
  importDirectory,
  inventory,
} = {}) {
  const current = JSON.parse(await fs.readFile('content/current-import.json', 'utf8'));
  const root = importDirectory ?? current.directory;
  const records = inventory ?? JSON.parse(await fs.readFile('content/source-inventory.json', 'utf8'));
  const pages = records.filter(record => record.kind === 'html' && record.localPath && record.status === 200);
  const byUrl = new Map(pages.map(record => [record.url, record]));
  const byPath = new Map(pages.map(record => [record.localPath.replaceAll('\\', '/'), record]));
  const items = [];
  const seen = new Set();

  for (const index of INDEXES) {
    const record = byUrl.get(index.url);
    if (!record) throw new Error(`Index introuvable : ${index.url}`);
    const html = await fs.readFile(path.join(root, 'normalized', record.localPath), 'utf8');
    for (const button of indexButtons(html)) {
      const localPath = pageFile(button.href, record.localPath.replaceAll('\\', '/'));
      const target = localPath ? byPath.get(localPath) : null;
      if (!target || seen.has(target.id)) continue;
      seen.add(target.id);
      const page = await fs.readFile(path.join(root, 'normalized', target.localPath), 'utf8');
      const sections = extractSections(page);
      const title = button.title || sections.title;
      const references = sections.info ? [sections.info] : [];
      items.push({
        id: target.id,
        kind: index.kind,
        title,
        arabic: sections.arabic,
        translation: sections.translation,
        transliteration: sections.transliteration,
        introduction: sections.introduction,
        references,
        audioIds: [],
        sourceUrl: target.url,
        pagePath: target.localPath.replaceAll('\\', '/'),
      });
    }
  }
  await applyAudioAssociations(items, 'content/audio-associations.json');
  return items;
}

const running = process.argv[1] && path.basename(process.argv[1]) === 'extract-devotional-catalog.mjs';
if (running) {
  const items = await extractCatalog();
  const destination = 'apps/mobile/assets/content/catalog.json';
  await fs.mkdir(path.dirname(destination), { recursive: true });
  await fs.writeFile(destination, `${JSON.stringify(items, null, 2)}\n`);
  const counts = Object.fromEntries(
    ['dua', 'ziyarat', 'quran', 'namaz', 'aamal'].map(kind => [
      kind,
      items.filter(item => item.kind === kind).length,
    ]),
  );
  console.log(`${items.length} textes extraits`, counts);
}
