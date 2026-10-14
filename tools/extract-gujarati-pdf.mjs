// Extrait le gujarati imprimé d'un PDF dont l'encodage des polices est faux.
//
// Le texte brut (ToUnicode) est du gujarati Unicode, mais les matras sont
// cassées : િ devient « દ » ou « ખ » et passe devant la consonne, ુ / ૂ
// disparaissent, ં devient « ું ». On ne s'en sert donc que pour localiser
// les lignes. Le texte retenu vient de l'OCR Tesseract (guj, tessdata_best)
// sur le rendu 300 dpi de chaque bloc.
//
// Usage :
//   node tools/extract-gujarati-pdf.mjs --pdf "<chemin.pdf>" --from 161 --to 170 --out data/gujarati/ashura.gu.json --edits data/gujarati/ashura.edits.json
//   node tools/extract-gujarati-pdf.mjs --pdf "<chemin.pdf>" --batch data/gujarati/batch.json --resume true
//   node tools/apply-gujarati-ashura.mjs
//
// Les corrections visuelles de data/gujarati/ashura.edits.json sont appliquées
// au champ text. ocr conserve la sortie Tesseract.
//
// Dépendances (dev) : mupdf, tesseract.js, pngjs.
// Le modèle tessdata_best/guj.traineddata est téléchargé au premier lancement
// dans tmp/tessdata (non versionné).

import fs from 'node:fs';
import path from 'node:path';
import { PNG } from 'pngjs';
import * as mupdf from 'mupdf';
import { createWorker, PSM } from 'tesseract.js';

const DPI = 300;
const BASELINE_GAP = 26;
const LANG_PATH = 'https://github.com/tesseract-ocr/tessdata_best/raw/main';

function arg(name, fallback) {
  const index = process.argv.indexOf(name);
  if (index === -1) return fallback;
  const value = process.argv[index + 1];
  if (!value || value.startsWith('--')) {
    throw new Error(`option ${name} : valeur manquante`);
  }
  return value;
}

function scriptOf(text) {
  const gujarati = /[\u0A80-\u0AFF]/.test(text);
  const arabic = /[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]/.test(text);
  if (gujarati && arabic) return 'mix';
  if (gujarati) return 'guj';
  if (arabic) return 'ar';
  return 'other';
}

function gujaratiLines(page) {
  const json = JSON.parse(page.toStructuredText('preserve-whitespace').asJSON());
  const lines = [];
  for (const block of json.blocks || []) {
    for (const line of block.lines || []) {
      const text = (line.text || '').replace(/\s+/g, ' ').trim();
      if (!text || scriptOf(text) !== 'guj') continue;
      lines.push({
        x: line.bbox.x,
        y: line.bbox.y,
        w: line.bbox.w,
        h: line.bbox.h,
        size: line.font?.size || 0,
        text,
      });
    }
  }
  lines.sort((a, b) => a.y - b.y || a.x - b.x);
  return lines;
}

function groupLines(lines) {
  const groups = [];
  for (const line of lines) {
    const current = groups.at(-1);
    const sameSize = current && Math.abs(line.size - current.size) < 2;
    const close = current && line.y - current.lastY <= BASELINE_GAP;
    if (current && sameSize && close) {
      current.lines.push(line);
      current.lastY = line.y;
      current.x0 = Math.min(current.x0, line.x);
      current.y0 = Math.min(current.y0, line.y);
      current.x1 = Math.max(current.x1, line.x + line.w);
      current.y1 = Math.max(current.y1, line.y + line.h);
    } else {
      groups.push({
        lines: [line],
        size: line.size,
        lastY: line.y,
        x0: line.x,
        y0: line.y,
        x1: line.x + line.w,
        y1: line.y + line.h,
      });
    }
  }
  return groups;
}

function roleOf(group) {
  if (group.size >= 18) return 'title';
  const raw = group.lines.map((line) => line.text).join(' ');
  const short = group.x1 - group.x0 < 220 && group.lines.length === 1;
  if (short && /પઢે|વખત|સજદા/.test(raw)) return 'instruction';
  return 'body';
}

function cropPng(pagePng, box, scale) {
  const pad = 8;
  const left = Math.max(0, Math.floor(box.x0 * scale) - pad);
  const top = Math.max(0, Math.floor(box.y0 * scale) - pad);
  const right = Math.min(pagePng.width, Math.ceil(box.x1 * scale) + pad);
  const bottom = Math.min(pagePng.height, Math.ceil(box.y1 * scale) + pad);
  const width = Math.max(1, right - left);
  const height = Math.max(1, bottom - top);
  const cropped = new PNG({ width, height });
  PNG.bitblt(pagePng, cropped, left, top, width, height, 0, 0);
  const margin = 24;
  const framed = new PNG({ width: width + margin * 2, height: height + margin * 2 });
  for (let i = 0; i < framed.data.length; i += 4) {
    framed.data[i] = 255;
    framed.data[i + 1] = 255;
    framed.data[i + 2] = 255;
    framed.data[i + 3] = 255;
  }
  PNG.bitblt(cropped, framed, 0, 0, width, height, margin, margin);
  return PNG.sync.write(framed);
}

function tidy(value) {
  return value
    .normalize('NFC')
    .replace(/\r/g, '')
    .split('\n')
    .map((line) => line.replace(/[ \t]+/g, ' ').trim())
    .filter((line) => line.length > 0)
    .join(' ')
    .replace(/[ \t]+/g, ' ')
    .trim();
}

