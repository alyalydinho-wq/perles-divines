const FILE_RULES = [
  { file: /iftitah|iftetah/i, title: /iftetah|iftitah/i },
  { file: /qomel|kumayl|kumail/i, title: /kumayl|kumail/i },
  { file: /\bahad\b/i, title: /\bahad\b/i },
  { file: /maqarim|makarim|akhlaq|akhlak/i, title: /makarim|maqarim|akhlak|akhlaq/i },
  { file: /aminullah|amin.?all/i, title: /amin.?all/i },
];

export function matchAudioToCatalog(filename, items) {
  const rules = FILE_RULES.filter((rule) => rule.file.test(filename));
  if (rules.length !== 1) return null;
  const matches = items.filter((item) => rules[0].title.test(item.title));
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
