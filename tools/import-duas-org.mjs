// Remplace l'arabe (Unicode, rendu IndoPak par la police embarquée) et la
// translittération des textes du catalogue mobile par ceux de duas.org.
// La traduction française n'est jamais modifiée.
//
//   node tools/import-duas-org.mjs            # aperçu, n'écrit rien
//   node tools/import-duas-org.mjs --write    # écrit apps/mobile/assets/content/catalog.json
//   node tools/import-duas-org.mjs --quran    # sourates seulement (combinable avec --write)
//
// Trois formats de source sont gérés : le JSON du site actuel (data_v2/<id>.json),
// les anciennes pages HTML (<page>.htm) avec les blocs .Ara / .Trl, et les
// sourates de quran.duas.org (voir import-quran-duas-org.mjs).
import fs from 'node:fs/promises';
import {QURAN_MAPPING, fetchCached, loadQuran} from './import-quran-duas-org.mjs';

const CATALOG = 'apps/mobile/assets/content/catalog.json';

// Titre exact dans le catalogue -> source duas.org.
// v2: identifiant de data_v2/<id>.json. legacy: nom de page .htm.
// quran: numéro de sourate (+ verse pour un verset seul), cf. QURAN_MAPPING.
export const MAPPING = [
  {title: 'Naad-e-Ali', v2: 'naad-e-ali'},
  {title: 'Hadith-e-Kissa', v2: 'hadis-e-kisa'},
  {title: 'Doua-e-Kumayl', v2: 'dua-kumayl'},
  {title: 'Doua-e-Tawassoul', v2: 'dua-tawassul'},
  {title: 'Doua-e-Abou-Hamza-Thamali', v2: 'ramadan-dua-abu-hamza-thumali'},
  {title: 'Doua-e-Ahad', v2: 'dua-ahad'},
  {title: 'Doua-e-Alqamah', v2: 'dua-alqama-after-ziyarat-ashura-imam-husain'},
  {title: 'Doua-e-Baha', v2: 'ramadan-sahar-dua-baha'},
  {title: "Doua-e-Faraj (Eelaahi A'Zomal Balaaa-o)", v2: 'dua-faraj-dua-azumal-bala-imam-mahdi'},
  {title: 'Doua-e-Iftetah', v2: 'ramadan-dua-iftitah'},
  {title: 'Doua-e-Jawshan-e-Kabir', v2: 'dua-jawshan-kabeer'},
  {title: 'Doua-e-Mashlool', legacy: 'mashlool.htm'},
  {title: 'Doua-e-Mujir', v2: 'dua-mujeer'},
  {title: 'Doua-e-Nudba', v2: 'dua-nudbah'},
  {title: 'Doua-e-Wahda', v2: 'dua-wahda-for-unity'},
  {title: 'Doua du mois de Safar', v2: 'month-of-safar-daily-dua'},
  // La page duas.org regroupe plusieurs douas ; seule « Allahumma adkhil » correspond.
  {title: 'Doua après chaque prière obligatoire du mois béni de Ramadhaan', v2: 'ramadan-dua-after-every-salaat', dua: 'dua-2'},
  {title: "Doua du jour de 'Arafah", v2: 'dua-arafah-imam-husain'},
  {title: 'Zyaarat-e-Wâressa', v2: 'ziyarat-imam-hussain-waritha'},
  {title: "Zyaarat-e-Arbae'en", legacy: 'arbaeen.htm'},
  {title: 'Zyaarat-e-Amin-Allàh', v2: 'ziyarat-ameenallah'},
  {title: "Zyaarat du Vendredi (Jum'a) Imam al Mahdi (aj)", v2: 'ziyarat-imam-mahdi-friday'},
  ...QURAN_MAPPING,
];

const ARABIC = /[\u0600-\u06FF]/;

function decode(text) {
  return text
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&#39;|&apos;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/\s+/g, ' ')
    .trim();
}

// Segments : {arabic, transliteration} ou {break: true} entre deux sections.
function parseV2(json, only) {
  const data = JSON.parse(json);
  const duas = (data.duas || []).filter(
    (d) => d.type === 'dua' && Array.isArray(d.segments) && (!only || d.id === only),
  );
  const segments = [];
  for (const dua of duas) {
    if (segments.length) segments.push({break: true});
    for (const segment of dua.segments) {
      if (segment.type === 'instruction') {
        segments.push({break: true});
        continue;
      }
      const arabic = (segment.arabic || '').trim();
      if (!arabic) continue;
      segments.push({arabic, transliteration: (segment.transliteration || '').trim()});
    }
  }
  return {title: data.title, segments, sourceTitle: data.title};
}

