import fs from "node:fs/promises";
import { LocalJobs } from "../services/publisher/local-store.mjs";
import { validateManifest } from "../packages/content-schema/runtime.mjs";
const origin = "http://127.0.0.1:4175";
const fixtures = JSON.parse(
  await fs.readFile("content/fixtures/catalog.json", "utf8"),
);
const manifest = {
  schemaVersion: 1,
  releaseVersion: 1,
  publishedAt: new Date().toISOString(),
  sections: [],
  authors: [],
  themes: [],
  collections: [],
  tracks: fixtures.map((t) => ({
    id: t.id,
    title: t.title,
    description: t.description,
    authorId: null,
    contentVersion: 1,
    fixture: true,
    themeIds: [],
    media: {
      id: t.id,
      version: t.version,
      url: `${origin}/media/${t.id}/${t.version}.mp3`,
      mime: "audio/mpeg",
      sizeBytes: t.sizeBytes,
      sha256: t.sha256,
      durationMs: t.durationMs,
    },
  })),
  pages: [],
  collectionTracks: [],
  audioPageLinks: [],
  removedTrackIds: [],
};
validateManifest(manifest, { development: true, allowedOrigins: [origin] });
const jobs = new LocalJobs("content/development");
try {
  const row = jobs.submit(
    {
      manifest,
      files: fixtures.map((t, i) => ({
        url: manifest.tracks[i].media.url,
        relativePath: t.file,
      })),
    },
    `fixture-${manifest.publishedAt}`,
  );
  console.log(
    `Tâche locale ${row.id}, version ${row.version}. Exécuter node services/publisher/worker.mjs --once`,
  );
} finally {
  jobs.close();
}
