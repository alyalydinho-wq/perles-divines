// Recopie le gujarati relu de Ziyârat Âchourâ dans le catalogue mobile.
// Deux blocs coupés par un changement de page, et qui ne finissent pas par
// un point, sont recollés. Le reste reste un paragraphe par bloc du PDF.
//
//   node tools/apply-gujarati-ashura.mjs

import fs from 'node:fs';

const gu = JSON.parse(fs.readFileSync('data/gujarati/ashura.gu.json', 'utf8'));
const blocks = gu.blocks.filter((block) => block.role !== 'title');
const closed = /[.!?।]\s*$/u;
const parts = [];

for (let i = 0; i < blocks.length; i += 1) {
  const block = blocks[i];
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

const catalogPath = 'apps/mobile/assets/content/catalog.json';
const items = JSON.parse(fs.readFileSync(catalogPath, 'utf8'));
const item = items.find((entry) => entry.title === 'Zyaarat-e-Âchourâ');
if (!item) throw new Error('Zyaarat-e-Âchourâ introuvable');
item.gujarati = parts.map((part) => part.text).join('\n\n');
fs.writeFileSync(catalogPath, `${JSON.stringify(items, null, 2)}\n`);

console.log(`${parts.length} paragraphes, ${item.gujarati.length} caractères`);
for (const part of parts) {
  console.log(
    `${part.role} p${part.endPage} | ${part.text.slice(0, 28)} … ${part.text.slice(-18)}`,
  );
}
