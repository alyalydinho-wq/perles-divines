import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs/promises";
import path from "node:path";
import { randomUUID, createHash } from "node:crypto";
import {
  validateManifest,
  validateLatest,
} from "../../packages/content-schema/runtime.mjs";
import { LocalJobs } from "../../services/publisher/local-store.mjs";
import {
  LocalObjects,
  publish,
  safeKey,
} from "../../services/publisher/publish.mjs";
const origin = "http://127.0.0.1:4175",
  options = {
    development: true,
    allowedOrigins: [origin],
    publicOrigin: origin,
  };
const bytes = await fs.readFile("apps/mobile/assets/fixtures/tone-1.mp3");
const digest = createHash("sha256").update(bytes).digest("hex");
function manifest() {
  const id = randomUUID();
  return {
    schemaVersion: 1,
    releaseVersion: 1,
    publishedAt: "2026-09-17T08:00:00Z",
    sections: [],
    authors: [],
    themes: [],
    collections: [],
    tracks: [
      {
        id,
        title: "Écoute d’essai",
        description: "",
        authorId: null,
        contentVersion: 1,
        fixture: true,
        media: {
          id,
          version: 1,
          url: `${origin}/media/${id}/1.mp3`,
          sha256: digest,
          sizeBytes: bytes.length,
          durationMs: 20000,
          mime: "audio/mpeg",
        },
        themeIds: [],
      },
    ],
    pages: [],
    collectionTracks: [],
    audioPageLinks: [],
    removedTrackIds: [],
  };
}
async function setup(t) {
  const base = path.resolve("artifacts/publication-tests");
  await fs.mkdir(base, { recursive: true });
  const directory = await fs.mkdtemp(path.join(base, "case-"));
  const jobs = new LocalJobs(directory),
    objects = new LocalObjects(path.join(directory, "public"));
  await fs.writeFile(path.join(directory, "input.mp3"), bytes);
  t.after(async () => {
    jobs.close();
    if (!directory.startsWith(base + path.sep + "case-"))
      throw Error("Unsafe cleanup");
    await fs.rm(directory, { recursive: true, force: true });
  });
  const m = manifest();
  return {
    directory,
    jobs,
    objects,
    options: { ...options, inputRoot: directory },
    snapshot: {
      manifest: m,
      files: [{ url: m.tracks[0].media.url, relativePath: "input.mp3" }],
    },
  };
}
test("Contrat : titre accentué conservé, auteur inconnu nullable, aucune limite à 500", () => {
  const m = manifest();
  for (let i = 1; i < 1000; i++) {
    const t = structuredClone(m.tracks[0]);
    t.id = randomUUID();
    m.tracks.push(t);
  }
  assert.equal(validateManifest(m, options).tracks.length, 1000);
  assert.equal(m.tracks[0].authorId, null);
});
test("Contrat : refuse les origines privées, fixtures de production, faux hash, cycles et références absentes", () => {
  for (const modify of [
    (m) => (m.tracks[0].media.url = "http://192.168.1.1/latest.json"),
    (m) => (m.tracks[0].media.sha256 = "0".repeat(64)),
    (m) => (m.tracks[0].authorId = randomUUID()),
    (m) => (m.publishedAt = "2026-02-31T00:00:00Z"),
    (m) => {
      const id = randomUUID();
      m.sections = [{ id, title: "Cycle", parentId: id, order: 0 }];
    },
    (m) => (m.tracks[0].media.url = origin + "/latest.json"),
  ]) {
    const m = manifest();
    modify(m);
    assert.throws(() => validateManifest(m, options));
  }
  assert.throws(
    () => validateManifest(manifest(), { ...options, development: false }),
    /fixtures/,
  );
});
test("Publication : fichiers et manifeste prêts avant latest ; données immuables", async (t) => {
  const s = await setup(t);
  const row = s.jobs.submit(s.snapshot, "same-click");
  assert.equal(s.jobs.submit(s.snapshot, "same-click").id, row.id);
  const job = s.jobs.claim("worker-a");
  assert.equal(s.jobs.claim("worker-b"), null);
  const latest = await publish(job, s.jobs, s.objects, s.options);
  validateLatest(latest, options);
  assert.equal(latest.releaseVersion, 1);
  assert.equal(s.jobs.state().active_version, 1);
  const stored = JSON.parse(
    await fs.readFile(
      path.join(s.directory, "public/releases/1/manifest.json"),
    ),
  );
  assert.equal(stored.tracks[0].title, "Écoute d’essai");
  assert.throws(
    () => s.jobs.submit({ ...s.snapshot, changed: true }, "same-click"),
    /IDEMPOTENCY_CONFLICT/,
  );
});
test("Crash après latest : reprise après expiration du bail, sans nouvelle version ni doublon", async (t) => {
  const s = await setup(t);
  s.jobs.submit(s.snapshot, "crash");
  const job = s.jobs.claim("dead-worker");
  await assert.rejects(
    publish(job, s.jobs, s.objects, s.options, {
      afterPointer: () => {
        throw Error("SIMULATED_CRASH");
      },
    }),
    /SIMULATED_CRASH/,
  );
  assert.equal((await s.objects.latest()).releaseVersion, 1);
  assert.equal(s.jobs.state().active_version, 0);
  s.jobs.db.prepare("UPDATE publication_state SET lease_until=0").run();
  const resumed = s.jobs.claim("new-worker");
  await publish(resumed, s.jobs, s.objects, s.options);
  assert.equal(s.jobs.state().active_version, 1);
  assert.equal(s.jobs.db.prepare("SELECT count(*) AS n FROM jobs").get().n, 1);
});
test("Erreur avant latest : ancienne publication intacte ; restauration sous numéro croissant", async (t) => {
  const s = await setup(t);
  s.jobs.submit(s.snapshot, "v1");
  await publish(s.jobs.claim("a"), s.jobs, s.objects, s.options);
  const broken = structuredClone(s.snapshot);
  broken.manifest.tracks[0].media.sha256 = "a".repeat(64);
  s.jobs.submit(broken, "bad");
  const bad = s.jobs.claim("b");
  await assert.rejects(
    publish(bad, s.jobs, s.objects, s.options),
    /INTEGRITY_ERROR/,
  );
  s.jobs.fail(bad, "Invalid file");
  assert.equal((await s.objects.latest()).releaseVersion, 1);
  s.jobs.submit(s.snapshot, "restore-v1");
  const restored = await publish(
    s.jobs.claim("c"),
    s.jobs,
    s.objects,
    s.options,
  );
  assert.equal(restored.releaseVersion, 3);
  assert.equal(s.jobs.state().active_version, 3);
});
test("Traversées de chemins refusées", () => {
  for (const key of [
    "../secret",
    "/absolute",
    "a/../../b",
    "a\\..\\b",
    "C:\\secret",
  ])
    assert.throws(() => safeKey("content", key), /UNSAFE_KEY/);
});
test("Un faux MP3 avec une taille et une empreinte exactes ne peut pas être publié", async (t) => {
  const s = await setup(t);
  const bad = Buffer.from("Texte déguisé en MP3");
  await fs.writeFile(path.join(s.directory, "input.mp3"), bad);
  Object.assign(s.snapshot.manifest.tracks[0].media, {
    sha256: createHash("sha256").update(bad).digest("hex"),
    sizeBytes: bad.length,
  });
  s.jobs.submit(s.snapshot, "not-mp3");
  await assert.rejects(
    publish(s.jobs.claim("worker"), s.jobs, s.objects, s.options),
    /INVALID_MEDIA/,
  );
  assert.equal(await s.objects.latest(), null);
});
test("Stockage immuable : deux écritures identiques simultanées sont idempotentes", async (t) => {
  const s = await setup(t);
  const expected = { sha256: digest, sizeBytes: bytes.length };
  await Promise.all([
    s.objects.putFile(
      "media/concurrent.mp3",
      path.join(s.directory, "input.mp3"),
      expected,
    ),
    s.objects.putFile(
      "media/concurrent.mp3",
      path.join(s.directory, "input.mp3"),
      expected,
    ),
  ]);
  assert.deepEqual(
    await fs.readFile(path.join(s.directory, "public/media/concurrent.mp3")),
    bytes,
  );
});
