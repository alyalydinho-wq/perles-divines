import assert from 'node:assert/strict';
import test from 'node:test';
import {convertPage, imageSize, isLegacySommaireUrl, pageTitle} from '../native-pages.mjs';

const images = {'a.gif': {name: 'a.gif', width: 480, height: 240}, 'n.png': {name: 'n.png', width: 92, height: 48}};
const convert = (body, links = {}) => convertPage(`<html><body>${body}</body></html>`, {
  resolveLink: (href) => links[href],
  imageOf: (src) => images[src.split('/').pop()],
}).blocks;

test('un paragraphe garde ses styles, ses retours à la ligne et son alignement', () => {
  const blocks = convert('<p align="justify"><span class="vert tg"><b>Niyat :<br>Sounnat</b></span> puis <font color="#800000">rouge</font></p>');
  assert.deepEqual(blocks, [{
    p: [
      {t: 'Niyat :\nSounnat', b: 1, c: '#145014', s: 16},
      {t: ' puis '},
      {t: 'rouge', c: '#800000'},
    ],
    a: 'j',
  }]);
});

test('le texte est centré par défaut, comme le site', () => {
  assert.deepEqual(convert('<p>Titre</p>'), [{p: [{t: 'Titre'}]}]);
});

test('le bandeau du site disparaît, les images gardent leur taille', () => {
  const blocks = convert('<center><a href="x"><img class="logo cadre" src="../assets/n.png"></a></center><p align="justify"><img src="../assets/a.gif" width="100%"></p>');
  assert.deepEqual(blocks, [{img: 'a.gif', iw: 480, ih: 240, f: 1, a: 'j'}]);
});

test('un lien sans destination n’est plus un lien, sa flèche disparaît', () => {
  const blocks = convert('<p><a href="nulle-part.html">texte</a> et <a href="ok.html">lien</a></p><a href="nulle-part.html"><img src="../assets/n.png"></a>', {'ok.html': 'page:x'});
  assert.deepEqual(blocks, [{p: [{t: 'texte et '}, {t: 'lien', u: 1, c: '#124e12', s: 14, h: 'page:x'}]}]);
});

test('boutons, ancres, filets et tableaux de mise en page', () => {
  const blocks = convert(
    '<a class="button green" href="s.html">Retour au sommaire</a>'
    + '<a class="button white" href="absent.html">Sans destination</a>'
    + '<div class="pd-table"><table><tbody><tr><td><a href="#T"><img src="../assets/n.png"></a></td><td><p align="right">droite</p></td></tr></tbody></table></div>'
    + '<hr><p><b><a name="T">TRADUCTION</a></b></p>',
    {'s.html': 'sommaire', '#T': '#T'},
  );
  assert.deepEqual(blocks, [
    {button: 'Retour au sommaire', green: 1, h: 'sommaire'},
    {row: [[{img: 'n.png', iw: 92, ih: 48, h: '#T'}], [{p: [{t: 'droite'}], a: 'r'}]]},
    {hr: 1},
    {p: [{t: 'TRADUCTION', b: 1}], k: ['T']},
  ]);
});

test('les sauts de ligne entre deux blocs deviennent un espace', () => {
  const blocks = convert('<p>Un</p><br><br><p>Deux</p>');
  assert.deepEqual(blocks, [{p: [{t: 'Un'}]}, {gap: 2}, {p: [{t: 'Deux'}]}]);
});

test('l’arabe en texte se lit de droite à gauche', () => {
  const blocks = convert('<div class="ar" dir="rtl">اللهُ أَکبَر</div>');
  assert.deepEqual(blocks, [{p: [{t: 'اللهُ أَکبَر'}], d: 'rtl', ar: 1}]);
});

test('le titre est le premier paragraphe', () => {
  assert.equal(pageTitle(convert('<img src="../assets/a.gif"><p>Namaz-e-Shab<br>(Tahajjoud)</p>')), 'Namaz-e-Shab (Tahajjoud)');
});

test('la taille des images se lit dans leur en-tête', () => {
  const gif = Buffer.from('GIF89a\x10\x00\x08\x00', 'latin1');
  assert.deepEqual(imageSize(gif), {width: 16, height: 8});
  const png = Buffer.alloc(24);
  png.writeUInt32BE(0x89504e47, 0);
  png.writeUInt32BE(92, 16);
  png.writeUInt32BE(48, 20);
  assert.deepEqual(imageSize(png), {width: 92, height: 48});
  assert.throws(() => imageSize(Buffer.from('nope')), /inconnu/);
});

test('isLegacySommaireUrl reconnaît sommaire et accueil du site, pas les autres pages', () => {
  for (const url of [
    'https://www.perlesdivines.fr/sommaire.html',
    'https://www.perlesdivines.fr/sommaire.html#liste',
    'https://perlesdivines.fr/index.html?ref=1',
    'http://www.perlesdivines.fr/',
    'https://perlesdivines.fr',
    'https://www.perlesdivines.fr/fr/',
    'https://WWW.perlesdivines.fr/fr/index.html',
    'https://www.perlesdivines.fr/fr/sommaire.html',
  ]) assert.ok(isLegacySommaireUrl(url), url);
  for (const url of [
    'https://www.perlesdivines.fr/fr/aamal_safar.html',
    'https://example.com/sommaire.html',
    'mailto:contact@perlesdivines.fr',
    'sommaire.html',
  ]) assert.ok(!isLegacySommaireUrl(url), url);
});
