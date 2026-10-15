import test from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';

const batch = JSON.parse(fs.readFileSync('data/gujarati/batch.json', 'utf8'));
const nudba = JSON.parse(fs.readFileSync('data/gujarati/nudba.gu.json', 'utf8'));
const waressa = JSON.parse(fs.readFileSync('data/gujarati/waressa.gu.json', 'utf8'));

function hash(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function loadBlocks() {
  const owned = [];
  for (const entry of batch) {
    const file = `data/gujarati/${entry.id}.gu.json`;
    if (!fs.existsSync(file)) continue;
    const payload = JSON.parse(fs.readFileSync(file, 'utf8'));
    for (const block of payload.blocks) {
      owned.push({ id: entry.id, page: block.pdf_page, index: block.index });
    }
  }
  return owned;
}

const reviewed = [
  ['129#0', '826275d95098d27d9148b6aabfbe10c43afccbf84e6f93912feb76e05e62a917'],
  ['129#1', 'a2ab4d7a6a6a2ed0324bc5484b52d967808447ce827c255295a2f04d07c06e08'],
  ['129#2', '09858cbd0580d2c625915a5a30da3cbd45b99a5ece96baf8dfd2e2f9c63565d0'],
  ['129#3', '947aad603fee8e24e2610f5536094b55a1310028e31c4ed6e0ac372accdd10c3'],
  ['130#0', 'cf0d99772ef4e40ecc9fa4b265997a9ea3a40f0f25c2712e1b12b3c5a8f88f80'],
  ['130#1', 'f3916ccc858d2ca0aa02b5a4d446ff74def94f7a68ca585669dbf15c53d793d2'],
  ['131#0', '964d60a76456c94425eab5dabde5730aaac4e99b0d1c26b788e1617dfacd60fd'],
  ['132#0', '23bfbb53e159e64e5bcdc236465d5621927bdc84219e72950fce6c6aede0d5c0'],
  ['133#0', '845afc66746d0c6774999a8e005ce013f13ad54e2a63ea4168b6b34e75725564'],
  ['134#0', '5c951204a43542312493b47ec5ad330fabfc66b9d6864b2aafd1c5c83d64d4ed'],
];

test('aucun bloc (page, index) n’appartient à deux lots', () => {
  const seen = new Map();
  for (const block of loadBlocks()) {
    const key = `${block.page}#${block.index}`;
    const previous = seen.get(key);
    assert.equal(
      previous,
      undefined,
      `${key} est dans ${previous} et ${block.id}`,
    );
    seen.set(key, block.id);
  }
});

test('Nudba couvre chaque page jusqu’à Wâressa, sauf l’arabe seul', () => {
  const entry = batch.find((item) => item.id === 'nudba');
  const next = batch.find((item) => item.id === 'waressa');
  assert.equal(entry.from, 129);
  assert.equal(entry.to, 154);
  assert.equal(next.from, 154);
  const pages = new Set(nudba.blocks.map((block) => block.pdf_page));
  const justified = new Map([
    [144, 'Page PDF 144 : arabe seul, aucun gujarati imprimé.'],
  ]);
  for (let page = entry.from; page < next.from; page += 1) {
    assert.ok(
      pages.has(page) || justified.has(page),
      `page PDF ${page} orpheline`,
    );
  }
  assert.ok(pages.has(154));
  assert.equal(
    nudba.blocks.some((block) => block.text.includes('ઝિયારતે વારેસા')),
    false,
  );
  assert.equal(waressa.blocks[0].pdf_page, 154);
  assert.equal(waressa.blocks[0].index, 1);
  assert.equal(waressa.blocks[0].text, 'ઝિયારતે વારેસા');
});

test('les dix blocs déjà relus de Nudba sont inchangés', () => {
  assert.deepEqual(
    nudba.blocks.slice(0, 10).map((block) => [
      `${block.pdf_page}#${block.index}`,
      hash(block.text),
    ]),
    reviewed,
  );
});

test('le gujarati des lots est en NFC', () => {
  for (const entry of batch) {
    const file = `data/gujarati/${entry.id}.gu.json`;
    if (!fs.existsSync(file)) continue;
    const payload = JSON.parse(fs.readFileSync(file, 'utf8'));
    for (const block of payload.blocks) {
      assert.equal(block.text, block.text.normalize('NFC'), `${entry.id} p${block.pdf_page}`);
    }
  }
});
