import { execFile } from "node:child_process";
import { createHash } from "node:crypto";
import { createReadStream } from "node:fs";
import { promisify } from "node:util";
import { fileURLToPath } from "node:url";

const run = promisify(execFile);

/** Hash a media source without loading the complete file into memory. */
export async function hashFile(file) {
  const hash = createHash("sha256");
  let sizeBytes = 0;
  for await (const chunk of createReadStream(file)) {
    hash.update(chunk);
    sizeBytes += chunk.length;
  }
  return { sha256: hash.digest("hex"), sizeBytes };
}

/** Inspect an MP3 in a memory- and time-bounded child process. */
export async function inspectMp3(file, { tags = false } = {}) {
  try {
    const { stdout } = await run(
      process.execPath,
      [
        "--max-old-space-size=256",
        fileURLToPath(new URL("./probe-media.mjs", import.meta.url)),
        file,
        ...(tags ? ["--tags"] : []),
      ],
      { timeout: 30000, maxBuffer: 65536, windowsHide: true },
    );
    return JSON.parse(stdout);
  } catch {
    throw Error("INVALID_MEDIA");
  }
}
