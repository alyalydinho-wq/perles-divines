// Runs in a separate, memory-limited process. No untrusted shell interpolation.
import { parseFile } from "music-metadata";
try {
  const { format, common } = await parseFile(process.argv[2], {
    skipCovers: true,
    skipPostHeaders: true,
    duration: true,
  });
  const codec = format.codec ?? "";
  const container = format.container ?? "";
  const mp3 =
    container === "MPEG" && /^MPEG (?:1|2|2\.5) Layer 3$/.test(codec);
  const mpeg4Audio =
    /M4A|MPEG-4|mp4|isom/i.test(container) && /AAC|ALAC|MPEG-4/i.test(codec);
  if (
    !(mp3 || mpeg4Audio) ||
    !Number.isFinite(format.duration) ||
    format.duration <= 0 ||
    format.hasVideo
  )
    throw Error("INVALID_MEDIA");
  process.stdout.write(
    JSON.stringify({
      durationMs: Math.round(format.duration * 1000),
      sampleRate: format.sampleRate,
      channels: format.numberOfChannels,
      ...(process.argv.includes("--tags")
        ? {
            tags: Object.fromEntries(
              [
                "title",
                "artist",
                "album",
                "albumartist",
                "year",
                "genre",
                "track",
              ].map((key) => {
                const value = common[key] ?? null;
                // Preserve existing tag values as observations, never as approved editorial fields.
                return [
                  key,
                  typeof value === "string"
                    ? value.slice(0, 4000)
                    : Array.isArray(value)
                      ? value.slice(0, 20).map((x) => String(x).slice(0, 500))
                      : value,
                ];
              }),
            ),
          }
        : {}),
    }),
  );
} catch {
  process.stderr.write("INVALID_MEDIA");
  process.exitCode = 1;
}
