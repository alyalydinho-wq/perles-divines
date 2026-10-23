import fs from 'node:fs/promises';

export const JAWSHAN_ID = 'a6a50d78-0076-5d00-95f2-c3a732c97077';

export function jawshanBlocks(value) {
  return String(value)
    .split(/\n{2,}/)
    .map((block) => block.trim())
    .filter(Boolean);
}

// Même règle que parseJawshanTranslation dans l'application.
export function parseJawshanTranslation(value) {
  const text = String(value);
  const markers = [...text.matchAll(/(?:^|\s)(\d{1,3}) - /g)];
  if (markers.length !== 100) return null;
  const parts = [];
  for (let i = 0; i < markers.length; i++) {
    const match = markers[i];
    const number = Number(match[1]);
    if (number !== i + 1) return null;
    const start = match.index + (text[match.index] === ' ' ? 1 : 0);
    const end = i + 1 < markers.length ? markers[i + 1].index : text.length;
    const part = text.slice(start, end).trim();
    if (!part) return null;
    parts.push(part);
  }
  return {preamble: text.slice(0, markers[0].index).trim(), parts};
}

function compact(value) {
  return String(value).replace(/\s+/g, ' ').trim();
}

export async function checkJawshanParts() {
  const failures = [];
  const catalog = JSON.parse(
    await fs.readFile('apps/mobile/assets/content/catalog.json', 'utf8'),
  );
  const titlesFile = JSON.parse(
    await fs.readFile('apps/mobile/assets/content/jawshan_titles_fr.json', 'utf8'),
  );
  const provenance = JSON.parse(await fs.readFile('content/provenance.json', 'utf8'));
  const item = catalog.find((entry) => entry.id === JAWSHAN_ID);
  if (!item) {
    failures.push('Doua-e-Jawshan-e-Kabir est absent du catalogue');
    return failures;
  }
  const arabic = jawshanBlocks(item.arabic);
  const transliteration = jawshanBlocks(item.transliteration);
  const translation = parseJawshanTranslation(item.translation);
  if (arabic.length !== 100) failures.push(`arabe : ${arabic.length} parties au lieu de 100`);
  if (transliteration.length !== 100) {
    failures.push(`translittération : ${transliteration.length} parties au lieu de 100`);
  }
  if (arabic.some((part) => !part.trim())) failures.push('une partie arabe est vide');
  if (transliteration.some((part) => !part.trim())) {
    failures.push('une partie translittérée est vide');
  }
  const count = Math.min(arabic.length, transliteration.length);
  for (let i = 0; i < count; i++) {
    const arabicLines = arabic[i].split(/\n/).filter((line) => line.trim()).length;
    const transliterationLines = transliteration[i]
      .split(/\n/)
      .filter((line) => line.trim()).length;
    if (arabicLines !== transliterationLines) {
      failures.push(
        `partie ${i + 1} : ${arabicLines} lignes arabes, ${transliterationLines} translittérées`,
      );
    }
  }
  if (!translation) {
    failures.push('traduction : les parties 1 à 100 ne sont pas numérotées dans l’ordre');
  } else if (translation.parts.some((part) => !part.trim())) {
    failures.push('une partie traduite est vide');
  } else if (
    compact([translation.preamble, ...translation.parts].filter(Boolean).join(' ')) !==
    compact(item.translation)
  ) {
    failures.push('le découpage de la traduction ajoute ou retire du texte');
  }
  if (compact(arabic.join(' ')) !== compact(item.arabic)) {
    failures.push('le découpage arabe ajoute ou retire du texte');
  }
  if (compact(transliteration.join(' ')) !== compact(item.transliteration)) {
    failures.push('le découpage de la translittération ajoute ou retire du texte');
  }
  const titles = titlesFile.titles;
  if (!Array.isArray(titles) || titles.length !== 100) {
    failures.push(`titres français : ${titles?.length ?? 0} au lieu de 100`);
  } else {
    titles.forEach((title, index) => {
      const number = index + 1;
      if (title.n !== number) failures.push(`titre ${number} mal numéroté`);
      if (!String(title.en ?? '').trim()) failures.push(`titre ${number} sans anglais`);
      if (!String(title.fr ?? '').trim()) failures.push(`titre ${number} sans français`);
      if (!String(title.fr ?? '').startsWith('Pour ')) {
        failures.push(`titre ${number} ne commence pas par « Pour »`);
      }
    });
  }
  const entry = (provenance.entries ?? []).find((candidate) => candidate.id === JAWSHAN_ID);
  if (!entry?.url?.includes('https://www.duas.org/dua-jawshan-kabeer.html')) {
    failures.push('provenance : URL duas.org absente');
  }
  if (!entry?.retrievedAt) failures.push('provenance : date de récupération absente');
  return failures;
}
