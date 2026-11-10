// Aligne l'orthographe des titres tirés des noms de fichiers audio sur celle
// des textes du catalogue : « Douà é Tawassoul » devient « Doua-e-Tawassoul »,
// « Ziarat … » devient « Zyaarat … ».
//
// Seul le titre affiché change. L'adresse sur R2 (`file`), l'identifiant et
// l'empreinte restent ceux du fichier : favoris et téléchargements suivent.

const LEADING = new Map([
  ["douà", "Doua"],
  ["doua", "Doua"],
  ["ziarat", "Zyaarat"],
  ["hadiçe", "Hadith"],
]);

// Mots après lesquels « é » ou « E » est la liaison « -e- » des textes.
const LINKED = new Set(["Doua", "Zyaarat", "Hadith", "Mounajat", "Salàwat"]);

// Formules de salutation écrites en minuscules dans les titres.
const KEEP_CASE = new Set(["as", "sa", "saw", "atfs", "aj"]);

function capitalize(word) {
  const lower = word.toLocaleLowerCase("fr");
  return lower.charAt(0).toLocaleUpperCase("fr") + lower.slice(1);
}

export function harmonizeAudioTitle(title) {
  const words = String(title).trim().split(/\s+/).filter(Boolean);
  if (words.length === 0) return "";
  const lead = LEADING.get(words[0].toLocaleLowerCase("fr"));
  if (lead) words[0] = lead;
  for (let i = 1; i < words.length; i++) {
    // « Sehri ni Douà » : le mot seul, ailleurs dans le titre.
    if (words[i] === "Douà") words[i] = "Doua";
    // « TAWBÀ » : un mot tout en capitales reprend la casse des autres.
    const word = words[i];
    if (
      word.length >= 3 &&
      !KEEP_CASE.has(word.toLowerCase()) &&
      word === word.toLocaleUpperCase("fr") &&
      /\p{L}{3,}/u.test(word)
    ) {
      words[i] = capitalize(word);
    }
  }
  if (
    words.length >= 3 &&
    LINKED.has(words[0]) &&
    /^[éÉeE]$/.test(words[1])
  ) {
    words.splice(0, 3, `${words[0]}-e-${words[2]}`);
  }
  return words.join(" ");
}
