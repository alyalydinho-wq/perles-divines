import { spawn } from "node:child_process";
import fs from "node:fs/promises";
import path from "node:path";
import assert from "node:assert/strict";
const origin = "http://127.0.0.1:4177";
// Values are deliberate test fixtures. No Supabase instance/account is contacted.
const child = spawn(
  process.execPath,
  [
    path.resolve("node_modules/next/dist/bin/next"),
    "start",
    path.resolve("apps/admin"),
    "--hostname",
    "127.0.0.1",
    "--port",
    "4177",
  ],
  {
    windowsHide: true,
    env: {
      ...process.env,
      NEXT_TELEMETRY_DISABLED: "1",
      ADMIN_ORIGIN: origin,
      SUPABASE_URL: "http://127.0.0.1:4199",
      SUPABASE_PUBLISHABLE_KEY: "fixture-publishable-no-provider",
      SUPABASE_SERVICE_ROLE_KEY: "fixture-service-no-provider",
    },
    stdio: ["ignore", "pipe", "pipe"],
  },
);
let log = "";
child.stdout.on("data", (chunk) => {
  log = (log + chunk).slice(-10000);
});
child.stderr.on("data", (chunk) => {
  log = (log + chunk).slice(-10000);
});
const checks = [];
try {
  let ready = false;
  for (let i = 0; i < 100; i++) {
    try {
      const r = await fetch(origin);
      if (r.ok) {
        await r.arrayBuffer();
        ready = true;
        break;
      }
    } catch {}
    await new Promise((r) => setTimeout(r, 100));
  }
  assert.ok(ready, log);
  for (const route of [
    "/api/pages",
    "/api/pages/11111111-1111-4111-8111-111111111111",
    "/api/pages/11111111-1111-4111-8111-111111111111/preview",
    "/api/assets/assets/image.png",
  ]) {
    const response = await fetch(origin + route);
    assert.equal(response.status, 401);
    assert.equal((await response.json()).error, "UNAUTHORIZED");
    checks.push(`GET ${route} : 401`);
  }
  for (const route of [
    "/api/pages/11111111-1111-4111-8111-111111111111",
    "/api/password",
  ]) {
    const response = await fetch(origin + route, {
      method: "POST",
      headers: { Origin: origin, "Content-Type": "application/json" },
      body: "{}",
    });
    assert.equal(response.status, 401);
    checks.push(`POST ${route} : 401`);
  }
  const cross = await fetch(origin + "/api/password", {
    method: "POST",
    headers: {
      Origin: "https://untrusted.example",
      "Content-Type": "application/json",
    },
    body: "{}",
  });
  assert.equal(cross.status, 403);
  checks.push("POST inter-origines : 403");
  await fs.writeFile(
    "docs/evidence/admin-unauthorized.json",
    JSON.stringify(
      {
        testedAt: new Date().toISOString(),
        scope:
          "Routes Next réelles avec paramètres de test et sans session ; aucun service Supabase réel",
        checks,
      },
      null,
      2,
    ),
  );
  console.log(`${checks.length} refus serveur vérifiés sans session.`);
} finally {
  child.kill();
}
