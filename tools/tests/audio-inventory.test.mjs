import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs/promises";
import path from "node:path";
import { inventoryAudios, metadataCsv } from "../audio-inventory/library.mjs";
import { hashFile } from "../../services/publisher/publish.mjs";

test("Inventaire : lecture seule, doublon conservé, faux MP3 signalé, aucune attribution inventée", async (t) => {
  const base = path.resolve("artifacts/inventory-tests");
  await fs.mkdir(base, { recursive: true });
  const root = await fs.mkdtemp(path.join(base, "case-"));
  const folder = path.join(root, "Dossier sans auteur validé");
  await fs.mkdir(folder);
  const a = path.join(folder, "Épreuve, numéro 1.mp3"),
    b = path.join(folder, "Autre titre.mp3");
  await fs.copyFile("apps/mobile/assets/fixtures/tone-1.mp3", a);
  await fs.copyFile(a, b);
  await fs.writeFile(path.join(root, "faux.mp3"), "aucun flux audio");
  const before = await hashFile(a);
  t.after(async () => {
    if (!root.startsWith(base + path.sep + "case-"))
      throw Error("Unsafe cleanup");
    await fs.rm(root, { recursive: true, force: true });
  });
  const report = await inventoryAudios(root, { fixture: true });
  assert.equal(report.summary.files, 3);
  assert.equal(report.summary.measured, 2);
  assert.equal(report.summary.invalid, 1);
  assert.equal(report.duplicateGroups.length, 1);
  assert.equal(report.duplicateGroups[0].paths.length, 2);
  for (const row of report.tracks) {
    assert.equal(row.author, null);
    assert.equal(row.title, null);
    assert.equal(row.description, "");
    assert.equal(row.editorialValidated, false);
    assert.equal(row.fixture, true);
  }
  assert.deepEqual(await hashFile(a), before);
  assert.ok(
    report.tracks.find((t) => t.relativePath.endsWith("Épreuve, numéro 1.mp3"))
      .durationMs > 20000,
  );
  assert.ok(metadataCsv(report).includes('"Épreuve, numéro 1"'));
  report.tracks[0].suggestions.titleFromFilename = '=HYPERLINK("untrusted")';
  assert.ok(metadataCsv(report).includes('"\'=HYPERLINK(""untrusted"")"'));
});
