import fs from "node:fs/promises";
import path from "node:path";
import { inventoryAudios, metadataCsv } from "./library.mjs";
const args = process.argv.slice(2),
  index = args.indexOf("--source"),
  source = index >= 0 ? args[index + 1] : null;
if (!source) {
  console.error(
    'Usage : node tools/audio-inventory/cli.mjs --source "C:\\Dossier MP3" [--fixture]',
  );
  process.exitCode = 1;
} else {
  const sourceRoot = await fs.realpath(source),
    outputRoot = path.resolve("artifacts/audio-inventory");
  if (outputRoot === sourceRoot || outputRoot.startsWith(sourceRoot + path.sep))
    throw Error(
      "Le dossier de résultats doit être extérieur au dossier source.",
    );
  const report = await inventoryAudios(sourceRoot, {
    fixture: args.includes("--fixture"),
  });
  const output = path.join(
    outputRoot,
    new Date().toISOString().replace(/[:.]/g, "-"),
  );
  await fs.mkdir(output, { recursive: true });
  await fs.writeFile(
    path.join(output, "inventory.json"),
    JSON.stringify(report, null, 2),
  );
  await fs.writeFile(
    path.join(output, "metadata-to-review.csv"),
    metadataCsv(report),
  );
  console.log(
    JSON.stringify(
      {
        output,
        ...report.summary,
        duplicateGroups: report.duplicateGroups.length,
        fixture: report.fixture,
      },
      null,
      2,
    ),
  );
}
