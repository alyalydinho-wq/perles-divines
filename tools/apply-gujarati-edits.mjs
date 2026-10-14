// Applique data/gujarati/shared-edits.json au champ text des extraits.
// ocr reste la sortie Tesseract. N’efface pas les corrections déjà faites.

import fs from 'node:fs';

const edits = JSON.parse(fs.readFileSync('data/gujarati/shared-edits.json', 'utf8'));
const files = fs
  .readdirSync('data/gujarati')
  .filter((name) => name.endsWith('.gu.json') && name !== 'ashura.gu.json');

for (const name of files) {
  const path = `data/gujarati/${name}`;
  const payload = JSON.parse(fs.readFileSync(path, 'utf8'));
  let hits = 0;
  for (const block of payload.blocks) {
    for (const edit of edits) {
      if (!block.text.includes(edit.from)) continue;
      block.text = block.text.replaceAll(edit.from, edit.to);
      hits += 1;
    }
  }
  if (name === 'abu-hamza.gu.json') {
    const before = payload.blocks.length;
    payload.blocks = payload.blocks.filter(
      (block) => !(block.pdf_page === 359 && block.index >= 1),
    );
    payload.source.excluded =
      'Page PDF 359 : l’encadré de hadiths (après le dernier paragraphe du du‘â) n’appartient pas au texte. Il n’est pas repris.';
    console.log(
      `${name} encadré retiré : ${before - payload.blocks.length} blocs`,
    );
  }
  fs.writeFileSync(path, `${JSON.stringify(payload, null, 2)}\n`);
  console.log(`${name} ${hits} remplacements`);
}
