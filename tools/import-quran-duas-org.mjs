// Source « Coran » pour tools/import-duas-org.mjs.
//
// https://quran.duas.org/ est une application Next.js sans contenu côté serveur :
// ses chunks JS (fetchChapterVerses / fetchChapterTranslations) appellent deux
// API publiques, réutilisées ici telles quelles :
//   - arabe (un verset par entrée ; le site affiche text_uthmani, l'app utilise
//     l'orthographe indo-pakistanaise text_indopak pour sa police IndoPak) :
//       https://api.quran.com/api/qdc/verses/by_chapter/<n>?fields=text_indopak&per_page=286
//   - translittération (édition « en.transliteration ») :
//       https://api.alquran.cloud/v1/surah/<n>/en.transliteration
// La basmalah affichée en tête de sourate par le site est le verset 1:1.
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';

export const CACHE = path.join(os.tmpdir(), 'duasorg-cache');

const QURAN_COM = 'https://api.quran.com/api/qdc';
const ALQURAN_CLOUD = 'https://api.alquran.cloud/v1';
const TRANSLITERATION_EDITION = 'en.transliteration';
const ARABIC_FIELD = 'text_indopak';

// Titre exact dans le catalogue -> sourate (et verset unique éventuel).
export const QURAN_MAPPING = [
  {title: 'Ayat al-Kursî', quran: 2, verse: 255},
  {title: 'Sourate al-Fâtihah (1)', quran: 1},
  {title: "Sourate al-'Ankabût (29)", quran: 29},
  {title: 'Sourate al-Rûm (30)', quran: 30},
  {title: 'Sourate al-Ahzâb (33)', quran: 33},
  {title: 'Sourate Yâ-Sîn (36)', quran: 36},
  {title: 'Sourate al-Dukhân (44)', quran: 44},
  {title: 'Sourate al-Rahmân (55)', quran: 55},
  {title: "Sourate al-Wâqi'ah (56)", quran: 56},
  {title: "Sourate al-Jum'ah (62)", quran: 62},
  {title: 'Sourate al-Munâfiqûn (63)', quran: 63},
  {title: 'Sourate al-Mulk (67)', quran: 67},
  {title: "Sourate al-A'lâ (87)", quran: 87},
  {title: 'Sourate as-Shams (91)', quran: 91},
  {title: 'Sourate al-Qadr (97)', quran: 97},
  {title: 'Sourate al-Zalzalah (99)', quran: 99},
  {title: 'Sourate al-Takâthur (102)', quran: 102},
  {title: 'Sourate al-Kawthar (108)', quran: 108},
  {title: 'Sourate al-Kâfirûn (109)', quran: 109},
  {title: 'Sourate al-Ikhlâç (112)', quran: 112},
  {title: 'Sourate al-Falaq (113)', quran: 113},
  {title: 'Sourate an-Nâs (114)', quran: 114},
];

export async function fetchCached(url, name) {
  await fs.mkdir(CACHE, {recursive: true});
  const file = path.join(CACHE, name);
  try {
    return await fs.readFile(file, 'utf8');
  } catch {
    const response = await fetch(url, {
      headers: {'user-agent': 'Mozilla/5.0', accept: 'application/json'},
    });
    if (!response.ok) throw new Error(`${response.status} ${url}`);
    const text = await response.text();
    await fs.writeFile(file, text);
    return text;
  }
}

// Numéro de verset en chiffres arabes-indiens entre parenthèses ornées : ﴿٧﴾
function ayahNumber(n) {
  return `\uFD3F${String(n).replace(/\d/g, (d) => '٠١٢٣٤٥٦٧٨٩'[d])}\uFD3E`;
}

// Le texte IndoPak de quran.com contient des espaces typographiques (U+2002) et
// des caractères de contrôle bidi (U+200B/U+200F) absents de la police : on les
// ramène à des espaces simples.
function clean(text) {
  return (text || '').replace(/[\u200B-\u200F\uFEFF]/g, '').replace(/\s+/g, ' ').trim();
}

// -> Map numéro de verset -> arabe (sans numéro).
async function loadArabic(chapter) {
  const json = await fetchCached(
    `${QURAN_COM}/verses/by_chapter/${chapter}?fields=${ARABIC_FIELD}&per_page=286&page=1`,
    `quran-${chapter}-${ARABIC_FIELD}.json`,
  );
  const data = JSON.parse(json);
  if (data.pagination?.next_page) throw new Error(`sourate ${chapter} : pagination inattendue`);
  return new Map(data.verses.map((v) => [v.verse_number, clean(v[ARABIC_FIELD])]));
}

// -> {name, count, verses: Map numéro -> translittération}.
async function loadTransliteration(chapter) {
  const json = await fetchCached(
    `${ALQURAN_CLOUD}/surah/${chapter}/${TRANSLITERATION_EDITION}`,
    `quran-${chapter}-${TRANSLITERATION_EDITION}.json`,
  );
  const {data} = JSON.parse(json);
  return {
    name: data.englishName,
    count: data.numberOfAyahs,
    verses: new Map(data.ayahs.map((a) => [a.numberInSurah, clean(a.text)])),
  };
}

async function loadChapter(chapter) {
  const [arabic, transliteration] = await Promise.all([loadArabic(chapter), loadTransliteration(chapter)]);
  if (arabic.size !== transliteration.count) {
    throw new Error(`sourate ${chapter} : ${arabic.size} versets arabes pour ${transliteration.count} attendus`);
  }
  return {arabic, ...transliteration};
}

// Même forme que loadSource() : {title, segments, sourceTitle}.
// Segments : basmalah (section à part, sauf al-Fâtihah où c'est le verset 1),
// puis un segment par verset avec son numéro en fin de ligne arabe.
export async function loadQuran(entry) {
  const chapter = await loadChapter(entry.quran);
  const segments = [];
  if (entry.quran !== 1 && entry.quran !== 9) {
    const fatihah = await loadChapter(1);
    segments.push({arabic: fatihah.arabic.get(1), transliteration: fatihah.verses.get(1)});
    segments.push({break: true});
  }
  const numbers = entry.verse ? [entry.verse] : [...chapter.arabic.keys()].sort((a, b) => a - b);
  for (const n of numbers) {
    const arabic = chapter.arabic.get(n);
    if (!arabic) throw new Error(`sourate ${entry.quran} : verset ${n} introuvable`);
    segments.push({arabic: `${arabic} ${ayahNumber(n)}`, transliteration: chapter.verses.get(n) || ''});
  }
  const label = entry.verse ? `${entry.quran}:${entry.verse}` : `sourate ${entry.quran}`;
  return {title: chapter.name, segments, sourceTitle: `${chapter.name} (${label})`, verses: numbers.length};
}
