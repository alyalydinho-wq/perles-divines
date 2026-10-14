// Signale les mots OCR dont les consonnes ne se retrouvent pas dans le texte
// brut, une fois retirés દ et ખ (souvent la matra િ mal encodée). Ce n’est pas
// une correction : la liste sert à relire les images.
//
//   node tools/check-gujarati-ocr.mjs

import fs from 'node:fs';

const files = fs
  .readdirSync('data/gujarati')
  .filter((name) => name.endsWith('.gu.json'));

function skeleton(value) {
  return [...value.normalize('NFC')]
    .filter((char) => {
      const code = char.codePointAt(0);
      if (code < 0x0a85 || code > 0x0ab9) return false;
      return char !== 'દ' && char !== 'ખ';
    })
    .join('');
}

const counts = new Map();
for (const name of files) {
  const payload = JSON.parse(fs.readFileSync(`data/gujarati/${name}`, 'utf8'));
  for (const block of payload.blocks) {
    const rawSkel = skeleton(block.raw || '');
    const words = (block.text || '').split(/\s+/);
    for (const word of words) {
      const bare = word.replace(/[^\u0A80-\u0AFF]/g, '');
      if (bare.length < 2) continue;
      const skel = skeleton(bare);
      if (!skel || rawSkel.includes(skel)) continue;
      const key = `${bare}`;
      const entry = counts.get(key) || { word: bare, n: 0, files: new Set() };
      entry.n += 1;
      entry.files.add(name.replace('.gu.json', ''));
      counts.set(key, entry);
    }
  }
}

const ranked = [...counts.values()].sort((a, b) => b.n - a.n);
console.log(`${ranked.length} formes absentes du squelette brut`);
for (const entry of ranked.slice(0, 80)) {
  console.log(
    `${String(entry.n).padStart(3)} ${entry.word}  ${[...entry.files].join(',')}`,
  );
}
