import fs from "node:fs/promises";
import path from "node:path";
import { inventoryAudios } from "./audio-inventory/library.mjs";
import { matchAudioToCatalog } from "./audio-match.mjs";

const DEFAULT_SOURCE =
  "C:\\Users\\alyas\\OneDrive\\Bureau\\Perlesdivines\\audio";
const AUDIO_DIR = "apps/mobile/assets/audio";
const AUDIO_CATALOG = "apps/mobile/assets/content/audio-catalog.json";
const ASSOCIATIONS = "content/audio-associations.json";
const TEXT_CATALOG = "apps/mobile/assets/content/catalog.json";

function assetName(relativePath) {
  const stem = path
    .basename(relativePath)
    .replace(/\.(m4a\.)?mp[34]$/i, "")
    .replace(/\.(m4a|aac)$/i, "");
  const slug = stem
    .normalize("NFKD")
    .replace(/[^\w]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .toLowerCase();
  return `${slug || "audio"}.m4a`;
}

async function ownerSource() {
  try {
    const saved = JSON.parse(
      await fs.readFile("content/development/owner-source.json", "utf8"),
    );
    if (saved.audio) return saved.audio;
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
  }
  return DEFAULT_SOURCE;
}

export async function prepareEmbeddedAudio({ source } = {}) {
  const root = source ?? (await ownerSource());
  try {
    await fs.access(root);
  } catch {
    return { skipped: true, reason: "SOURCE_MISSING", source: root };
  }
  const report = await inventoryAudios(root);
  const texts = JSON.parse(await fs.readFile(TEXT_CATALOG, "utf8"));
  await fs.mkdir(AUDIO_DIR, { recursive: true });
  const tracks = [];
  const associations = [];
  for (const row of report.tracks) {
    if (row.status !== "needs_review" || !row.sha256 || !row.durationMs) {
      continue;
    }
    const file = assetName(row.relativePath);
    const destination = path.join(AUDIO_DIR, file);
    await fs.copyFile(path.join(root, row.relativePath), destination);
    const matched = matchAudioToCatalog(row.relativePath, texts);
    const track = {
      id: row.id,
      title: matched?.title ?? row.suggestions.titleFromFilename,
      author: null,
      version: 1,
      durationMs: row.durationMs,
      sizeBytes: row.sizeBytes,
      sha256: row.sha256,
      file: `audio/${file}`,
      bundled: true,
      fixture: false,
    };
    tracks.push(track);
    if (matched) {
      associations.push({
        audioId: row.id,
        textId: matched.id,
        sourceFile: row.relativePath,
        catalogTitle: matched.title,
      });
    }
  }
  await fs.mkdir(path.dirname(AUDIO_CATALOG), { recursive: true });
  await fs.writeFile(AUDIO_CATALOG, `${JSON.stringify(tracks, null, 2)}\n`);
  await fs.mkdir(path.dirname(ASSOCIATIONS), { recursive: true });
  await fs.writeFile(ASSOCIATIONS, `${JSON.stringify(associations, null, 2)}\n`);
  const byText = new Map();
  for (const row of associations) {
    const list = byText.get(row.textId) ?? [];
    list.push(row.audioId);
    byText.set(row.textId, list);
  }
  for (const item of texts) {
    item.audioIds = byText.get(item.id) ?? [];
  }
  await fs.writeFile(TEXT_CATALOG, `${JSON.stringify(texts, null, 2)}\n`);
  return {
    skipped: false,
    source: root,
    files: tracks.length,
    associated: associations.length,
    unassociated: tracks.length - associations.length,
    invalid: report.summary.invalid,
  };
}

const running =
  process.argv[1] && path.basename(process.argv[1]) === "prepare-embedded-audio.mjs";
if (running) {
  console.log(JSON.stringify(await prepareEmbeddedAudio(), null, 2));
}
