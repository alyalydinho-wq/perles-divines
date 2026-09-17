import { chromium } from "@playwright/test";
import fs from "node:fs/promises";
import assert from "node:assert/strict";
const origin = "http://127.0.0.1:4176";
const browser = await chromium.launch({ channel: "msedge", headless: true });
const checks = [],
  errors = [],
  requests = [];
try {
  const context = await browser.newContext();
  await context.route("**/*", (route) => {
    const url = new URL(route.request().url());
    requests.push(url.origin);
    return url.origin === origin ? route.continue() : route.abort();
  });
  const page = await context.newPage();
  page.on("pageerror", (error) => errors.push(error.message));
  page.on("console", (message) => {
    if (
      message.type() === "error" &&
      message.text().includes("Content Security Policy")
    )
      errors.push(message.text());
  });
  for (const width of [390, 1280]) {
    await page.setViewportSize({ width, height: 900 });
    await page.goto(origin);
    await page.getByRole("heading", { name: "Votre administration" }).waitFor();
    assert.equal(
      await page.evaluate(
        () => document.documentElement.scrollWidth > innerWidth,
      ),
      false,
    );
    await page.screenshot({
      path: `docs/evidence/admin-configuration-${width}.png`,
      fullPage: true,
    });
    checks.push(
      `Configuration absente : lecture privée fermée, largeur ${width}`,
    );
  }
  await page.goto(`${origin}/admin`);
  assert.equal(new URL(page.url()).pathname, "/");
  checks.push("Écran privé inaccessible sans configuration");
  for (const [route, method] of [
    ["/api/pages", "GET"],
    ["/api/pages/11111111-1111-4111-8111-111111111111", "POST"],
    ["/api/session", "POST"],
    ["/api/password", "POST"],
  ]) {
    const response = await context.request.fetch(origin + route, {
      method,
      headers: { Origin: origin, "Content-Type": "application/json" },
      ...(method === "POST" ? { data: {} } : {}),
    });
    assert.equal(response.status(), 503);
    assert.equal((await response.json()).error, "NOT_CONFIGURED");
    checks.push(`${method} ${route} : 503 sans configuration`);
  }
  await page.goto(`${origin}/recovery`);
  await page.getByRole("button", { name: "Recevoir un lien" }).waitFor();
  await page.getByLabel("Adresse e-mail").fill("fixture@example.test");
  await page.getByRole("button", { name: "Recevoir un lien" }).click();
  await page
    .getByRole("status")
    .filter({ hasText: "Service indisponible" })
    .waitFor();
  checks.push("Formulaire hydraté : service absent signalé sans faux envoi");
  assert.deepEqual(errors, []);
  assert.ok(requests.every((r) => r === origin));
  await fs.writeFile(
    "docs/evidence/admin-browser.json",
    JSON.stringify(
      {
        testedAt: new Date().toISOString(),
        browser: await browser.version(),
        scope:
          "Administration sans services configurés ; aucune authentification Supabase réelle validée",
        checks,
        scriptErrors: errors,
        externalRequests: requests.filter((r) => r !== origin),
      },
      null,
      2,
    ),
  );
  console.log(
    `${checks.length} contrôles navigateur réussis, aucune erreur CSP ni requête externe.`,
  );
} finally {
  await browser.close();
}
