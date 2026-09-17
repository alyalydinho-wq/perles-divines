import fs from "node:fs/promises";
import path from "node:path";
import { hashFile } from "../../services/publisher/publish.mjs";
import { inspectMp3 } from "../../services/publisher/media.mjs";
import { stableId } from "../import-site/content.mjs";

export async function inventoryAudios(directory, { fixture = false } = {}) {
  const root = await fs.realpath(directory),
    files = [],
    warnings = [];
  let visited = 0;
  async function walk(folder) {
    const entries = await fs.readdir(folder, { withFileTypes: true });
    entries.sort((a, b) => a.name.localeCompare(b.name, "fr"));
    for (const entry of entries) {
      if (++visited > 500000) throw Error("SCAN_LIMIT");
      const absolute = path.join(folder, entry.name),
        relative = path.relative(root, absolute).split(path.sep).join("/");
      if (entry.isSymbolicLink()) {
        warnings.push({ path: relative, code: "SYMLINK_SKIPPED" });
        continue;
      }
      if (entry.isDirectory()) await walk(absolute);
      else if (entry.isFile() && /\.mp3$/i.test(entry.name)) {
        if (files.length >= 100000) throw Error("CATALOG_LIMIT");
        files.push({ absolute, relative });
      }
    }
  }
  await walk(root);
  const tracks = [];
  // Sequential disk reads bound memory/I/O even when the catalogue grows.
  for (const { absolute, relative } of files) {
    const before = await fs.stat(absolute);
    const row = {
      id: stableId(`audio-draft:${relative}`),
      relativePath: relative,
      fixture,
      status: "needs_review",
      editorialValidated: false,
      title: null,
      author: null,
      description: "",
      collection: null,
      themes: [],
      suggestions: {
        titleFromFilename: path.basename(relative).replace(/\.mp3$/i, ""),
        folderLabels: relative.split("/").slice(0, -1),
      },
      sizeBytes: before.size,
      sha256: null,
      durationMs: null,
      tags: {},
      error: null,
    };
    try {
      if (before.size > 8 * 1024 ** 3) throw Error("FILE_TOO_LARGE");
      Object.assign(row, await hashFile(absolute));
      const measured = await inspectMp3(absolute, { tags: true });
      row.durationMs = measured.durationMs;
      row.tags = measured.tags;
      const after = await fs.stat(absolute);
      if (after.size !== before.size || after.mtimeMs !== before.mtimeMs)
        throw Error("SOURCE_CHANGED");
    } catch (e) {
      row.status = "invalid";
      row.error = ["FILE_TOO_LARGE", "SOURCE_CHANGED"].includes(e.message)
        ? e.message
        : "INVALID_MEDIA";
    }
    tracks.push(row);
  }
  const groups = new Map();
  for (const track of tracks) {
    if (!track.sha256) continue;
    const group = groups.get(track.sha256) ?? [];
    group.push(track.relativePath);
    groups.set(track.sha256, group);
  }
  return {
    schemaVersion: 1,
    createdAt: new Date().toISOString(),
    sourceRoot: root,
    fixture,
    sourceReadOnly: true,
    fullDecodePerformed: false,
    tracks,
    duplicateGroups: [...groups]
      .filter(([, paths]) => paths.length > 1)
      .map(([sha256, paths]) => ({ sha256, paths })),
    warnings,
    summary: {
      files: tracks.length,
      measured: tracks.filter((t) => t.status === "needs_review").length,
      invalid: tracks.filter((t) => t.status === "invalid").length,
      totalBytes: tracks.reduce((sum, t) => sum + t.sizeBytes, 0),
      totalDurationMs: tracks.reduce((sum, t) => sum + (t.durationMs ?? 0), 0),
    },
  };
}

export function metadataCsv(report) {
  const quote = (value) => {
    const text = String(value ?? "");
    // This file is for human completion in spreadsheet tools; raw paths/tags stay in JSON.
    const safe = /^[=+\-@\t\r\n]/.test(text) ? `'${text}` : text;
    return `"${safe.replaceAll('"', '""')}"`;
  };
  return (
    "\ufeffrelative_path,title,author,collection,theme,description,sort_order,page_id\r\n" +
    report.tracks
      .map((t) =>
        [
          t.relativePath,
          t.suggestions.titleFromFilename,
          "",
          "",
          "",
          "",
          "",
          "",
        ]
          .map(quote)
          .join(","),
      )
      .join("\r\n") +
    "\r\n"
  );
}
