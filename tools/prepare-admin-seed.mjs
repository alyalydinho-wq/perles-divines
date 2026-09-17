import fs from "node:fs/promises";
import path from "node:path";
const current = JSON.parse(
  await fs.readFile("content/current-import.json", "utf8"),
);
const inventory = JSON.parse(
  await fs.readFile("content/source-inventory.json", "utf8"),
);
const quote = (value) => "'" + String(value).replaceAll("'", "''") + "'";
const sql = [
  "-- Initialisation locale préparée depuis la capture, jamais exécutée automatiquement.",
  "-- Appliquer la migration privée au préalable. Les pages existantes ne sont pas écrasées.",
  "begin;",
];
let count = 0;
for (const item of inventory.filter(
  (r) => r.status === 200 && r.kind === "html",
)) {
  const html = await fs.readFile(
    path.join(current.directory, "normalized", item.localPath),
    "utf8",
  );
  sql.push(
    `insert into public.pages(id,title,source_url,slug) values (${quote(item.id)},${quote(item.title || new URL(item.url).pathname)},${quote(item.url)},${quote(item.localPath)}) on conflict (id) do nothing;`,
  );
  sql.push(
    `insert into public.page_revisions(page_id,revision,html) values (${quote(item.id)},1,${quote(html)}) on conflict (page_id,revision) do nothing;`,
  );
  count++;
}
sql.push("commit;");
await fs.mkdir("artifacts", { recursive: true });
await fs.writeFile(
  "artifacts/admin-initial-content.sql",
  sql.join("\n"),
  "utf8",
);
console.log(
  `${count} pages préparées dans artifacts/admin-initial-content.sql. Aucune écriture distante.`,
);
