import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs/promises";
import path from "node:path";
import { once } from "node:events";
import { createPublicationServer } from "../../services/publisher/public-server.mjs";

test("Publication HTTP : 304, HEAD, reprise 206, If-Range et erreur 416", async (t) => {
  const base = path.resolve("artifacts/http-tests");
  await fs.mkdir(base, { recursive: true });
  const directory = await fs.mkdtemp(path.join(base, "case-"));
  const key = "media/11111111-1111-4111-8111-111111111111/1.mp3";
  await fs.mkdir(path.dirname(path.join(directory, key)), { recursive: true });
  const bytes = await fs.readFile("apps/mobile/assets/fixtures/tone-1.mp3");
  await fs.writeFile(path.join(directory, key), bytes);
  await fs.writeFile(path.join(directory, "latest.json"), '{"fixture":true}');
  const server = createPublicationServer(directory);
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  t.after(async () => {
    server.closeAllConnections();
    await new Promise((resolve) => server.close(resolve));
    if (!directory.startsWith(base + path.sep + "case-"))
      throw Error("Unsafe cleanup");
    await fs.rm(directory, { recursive: true, force: true });
  });
  const origin = `http://127.0.0.1:${server.address().port}`;
  const latest = await fetch(origin + "/latest.json");
  const etag = latest.headers.get("etag");
  await latest.arrayBuffer();
  assert.equal(
    (
      await fetch(origin + "/latest.json", {
        headers: { "If-None-Match": etag },
      })
    ).status,
    304,
  );
  const head = await fetch(origin + "/" + key, { method: "HEAD" });
  assert.equal(Number(head.headers.get("content-length")), bytes.length);
  assert.equal((await head.arrayBuffer()).byteLength, 0);
  const first = await fetch(origin + "/" + key, {
    headers: { Range: "bytes=0-100" },
  });
  assert.equal(first.status, 206);
  const rest = await fetch(origin + "/" + key, {
    headers: { Range: "bytes=101-", "If-Range": head.headers.get("etag") },
  });
  assert.equal(rest.status, 206);
  assert.deepEqual(
    Buffer.concat([
      Buffer.from(await first.arrayBuffer()),
      Buffer.from(await rest.arrayBuffer()),
    ]),
    bytes,
  );
  const invalid = await fetch(origin + "/" + key, {
    headers: { Range: `bytes=${bytes.length}-` },
  });
  assert.equal(invalid.status, 416);
  const changed = await fetch(origin + "/" + key, {
    headers: { Range: "bytes=20-", "If-Range": '"obsolete"' },
  });
  assert.equal(changed.status, 200);
  assert.equal((await changed.arrayBuffer()).byteLength, bytes.length);
  const suffix = await fetch(origin + "/" + key, {
    headers: { Range: "bytes=-10" },
  });
  assert.equal(suffix.status, 206);
  assert.deepEqual(
    Buffer.from(await suffix.arrayBuffer()),
    bytes.subarray(-10),
  );
  assert.equal((await fetch(origin + "/jobs.sqlite")).status, 404);
  assert.equal(
    (await fetch(origin + "/latest.json", { method: "POST" })).status,
    405,
  );
});