function parseLegacy(html) {
  const body = html.replace(/<script[\s\S]*?<\/script>/g, '').replace(/<style[\s\S]*?<\/style>/g, '');
  const title = decode((body.match(/<title>([\s\S]*?)<\/title>/) || ['', ''])[1]);
  const segments = [];
  const pattern = /<div class="Ara">([\s\S]*?)<\/div>(?:\s*<div class="Trl">([\s\S]*?)<\/div>)?/g;
  let match;
  let last = 0;
  while ((match = pattern.exec(body))) {
    // Texte libre entre deux blocs = changement de section.
    const between = decode(body.slice(last, match.index).replace(/<\/?t1>|<div class="Tra">[\s\S]*?<\/div>/g, ''));
    if (segments.length && between.replace(/[^a-z]/gi, '').length > 40) segments.push({break: true});
    last = pattern.lastIndex;
    const arabic = decode(match[1]);
    if (!ARABIC.test(arabic)) continue;
    segments.push({arabic, transliteration: decode(match[2] || '')});
  }
  return {title, segments, sourceTitle: title};
}

function join(segments, field) {
  const sections = [[]];
  for (const segment of segments) {
    if (segment.break) {
      if (sections.at(-1).length) sections.push([]);
      continue;
    }
    if (segment[field]) sections.at(-1).push(segment[field]);
  }
  return sections.filter((s) => s.length).map((s) => s.join('\n')).join('\n\n');
}

function sourceLabel(entry) {
  if (entry.quran) return entry.verse ? `quran ${entry.quran}:${entry.verse}` : `quran ${entry.quran}`;
  return entry.v2 || entry.legacy;
}

export async function loadSource(entry) {
  if (entry.quran) return loadQuran(entry);
  if (entry.v2) {
    const json = await fetchCached(`https://www.duas.org/data_v2/${entry.v2}.json`, `${entry.v2}.json`);
    return parseV2(json, entry.dua);
  }
  const html = await fetchCached(`https://www.duas.org/${entry.legacy}`, entry.legacy);
  return parseLegacy(html);
}

const write = process.argv.includes('--write');
// --quran : ne traiter que les sourates (les douas déjà importées restent intactes).
const entries = process.argv.includes('--quran') ? MAPPING.filter((e) => e.quran) : MAPPING;
const catalog = JSON.parse(await fs.readFile(CATALOG, 'utf8'));
let changed = 0;
for (const entry of entries) {
  const item = catalog.find((x) => x.title === entry.title);
  if (!item) {
    console.log(`!! introuvable dans le catalogue : ${entry.title}`);
    continue;
  }
  let source;
  try {
    source = await loadSource(entry);
  } catch (error) {
    console.log(`!! ${entry.title} : ${error.message}`);
    continue;
  }
  const arabic = join(source.segments, 'arabic');
  const transliteration = join(source.segments, 'transliteration');
  const count = source.segments.filter((s) => s.arabic).length;
  console.log(`\n== ${entry.title}`);
  console.log(`   source : ${source.sourceTitle} (${sourceLabel(entry)}) — ${source.verses ?? count} versets`);
  console.log(`   app    : ${(item.transliteration || '').split('\n')[0].slice(0, 90)}`);
  console.log(`   duas   : ${transliteration.split('\n')[0].slice(0, 90)}`);
  console.log(`   arabe  : ${arabic.split('\n')[1] || arabic.split('\n')[0]}`);
  if (count === 0) {
    console.log('   -> ignoré, aucun arabe trouvé');
    continue;
  }
  if (write) {
    item.arabic = arabic;
    item.transliteration = transliteration;
    item.pagePath = '';
    changed++;
  }
}
if (write) {
  await fs.writeFile(CATALOG, `${JSON.stringify(catalog, null, 2)}\n`);
  console.log(`\n${changed} textes mis à jour dans ${CATALOG}`);
} else {
  console.log('\nAperçu seulement. Relancer avec --write pour écrire le catalogue.');
}