const pdfPath = arg('--pdf');
const from = Number(arg('--from', '161'));
const to = Number(arg('--to', '170'));
const outPath = arg('--out', 'data/gujarati/ashura.gu.json');
const cropsDir = arg('--crops', 'tmp/gujarati-crops');
const editsPath = arg('--edits', '');
const batchPath = arg('--batch', '');
const sectionName = arg('--section', 'ઝિયારતે આશૂરા');

if (!pdfPath || !fs.existsSync(pdfPath)) {
  throw new Error(`PDF introuvable : ${pdfPath || '(--pdf manquant)'}`);
}

fs.mkdirSync('tmp/tessdata', { recursive: true });

const doc = mupdf.Document.openDocument(fs.readFileSync(pdfPath), 'application/pdf');
const scale = DPI / 72;

function collectJobs(range) {
  const dir = range.cropsDir;
  fs.mkdirSync(dir, { recursive: true });
  const jobs = [];
  let started = false;
  let seenBody = false;
  let stopped = false;
  for (let pageNo = range.from; pageNo <= range.to && !stopped; pageNo += 1) {
    const page = doc.loadPage(pageNo - 1);
    const groups = groupLines(gujaratiLines(page));
    const pixmap = page.toPixmap(
      mupdf.Matrix.scale(scale, scale),
      mupdf.ColorSpace.DeviceRGB,
      false,
    );
    const pagePng = PNG.sync.read(Buffer.from(pixmap.asPNG()));
    let kept = 0;
    for (let index = 0; index < groups.length; index += 1) {
      const group = groups[index];
      const role = roleOf(group);
      if (!started) {
        if (role !== 'title') continue;
        started = true;
      } else if (role === 'title' && seenBody && range.stopAtNextTitle) {
        stopped = true;
        break;
      }
      if (role === 'body' || role === 'instruction') seenBody = true;
      const image = cropPng(pagePng, group, scale);
      const file = path.join(
        dir,
        `p${pageNo}-${String(index).padStart(2, '0')}.png`,
      );
      fs.writeFileSync(file, image);
      jobs.push({
        pdf_page: pageNo,
        index,
        role,
        raw: tidy(group.lines.map((line) => line.text).join('\n')),
        bbox: [
          Number(group.x0.toFixed(1)),
          Number(group.y0.toFixed(1)),
          Number((group.x1 - group.x0).toFixed(1)),
          Number((group.y1 - group.y0).toFixed(1)),
        ],
        file,
      });
      kept += 1;
    }
    console.error(`page ${pageNo} : ${kept} blocs`);
  }
  return jobs;
}

const worker = await createWorker('guj', 1, {
  langPath: LANG_PATH,
  cachePath: path.resolve('tmp/tessdata'),
  gzip: false,
});
await worker.setParameters({
  tessedit_pageseg_mode: PSM.SINGLE_BLOCK,
  preserve_interword_spaces: '1',
  user_defined_dpi: String(DPI),
});

function applyEdits(blocks, file) {
  if (!file || !fs.existsSync(file)) return;
  const edits = JSON.parse(fs.readFileSync(file, 'utf8'));
  for (const block of blocks) {
    for (const edit of edits) {
      if (block.text.includes(edit.from)) {
        block.text = block.text.replaceAll(edit.from, edit.to);
      }
    }
  }
}

async function recognize(jobs, range) {
  console.error(`OCR de ${jobs.length} blocs (${range.section})…`);
  const blocks = [];
  for (const job of jobs) {
    const result = await worker.recognize(job.file);
    const text = tidy(result.data.text || '');
    blocks.push({
      pdf_page: job.pdf_page,
      index: job.index,
      role: job.role,
      text,
      ocr: text,
      raw: job.raw,
      bbox: job.bbox,
    });
    console.error(`  p${job.pdf_page}#${job.index} ${job.role} ${text.slice(0, 72)}`);
  }
  applyEdits(blocks, range.edits);
  fs.mkdirSync(path.dirname(range.out), { recursive: true });
  const payload = {
    source: {
      book: 'જન્નતની ચાવીઓ',
      compiler: 'Maulana Rizwanali Palsaniya',
      section: range.section,
      catalogTitle: range.catalogTitle || '',
      pdf_pages: [range.from, range.to],
      page_rule: 'numéro de page PDF = numéro imprimé + 1',
    },
    method:
      'Rendu MuPDF 300 dpi, blocs isolés par le script gujarati (pas par le texte brut), OCR Tesseract LSTM -l guj avec tessdata_best. Le champ raw est l’extraction Unicode fautive, conservée pour contrôle ; ocr est la sortie Tesseract ; text est ocr après les corrections visuelles.',
    blocks,
  };
  fs.writeFileSync(range.out, `${JSON.stringify(payload, null, 2)}\n`);
  console.error(`écrit ${range.out} (${blocks.length} blocs)`);
}

const ranges = batchPath
  ? JSON.parse(fs.readFileSync(batchPath, 'utf8')).map((item) => ({
      ...item,
      out: item.out || `data/gujarati/${item.id}.gu.json`,
      cropsDir: item.cropsDir || `tmp/gujarati-crops/${item.id}`,
      edits: item.edits || editsPath,
      stopAtNextTitle: item.stopAtNextTitle !== false,
    }))
  : [
      {
        section: sectionName,
        catalogTitle: arg('--catalog', ''),
        from,
        to,
        out: outPath,
        cropsDir,
        edits: editsPath,
        stopAtNextTitle: arg('--stop-at-next-title', 'false') === 'true',
      },
    ];

for (const range of ranges) {
  if (fs.existsSync(range.out) && arg('--resume', 'false') === 'true') {
    console.error(`déjà fait : ${range.out}`);
    continue;
  }
  const jobs = collectJobs(range);
  await recognize(jobs, range);
}
await worker.terminate();
