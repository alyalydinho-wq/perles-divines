import fs from "node:fs/promises";
import path from "node:path";
import { HeadObjectCommand, PutObjectCommand } from "@aws-sdk/client-s3";
import { loadR2Env, publicObjectUrl, r2Client } from "./r2-client.mjs";
import { inventoryAudios } from "./audio-inventory/library.mjs";
import { matchAudioToCatalog } from "./audio-match.mjs";

const DEFAULT_SOURCE =
  "C:\\Users\\alyas\\OneDrive\\Bureau\\Perlesdivines\\audio";
const AUDIO_CATALOG = "apps/mobile/assets/content/audio-catalog.json";
const ASSOCIATIONS = "content/audio-associations.json";
const TEXT_CATALOG = "apps/mobile/assets/content/catalog.json";
const MANIFEST = "artifacts/r2-audio-test.json";

export function assetName(relativePath) {
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

function parseArgs(argv) {
  const args = { limit: null, includes: [], writeCatalog: false, keys: [] };
  for (let i = 0; i < argv.length; i++) {
    const token = argv[i];
    if (token === "--limit") args.limit = Number(argv[++i]);
    else if (token === "--include") args.includes.push(argv[++i]);
    else if (token === "--write-catalog") args.writeCatalog = true;
    else if (token === "--key") args.keys.push(argv[++i]);
  }
  return args;
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

export function uniqueAudioKey(relativePath, sha256, used) {
  let file = assetName(relativePath);
  if (used.has(file)) {
    file = `${file.replace(/\.m4a$/i, "")}-${sha256.slice(0, 8)}.m4a`;
  }
  used.add(file);
  return `audio/${file}`;
}

function selected(tracks, args) {
  let rows = tracks.filter(
    (row) => row.status === "needs_review" && row.sha256 && row.durationMs,
  );
  if (args.includes.length) {
    rows = rows.filter((row) =>
      args.includes.some((needle) =>
        row.relativePath.toLowerCase().includes(needle.toLowerCase()),
      ),
    );
  }
  if (Number.isFinite(args.limit) && args.limit > 0) {
    rows = rows.slice(0, args.limit);
  }
  return rows;
}

async function alreadyPublished(client, bucket, key, sizeBytes, sha256) {
  try {
    const head = await client.send(
      new HeadObjectCommand({ Bucket: bucket, Key: key }),
    );
    const sameSize = Number(head.ContentLength) === sizeBytes;
    const meta = head.Metadata?.sha256;
    return sameSize && (!meta || meta === sha256);
  } catch (error) {
    if (error.$metadata?.httpStatusCode === 404 || error.name === "NotFound") {
      return false;
    }
    throw error;
  }
}

export async function publishR2Audio({
  source,
  limit,
  includes = [],
  writeCatalog = false,
} = {}) {
  const env = await loadR2Env();
  const client = r2Client(env);
  const root = source ?? (await ownerSource());
  const report = await inventoryAudios(root);
  const texts = JSON.parse(await fs.readFile(TEXT_CATALOG, "utf8"));
  const rows = selected(report.tracks, { limit, includes });
  const tracks = [];
  const associations = [];
  const uploaded = [];
  const usedNames = new Set();
  for (const row of rows) {
    const key = uniqueAudioKey(row.relativePath, row.sha256, usedNames);
    if (
      !(await alreadyPublished(
        client,
        env.R2_BUCKET,
        key,
        row.sizeBytes,
        row.sha256,
      ))
    ) {
      const body = await fs.readFile(path.join(root, row.relativePath));
      await client.send(
        new PutObjectCommand({
          Bucket: env.R2_BUCKET,
          Key: key,
          Body: body,
          ContentType: "audio/mp4",
          CacheControl: "public, max-age=86400",
          Metadata: {
            sha256: row.sha256,
          },
        }),
      );
    }
    const head = await client.send(
      new HeadObjectCommand({ Bucket: env.R2_BUCKET, Key: key }),
    );
    if (Number(head.ContentLength) !== row.sizeBytes) {
      throw new Error(`Size mismatch for ${key}`);
    }
    const matched = matchAudioToCatalog(row.relativePath, texts);
    const track = {
      id: row.id,
      title: matched?.title ?? row.suggestions.titleFromFilename,
      author: null,
      version: 1,
      durationMs: row.durationMs,
      sizeBytes: row.sizeBytes,
      sha256: row.sha256,
      file: key,
      bundled: false,
      fixture: false,
    };
    tracks.push(track);
    uploaded.push({
      key,
      sizeBytes: row.sizeBytes,
      sha256: row.sha256,
      publicUrl: publicObjectUrl(env, key),
    });
    if (matched) {
      associations.push({
        audioId: row.id,
        textId: matched.id,
        sourceFile: row.relativePath,
        catalogTitle: matched.title,
      });
    }
  }
  if (writeCatalog) {
    await fs.writeFile(AUDIO_CATALOG, `${JSON.stringify(tracks, null, 2)}\n`);
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
  }
  await fs.mkdir(path.dirname(MANIFEST), { recursive: true });
  const manifest = {
    bucket: env.R2_BUCKET,
    publicUrl: env.R2_PUBLIC_URL || null,
    uploadedAt: new Date().toISOString(),
    files: uploaded,
    tracks,
  };
  await fs.writeFile(MANIFEST, `${JSON.stringify(manifest, null, 2)}\n`);
  return {
    source: root,
    uploaded: uploaded.length,
    associated: associations.length,
    publicUrl: env.R2_PUBLIC_URL || null,
    files: uploaded,
  };
}

export async function verifyPublicUrls(env, keys) {
  const results = [];
  for (const key of keys) {
    const url = publicObjectUrl(env, key);
    if (!url) {
      results.push({ key, ok: false, reason: "NO_PUBLIC_URL" });
      continue;
    }
    const response = await fetch(url, {
      headers: { Range: "bytes=0-1" },
    });
    results.push({
      key,
      url,
      ok: response.ok || response.status === 206,
      status: response.status,
      contentType: response.headers.get("content-type"),
    });
  }
  return results;
}

const running =
  process.argv[1] && path.basename(process.argv[1]) === "publish-r2-audio.mjs";
if (running) {
  const args = parseArgs(process.argv.slice(2));
  if (args.keys.length) {
    const env = await loadR2Env();
    console.log(JSON.stringify(await verifyPublicUrls(env, args.keys), null, 2));
  } else {
    console.log(
      JSON.stringify(
        await publishR2Audio({
          limit: args.limit,
          includes: args.includes,
          writeCatalog: args.writeCatalog,
        }),
        null,
        2,
      ),
    );
  }
}
