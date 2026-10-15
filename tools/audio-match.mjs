const CATEGORIES = new Set([
  "doua",
  "ziarat",
  "hadith",
  "namaz",
  "sourate",
  "mounajat",
  "salawat",
  "salat",
  "aamal",
]);

const WEEKDAYS = new Set([
  "lundi",
  "mardi",
  "mercredi",
  "jeudi",
  "vendredi",
  "samedi",
  "dimanche",
]);

const EPITHETS = new Set([
  "prophete",
  "prophet",
  "rasul",
  "rasool",
  "moustapha",
  "mustafa",
  "mustapha",
  "sayyada",
  "sayeda",
  "hazrat",
  "bibi",
  "janabe",
]);

const DROP = new Set([
  "a",
  "au",
  "aux",
  "d",
  "de",
  "des",
  "du",
  "e",
  "el",
  "et",
  "h",
  "l",
  "la",
  "le",
  "les",
  "ni",
  "pour",
  "un",
  "une",
  "al",
  "ar",
  "as",
  "bin",
  "ibn",
  "ibne",
  "sa",
  "saw",
  "aj",
  "atfs",
  "audio",
  "m4a",
  "mp3",
  "mp4",
  "aac",
  "wav",
]);

const SYNONYMS = {
  hadice: "hadith",
  hadic: "hadith",
  hadeese: "hadith",
  hadees: "hadith",
  hadis: "hadith",
  kissa: "kisa",
  kissaa: "kisa",
  kisaa: "kisa",
  tawassul: "tawassoul",
  tawassol: "tawassoul",
  tavassoul: "tawassoul",
  bahaa: "baha",
  mashlou: "mashlool",
  mashloul: "mashlool",
  mashlul: "mashlool",
  moudjir: "mujir",
  mudjir: "mujir",
  mujeer: "mujir",
  qomel: "kumayl",
  qomail: "kumayl",
  kumail: "kumayl",
  kumeyl: "kumayl",
  komail: "kumayl",
  iftitah: "iftetah",
  maqarim: "makarim",
  maqarimoul: "makarim",
  makarimoul: "makarim",
  akhlaq: "akhlak",
  aminullah: "aminallah",
  zyarat: "ziarat",
  zyaarat: "ziarat",
  zyarate: "ziarat",
  zyaraat: "ziarat",
  dua: "doua",
  douaa: "doua",
  warisa: "waressa",
  waresa: "waressa",
  warissa: "waressa",
  ashura: "ashoura",
  achoura: "ashoura",
  nudbah: "nudba",
  yassin: "yasin",
  yassine: "yasin",
  yaseen: "yasin",
  fatema: "fatima",
  fatimah: "fatima",
  zehra: "zahra",
  zaman: "mahdi",
  zamana: "mahdi",
  imame: "imam",
  juma: "vendredi",
  jumua: "vendredi",
  jumuah: "vendredi",
  jumma: "vendredi",
  mouhammad: "mohammad",
  muhammad: "mohammad",
  mohammed: "mohammad",
  muhammed: "mohammad",
  hajate: "hajat",
  housseyn: "houssein",
  hussein: "houssein",
  hussain: "houssein",
  hossein: "houssein",
  raza: "reza",
  ridha: "reza",
  naqi: "hadi",
  baqer: "baqir",
  djaffar: "jafar",
  jaafar: "jafar",
  jaffar: "jafar",
  sadiq: "sadiq",
  sadique: "sadiq",
  taqi: "jawad",
  jawwad: "jawad",
  kadhim: "kazim",
  moussa: "moussa",
  musa: "moussa",
};

function fold(value) {
  return String(value ?? "")
    .normalize("NFKD")
    .replace(/\p{M}/gu, "")
    .toLowerCase()
    .replace(/['’ʻ]/g, "")
    .replace(/[^a-z0-9]+/g, " ")
    .trim()
    .replace(/\bamin\s+all(?:ah)?\b/g, "aminallah")
    .replace(/\barbae\s+en\b/g, "arbaeen")
    .replace(/\bfate\s+ma\b/g, "fatima");
}

export function nameTokens(value) {
  const tokens = new Set();
  for (const raw of fold(value).split(/\s+/)) {
    if (!raw || DROP.has(raw)) continue;
    tokens.add(SYNONYMS[raw] ?? raw);
  }
  return tokens;
}

function isFiller(token) {
  return CATEGORIES.has(token) || WEEKDAYS.has(token) || EPITHETS.has(token);
}

function compatible(audio, text) {
  const audioCategory = [...audio].find((token) => CATEGORIES.has(token));
  const textCategory = [...text].find((token) => CATEGORIES.has(token));
  if (audioCategory && textCategory && audioCategory !== textCategory) return false;
  for (const token of audio) {
    if (!text.has(token) && !isFiller(token)) return false;
  }
  for (const token of text) {
    if (!audio.has(token) && !isFiller(token)) return false;
  }
  let specific = 0;
  for (const token of audio) {
    if (text.has(token) && !isFiller(token) && !/^\d+$/.test(token)) specific += 1;
  }
  return specific >= 1;
}

export function matchAudioToCatalog(filename, items) {
  const audio = nameTokens(filename);
  const matches = items.filter((item) => compatible(audio, nameTokens(item.title)));
  return matches.length === 1 ? matches[0] : null;
}

export async function applyAudioAssociations(items, associationsPath) {
  const fs = await import("node:fs/promises");
  try {
    const associations = JSON.parse(await fs.readFile(associationsPath, "utf8"));
    const byText = new Map();
    for (const row of associations) {
      if (!row.textId || !row.audioId) continue;
      const list = byText.get(row.textId) ?? [];
      if (!list.includes(row.audioId)) list.push(row.audioId);
      byText.set(row.textId, list);
    }
    for (const item of items) {
      item.audioIds = byText.get(item.id) ?? [];
    }
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
  }
  return items;
}
