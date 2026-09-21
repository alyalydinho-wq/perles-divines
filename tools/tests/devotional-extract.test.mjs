import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import { extractSections, indexButtons } from '../import-site/devotional.mjs';

test('extrait titre, introduction, translittération et traduction sans inventer l’arabe', () => {
  const html = `<body>
    <p>Naad-e-Ali</p>
    <p>En cas de difficulté sérieuse, cet appel est recommandé.</p>
    <img src="arabe.gif">
    <p>TRANSLITTERATION</p>
    <p>NAADE A'LIYYAN</p>
    <p>TRADUCTION</p>
    <p>Faites appel à Ali.</p>
  </body>`;
  const sections = extractSections(html);
  assert.equal(sections.title, 'Naad-e-Ali');
  assert.match(sections.introduction, /difficulté sérieuse/);
  assert.equal(sections.transliteration, "NAADE A'LIYYAN");
  assert.equal(sections.translation, 'Faites appel à Ali.');
  assert.equal(sections.arabic, '');
});

test('conserve l’arabe Unicode déjà présent dans la page', () => {
  const sections = extractSections('<body><p lang="ar">بِسْمِ اللَّهِ</p><p>TRADUCTION</p><p>Au nom de Dieu</p></body>');
  assert.match(sections.arabic, /بِسْمِ اللَّهِ/);
  assert.equal(sections.translation, 'Au nom de Dieu');
});

test('les titres d’index gardent les retours à la ligne comme espaces', () => {
  const buttons = indexButtons(
    '<a class="button white" href="tafsir.html">Tafsir du Qur\'an<br>en ligne</a><a class="button green" href="sommaire.html">Retour au sommaire</a>',
  );
  assert.deepEqual(buttons.map(b => b.title), ["Tafsir du Qur'an en ligne"]);
});

test('le catalogue embarqué reprend les pages importées sans inventer l’arabe', async () => {
  const items = JSON.parse(
    await fs.readFile('apps/mobile/assets/content/catalog.json', 'utf8'),
  );
  assert.equal(items.filter(item => item.kind === 'dua').length, 31);
  assert.equal(items.filter(item => item.kind === 'ziyarat').length, 12);
  const kumail = items.find(item => item.title === 'Doua-e-Kumayl');
  assert.ok(kumail);
  assert.match(kumail.introduction, /Kumayl/);
  assert.match(kumail.translation, /Miséricorde/);
  assert.equal(kumail.arabic, '');
  assert.equal(kumail.sourceUrl, 'https://www.perlesdivines.fr/fr/kumail.html');
});
