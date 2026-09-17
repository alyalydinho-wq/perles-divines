import test from "node:test";
import assert from "node:assert/strict";
import {
  assertOrigin,
  readJson,
  errorResponse,
  AdminError,
} from "../../apps/admin/src/lib/security.ts";
const origin = "https://admin.perlesdivines.test";
test("Administration : mutations inter-origines et origine absente refusées", () => {
  for (const supplied of [
    null,
    "https://evil.test",
    origin + ".evil.test",
    "null",
  ]) {
    const headers = new Headers();
    if (supplied) headers.set("Origin", supplied);
    assert.throws(
      () => assertOrigin(new Request(origin, { headers }), origin),
      /FORBIDDEN/,
    );
  }
  assert.doesNotThrow(() =>
    assertOrigin(new Request(origin, { headers: { Origin: origin } }), origin),
  );
  assert.throws(
    () =>
      assertOrigin(
        new Request(origin, {
          headers: { Origin: origin, "sec-fetch-site": "cross-site" },
        }),
        origin,
      ),
    /FORBIDDEN/,
  );
});
test("Administration : corps borné même sans Content-Length et erreurs sans détail interne", async () => {
  const request = (body) =>
    new Request(origin, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body,
    });
  assert.deepEqual(await readJson(request('{"ok":true}')), { ok: true });
  await assert.rejects(
    readJson(request("x".repeat(1000)), 20),
    /REQUEST_TOO_LARGE/,
  );
  await assert.rejects(readJson(request("{")), /INVALID_REQUEST/);
  assert.deepEqual(await errorResponse(Error("secret provider token")).json(), {
    error: "TEMPORARY_FAILURE",
  });
  assert.equal(errorResponse(new AdminError("FORBIDDEN", 403)).status, 403);
});
