// Repère les titres gujarati du PDF (grande police), sans OCR.
// Le texte brut a les matras cassées : il sert seulement à situer les sections.
//
//   node tools/scan-gujarati-headings.mjs --pdf "<chemin.pdf>" --out data/gujarati/headings.json

import fs from 'node:fs';
import * as mupdf from 'mupdf';

function arg(name, fallback) {
  const index = process.argv.indexOf(name);
  if (index === -1) return fallback;
  return process.argv[index + 1];
}

const pdfPath = arg('--pdf');
const outPath = arg('--out', 'data/gujarati/headings.json');
const doc = mupdf.Document.openDocument(fs.readFileSync(pdfPath), 'application/pdf');
const headings = [];

for (let pageNo = 1; pageNo <= doc.countPages(); pageNo += 1) {
  const page = doc.loadPage(pageNo - 1);
  const json = JSON.parse(page.toStructuredText('preserve-whitespace').asJSON());
  for (const block of json.blocks || []) {
    for (const line of block.lines || []) {
      const text = (line.text || '').replace(/\s+/g, ' ').trim();
      const size = line.font?.size || 0;
      if (size < 18) continue;
      if (!/[\u0A80-\u0AFF]/.test(text)) continue;
      headings.push({
        pdf_page: pageNo,
        printed_page: pageNo - 1,
        size: Number(size.toFixed(1)),
        text,
      });
    }
  }
}

fs.mkdirSync('data/gujarati', { recursive: true });
fs.writeFileSync(outPath, `${JSON.stringify(headings, null, 2)}\n`);
console.log(`${headings.length} titres → ${outPath}`);
for (const heading of headings) {
  console.log(`p${heading.pdf_page} (impr. ${heading.printed_page}) ${heading.size} ${heading.text}`);
}
