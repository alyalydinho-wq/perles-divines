import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs/promises";
import path from "node:path";
import {
  editableFragments,
  replaceFragment,
} from "../../packages/content-schema/editor.mjs";

test("Éditeur : aller-retour intact et remplacement strictement limité au fragment choisi", () => {
  const html =
    '<!doctype html><html><head><style>p{color:red}</style></head><body><table data-x="exact"><tr><td>Texte &amp; exemple</td><td dir="rtl">العربية</td></tr></table><img src="original.png" width="420"><div data-preserved><custom-tag a="b">Bloc complexe</custom-tag></div></body></html>';
  const fragments = editableFragments(html);
  assert.equal(fragments.length, 2);
  for (const f of fragments)
    assert.equal(replaceFragment(html, f.id, f.text), html);
  const first = fragments[0];
  const text = "Nouvelle phrase <script>alert(1)</script> & exemple";
  const changed = replaceFragment(html, first.id, text);
  assert.ok(changed.startsWith(html.slice(0, first.start)));
  assert.ok(changed.endsWith(html.slice(first.end)));
  assert.ok(changed.includes("&lt;script&gt;"));
  assert.equal(editableFragments(changed)[0].text, text);
  assert.throws(
    () => replaceFragment(changed, first.id, "stale"),
    /FRAGMENT_CONFLICT/,
  );
});

test("Éditeur : modification réelle sur chaque page, autres textes et ressources inchangés", async () => {
  const current = JSON.parse(
    await fs.readFile("content/current-import.json", "utf8"),
  );
  // The importer is a reproducible prerequisite; use its actual normalized output.
  const root = current.directory ?? current.path;
  assert.ok(root, "Chemin de capture requis");
  const files = await fs.readdir(path.join(root, "normalized"), {
    recursive: true,
  });
  let pages = 0,
    fragments = 0;
  for (const file of files.filter((f) => f.endsWith(".html"))) {
    const html = await fs.readFile(path.join(root, "normalized", file), "utf8");
    const items = editableFragments(html);
    pages++;
    fragments += items.length;
    if (items.length) {
      const selected = items[Math.floor(items.length / 2)];
      // Modify only an in-memory copy. The imported religious source is never written.
      const changed = replaceFragment(
        html,
        selected.id,
        "FIXTURE ÉDITION < > & العربية",
      );
      const after = editableFragments(changed).map((f) => f.text);
      const expected = items.map((f) => f.text);
      expected[Math.floor(items.length / 2)] = "FIXTURE ÉDITION < > & العربية";
      assert.deepEqual(after, expected);
      const markup = (value) => value.match(/<[^>]+>/g);
      assert.deepEqual(markup(changed), markup(html));
    }
  }
  assert.ok(pages >= 114);
  assert.ok(fragments > 1000);
});
