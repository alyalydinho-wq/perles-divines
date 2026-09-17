import fs from "node:fs/promises";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import {
  validateLatest,
  validateManifest,
} from "../packages/content-schema/runtime.mjs";
const origin = "http://127.0.0.1:4175",
  options = { development: true, allowedOrigins: [origin] };
const response = await fetch(origin + "/latest.json");
assert.equal(response.status, 200);
const latest = validateLatest(await response.json(), options);
assert.equal(
  (
    await fetch(origin + "/latest.json", {
      headers: { "If-None-Match": response.headers.get("etag") },
    })
  ).status,
  304,
);
const bytes = Buffer.from(
  await (await fetch(latest.manifest.url)).arrayBuffer(),
);
assert.equal(bytes.length, latest.manifest.sizeBytes);
assert.equal(
  createHash("sha256").update(bytes).digest("hex"),
  latest.manifest.sha256,
);
const manifest = validateManifest(JSON.parse(bytes), options),
  files = [];
for (const track of manifest.tracks) {
  const media = track.media;
  const head = await fetch(media.url, { method: "HEAD" });
  assert.equal(head.status, 200);
  assert.equal(Number(head.headers.get("content-length")), media.sizeBytes);
  const fetched = await fetch(media.url);
  const hash = createHash("sha256");
  let size = 0;
  for await (const chunk of fetched.body) {
    size += chunk.length;
    hash.update(chunk);
  }
  assert.equal(size, media.sizeBytes);
  assert.equal(hash.digest("hex"), media.sha256);
  files.push({
    id: track.id,
    sizeBytes: size,
    durationMs: media.durationMs,
    fixture: track.fixture,
  });
}
const record = {
  testedAt: new Date().toISOString(),
  releaseVersion: latest.releaseVersion,
  scope:
    "Vraie publication sur disque local et lecture HTTP ; aucune ressource R2, aucun catalogue religieux",
  manifestHashVerified: true,
  etag304: true,
  files,
};
await fs.writeFile(
  "docs/evidence/local-publication.json",
  JSON.stringify(record, null, 2),
);
console.log(
  `${files.length} médias publiés localement puis relus avec empreintes identiques.`,
);
