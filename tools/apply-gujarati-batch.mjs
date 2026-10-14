// Recopie dans le catalogue le gujarati relu des textes listés dans
// data/gujarati/batch.json. Un titre seul, sans paragraphe, n’est pas écrit :
// l’onglet reste masqué. Deux blocs de corps coupés par un changement de page,
// et qui ne finissent pas par un point, sont recollés.
//
//   node tools/apply-gujarati-batch.mjs

import fs from 'node:fs';

const batch = JSON.parse(fs.readFileSync('data/gujarati/batch.json', 'utf8'));
const catalogPath = 'apps/mobile/assets/content/catalog.json';
const items = JSON.parse(fs.readFileSync(catalogPath, 'utf8'));
const closed = /[.!?।]\s*$/u;

function paragraphs(file) {
  const gu = JSON.parse(fs.readFileSync(file, 'utf8'));
  const blocks = gu.blocks.filter((block) => block.role !== 'title');
  const parts = [];
  for (const block of blocks) {
    const prev = parts.at(-1);
    const prevIsLastOnPage =
      prev &&
      !blocks.some(
        (other) => other.pdf_page === prev.endPage && other.index > prev.endIndex,
      );
    const continues =
      prev &&
      prev.role === 'body' &&
      block.role === 'body' &&
      block.pdf_page === prev.endPage + 1 &&
      prevIsLastOnPage &&
      !closed.test(prev.text);
    if (continues) {
      prev.text = `${prev.text} ${block.text}`;
      prev.endPage = block.pdf_page;
      prev.endIndex = block.index;
      continue;
    }
    parts.push({
      role: block.role,
      endPage: block.pdf_page,
      endIndex: block.index,
      text: block.text,
    });
  }
  return parts;
}

for (const entry of batch) {
  const file = `data/gujarati/${entry.id}.gu.json`;
  if (!fs.existsSync(file)) {
    console.log(`manquant ${entry.catalogTitle}`);
    continue;
  }
  const item = items.find((candidate) => candidate.title === entry.catalogTitle);
  if (!item) throw new Error(`introuvable : ${entry.catalogTitle}`);
  const parts = paragraphs(file);
  if (parts.length === 0) {
    console.log(`sans corps ${entry.catalogTitle}`);
    continue;
  }
  item.gujarati = parts.map((part) => part.text).join('\n\n');
  console.log(
    `${entry.id} ${parts.length} paragraphes, ${item.gujarati.length} caractères`,
  );
}

fs.writeFileSync(catalogPath, `${JSON.stringify(items, null, 2)}\n`);
