import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { fileURLToPath } from "node:url";
import ffmpeg from "ffmpeg-static";
const run = promisify(execFile);
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
export async function validateMp3(file, expectedDurationMs) {
  try {
    const measured = await inspectMp3(file);
    if (
      expectedDurationMs != null &&
      Math.abs(expectedDurationMs - measured.durationMs) > 1000
    )
      throw Error("DURATION_MISMATCH");
    // Parsing an ID3 header is insufficient: require full decode of the audio frames.
    await run(
      process.env.PERLES_FFMPEG_PATH || ffmpeg,
      [
        "-nostdin",
        "-hide_banner",
        "-loglevel",
        "error",
        "-xerror",
        "-i",
        file,
        "-map",
        "0:a:0",
        "-vn",
        "-f",
        "null",
        "-",
      ],
      { timeout: 120000, maxBuffer: 65536, windowsHide: true },
    );
    return measured;
  } catch (e) {
    if (e.message === "DURATION_MISMATCH") throw e;
    throw Error("INVALID_MEDIA");
  }
}
