import http from "node:http";
import fs from "node:fs/promises";
import { createReadStream } from "node:fs";
import { pipeline } from "node:stream/promises";
import path from "node:path";
import { hashFile, safeKey } from "./publish.mjs";

export function createPublicationServer(directory) {
  const cache = new Map();
  return http.createServer(async (req, res) => {
    try {
      if (!["GET", "HEAD"].includes(req.method)) {
        res.writeHead(405, { Allow: "GET, HEAD" }).end();
        return;
      }
      const key = decodeURIComponent(
        new URL(req.url, "http://localhost").pathname.slice(1),
      );
      if (
        !/^(latest\.json|releases\/[1-9]\d*\/manifest\.json|media\/[a-f0-9-]{36}\/[1-9]\d*\.mp3)$/.test(
          key,
        )
      ) {
        res.writeHead(404).end();
        return;
      }
      const root = await fs.realpath(directory),
        file = await fs.realpath(safeKey(root, key));
      if (!file.startsWith(root + path.sep)) {
        res.writeHead(404).end();
        return;
      }
      const stat = await fs.stat(file);
      const cacheKey = `${file}:${stat.size}:${stat.mtimeMs}`;
      let hash = cache.get(cacheKey);
      if (!hash) {
        hash = (await hashFile(file)).sha256;
        if (cache.size > 10000) cache.clear();
        cache.set(cacheKey, hash);
      }
      const etag = `"${hash}"`;
      res.setHeader("ETag", etag);
      res.setHeader("Accept-Ranges", "bytes");
      res.setHeader("X-Content-Type-Options", "nosniff");
      res.setHeader(
        "Content-Type",
        key.endsWith(".mp3") ? "audio/mpeg" : "application/json; charset=utf-8",
      );
      res.setHeader(
        "Cache-Control",
        key === "latest.json"
          ? "public, max-age=0, must-revalidate"
          : "public, max-age=31536000, immutable",
      );
      if (
        req.headers["if-none-match"]
          ?.split(",")
          .some(
            (e) => e.trim().replace(/^W\//, "") === etag || e.trim() === "*",
          )
      ) {
        res.writeHead(304).end();
        return;
      }
      let start = 0,
        end = stat.size - 1,
        status = 200;
      if (
        req.method === "GET" &&
        req.headers.range &&
        (!req.headers["if-range"] || req.headers["if-range"] === etag)
      ) {
        const match = /^bytes=(\d*)-(\d*)$/.exec(req.headers.range);
        if (!match || (!match[1] && !match[2])) {
          res.writeHead(416, { "Content-Range": `bytes */${stat.size}` }).end();
          return;
        }
        if (!match[1]) start = Math.max(0, stat.size - Number(match[2]));
        else {
          start = Number(match[1]);
          if (match[2]) end = Math.min(end, Number(match[2]));
        }
        if (
          !Number.isSafeInteger(start) ||
          !Number.isSafeInteger(end) ||
          start > end ||
          start >= stat.size
        ) {
          res.writeHead(416, { "Content-Range": `bytes */${stat.size}` }).end();
          return;
        }
        status = 206;
        res.setHeader("Content-Range", `bytes ${start}-${end}/${stat.size}`);
      }
      res.writeHead(status, { "Content-Length": end - start + 1 });
      if (req.method === "HEAD") res.end();
      else await pipeline(createReadStream(file, { start, end }), res);
    } catch {
      if (res.headersSent) res.destroy();
      else res.writeHead(404).end();
    }
  });
}
