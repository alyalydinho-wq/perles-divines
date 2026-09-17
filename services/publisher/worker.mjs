import fs from "node:fs/promises";
import path from "node:path";
import { randomUUID } from "node:crypto";
import { fileURLToPath } from "node:url";
import { LocalJobs } from "./local-store.mjs";
import { LocalObjects, publish } from "./publish.mjs";
const projectRoot = fileURLToPath(new URL("../../", import.meta.url));
const root = path.join(projectRoot, "content/development");
await fs.mkdir(root, { recursive: true });
const jobs = new LocalJobs(root),
  objects = new LocalObjects(path.join(root, "public"));
const options = {
  development: true,
  allowedOrigins: ["http://127.0.0.1:4175"],
  publicOrigin: "http://127.0.0.1:4175",
  inputRoot: path.join(projectRoot, "content/fixtures"),
};
const owner = randomUUID();
let stopped = false;
process.on("SIGINT", () => {
  stopped = true;
});
process.on("SIGTERM", () => {
  stopped = true;
});
console.log(
  "Worker de développement local. Aucun accès au site, à Supabase ou R2.",
);
while (!stopped) {
  const job = jobs.claim(owner);
  if (job) {
    const renewal = setInterval(() => {
      try {
        jobs.heartbeat(owner);
      } catch {
        /* Commit verifies the lease again and refuses a stale worker. */
      }
    }, 30000);
    try {
      const result = await publish(job, jobs, objects, options);
      console.log(`Publication locale ${result.releaseVersion} prête.`);
    } catch (e) {
      try {
        jobs.fail(job, e.message);
      } catch {}
      console.error(`Tâche ${job.id} : ${e.message}`);
    } finally {
      clearInterval(renewal);
    }
  } else if (process.argv.includes("--once")) break;
  else await new Promise((r) => setTimeout(r, 1000));
  if (process.argv.includes("--once")) break;
}
jobs.close();
