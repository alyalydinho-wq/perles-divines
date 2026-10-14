// Revue français / gujarati, un fichier par texte du lot.
// Le français est celui de l’application, réparti dans l’ordre des paragraphes
// gujarati au prorata de leur longueur. C’est un repère de sens, pas un
// alignement vérifié mot à mot.
//
//   node tools/write-gujarati-reviews.mjs

import fs from 'node:fs';

const batch = JSON.parse(fs.readFileSync('data/gujarati/batch.json', 'utf8'));
const items = JSON.parse(
  fs.readFileSync('apps/mobile/assets/content/catalog.json', 'utf8'),
);
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
      prev.pages.push(block.pdf_page);
      prev.endPage = block.pdf_page;
      prev.endIndex = block.index;
      continue;
    }
    parts.push({
      role: block.role,
      pages: [block.pdf_page],
      endPage: block.pdf_page,
      endIndex: block.index,
      text: block.text,
    });
  }
  return { source: gu.source, parts };
}

function frenchSlices(translation, parts) {
  const sentences = (translation || '')
    .split(/(?<=[.!?])\s+/)
    .map((sentence) => sentence.trim())
    .filter(Boolean);
  if (sentences.length === 0 || parts.length === 0) return parts.map(() => '');
  const weights = parts.map((part) => Math.max(part.text.length, 1));
  const total = weights.reduce((sum, weight) => sum + weight, 0);
  const slices = [];
  let cursor = 0;
  parts.forEach((part, index) => {
    const remaining = parts.length - index;
    const take =
      index === parts.length - 1
        ? sentences.length - cursor
        : Math.max(1, Math.round((weights[index] / total) * sentences.length));
    const count = Math.min(Math.max(take, 1), sentences.length - cursor - (remaining - 1));
    const safe = Math.max(count, 0);
    slices.push(sentences.slice(cursor, cursor + safe).join(' '));
    cursor += safe;
  });
  return slices;
}

fs.mkdirSync('docs/gujarati', { recursive: true });
const lines = [
  '# Import gujarati — lot suivant',
  '',
  'Livre « જન્નતની ચાવીઓ », compilation de Maulana Rizwanali Palsaniya.',
  'Page PDF = page imprimée + 1. Le gujarati est une traduction, pas une translittération.',
  'L’arabe, le français et la translittération déjà présents ne sont pas modifiés.',
  '',
  'Sourate Yâ-Sîn : le livre (pages imprimées 6 à 14) ne donne que l’arabe. Aucun gujarati n’a été ajouté.',
  '',
  'Ziyârat Amin Allâh : le titre imprimé est à la page 170, pas 174. La page 174 est la dernière de cette ziyârat.',
  '',
  'Doua du mois de Rajab : le texte de l’application correspond aux pages imprimées 211-212. La page 216 indiquée est la salawât du mois de Sha‘bân, qui n’est pas ce du‘â.',
  '',
];

for (const entry of batch) {
  const file = `data/gujarati/${entry.id}.gu.json`;
  if (!fs.existsSync(file)) continue;
  const { source, parts } = paragraphs(file);
  const item = items.find((candidate) => candidate.title === entry.catalogTitle);
  lines.push(`## ${entry.catalogTitle}`);
  lines.push('');
  lines.push(
    `Pages PDF ${source.pdf_pages[0]}–${source.pdf_pages[1]} (imprimées ${source.pdf_pages[0] - 1}–${source.pdf_pages[1] - 1}).`,
  );
  lines.push(`Paragraphes gujarati retenus : ${parts.length}.`);
  if (entry.note) lines.push(entry.note);
  if (parts.length === 0) {
    lines.push('Pas de traduction gujarati dans ces pages.');
    lines.push('');
    continue;
  }
  const slices = frenchSlices(item?.translation || '', parts);
  const review = [
    `# Revue — ${entry.catalogTitle}`,
    '',
    'À faire relire par un locuteur gujarati avant publication.',
    'Le français est celui de l’application, réparti automatiquement dans l’ordre, au prorata de la longueur. Ce n’est pas un alignement vérifié.',
    `Gujarati du livre « જન્નતની ચાવીઓ », pages PDF ${source.pdf_pages[0]} à ${source.pdf_pages[1]}.`,
    '',
  ];
  parts.forEach((part, index) => {
    const pages = [...new Set(part.pages)].join(', ');
    review.push(`## ${index + 1} — ${part.role}, page PDF ${pages}`);
    review.push('');
    review.push('**Français**');
    review.push('');
    review.push(slices[index] || '_(pas de français en regard)_');
    review.push('');
    review.push('**Gujarati**');
    review.push('');
    review.push(part.text);
    review.push('');
  });
  const reviewPath = `docs/gujarati/${entry.id}-review.md`;
  fs.writeFileSync(reviewPath, `${review.join('\n')}\n`);
  lines.push(`Revue : \`${reviewPath}\`.`);
  lines.push('');
}

fs.writeFileSync('docs/gujarati-batch-report.md', `${lines.join('\n')}\n`);
console.log('écrit docs/gujarati-batch-report.md');
