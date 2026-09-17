import fs from "node:fs/promises";
import { createReadStream } from "node:fs";
import path from "node:path";
import { createHash, randomUUID } from "node:crypto";
import {
  validateManifest,
  resourcesOf,
} from "../../packages/content-schema/runtime.mjs";
import { validateMp3 } from "./media.mjs";
export async function hashFile(file) {
  const hash = createHash("sha256");
  let size = 0;
  for await (const chunk of createReadStream(file)) {
    hash.update(chunk);
    size += chunk.length;
  }
  return { sha256: hash.digest("hex"), sizeBytes: size };
}
export function safeKey(root, key) {
  if (
    !key ||
    key.includes("\\") ||
    key.split("/").some((x) => ["..", ".", ""].includes(x)) ||
    path.isAbsolute(key)
  )
    throw Error("UNSAFE_KEY");
  const result = path.resolve(root, key);
  if (!result.startsWith(path.resolve(root) + path.sep))
    throw Error("UNSAFE_KEY");
  return result;
}
export class LocalObjects {
  constructor(root) {
    this.root = path.resolve(root);
  }
  async putFile(key, source, expected) {
    const destination = safeKey(this.root, key);
    await fs.mkdir(path.dirname(destination), { recursive: true });
    try {
      const existing = await hashFile(destination);
      if (
        existing.sha256 === expected.sha256 &&
        existing.sizeBytes === expected.sizeBytes
      )
        return;
      throw Error("IMMUTABLE_CONFLICT");
    } catch (e) {
      if (e.code !== "ENOENT") throw e;
    }
    const temp = `${destination}.${randomUUID()}.tmp`;
    try {
      await fs.copyFile(source, temp);
      const actual = await hashFile(temp);
      if (
        actual.sha256 !== expected.sha256 ||
        actual.sizeBytes !== expected.sizeBytes
      )
        throw Error("INTEGRITY_ERROR");
      try {
        await fs.link(temp, destination);
      } catch (e) {
        if (e.code !== "EEXIST") throw e;
        const concurrent = await hashFile(destination);
        if (
          concurrent.sha256 !== expected.sha256 ||
          concurrent.sizeBytes !== expected.sizeBytes
        )
          throw Error("IMMUTABLE_CONFLICT");
      }
    } finally {
      await fs.rm(temp, { force: true });
    }
  }
  async putJson(key, value) {
    const bytes = Buffer.from(JSON.stringify(value));
    const hash = createHash("sha256").update(bytes).digest("hex");
    const destination = safeKey(this.root, key);
    await fs.mkdir(path.dirname(destination), { recursive: true });
    try {
      await fs.writeFile(destination, bytes, { flag: "wx" });
    } catch (e) {
      if (e.code !== "EEXIST") throw e;
      if ((await hashFile(destination)).sha256 !== hash)
        throw Error("IMMUTABLE_CONFLICT");
    }
    return { sha256: hash, sizeBytes: bytes.length, mime: "application/json" };
  }
  async latest() {
    try {
      return JSON.parse(
        await fs.readFile(path.join(this.root, "latest.json"), "utf8"),
      );
    } catch (e) {
      if (e.code === "ENOENT") return null;
      throw e;
    }
  }
  async point(latest, expectedVersion) {
    const current = await this.latest();
    if ((current?.releaseVersion ?? 0) !== expectedVersion)
      throw Error("POINTER_CONFLICT");
    const temp = path.join(this.root, `latest.${randomUUID()}.tmp`);
    await fs.writeFile(temp, JSON.stringify(latest), { flag: "wx" });
    await fs.rename(temp, path.join(this.root, "latest.json"));
  }
}
export async function publish(
  job,
  jobs,
  objects,
  options,
  { afterPointer = async () => {} } = {},
) {
  const snapshot = job.snapshot;
  const manifest = { ...snapshot.manifest, releaseVersion: job.version };
  validateManifest(manifest, options);
  // Page-package verification is a separate milestone. Fail closed until implemented.
  if (manifest.pages.length) throw Error("PAGE_PACKAGES_NOT_IMPLEMENTED");
  const current = await objects.latest();
  if (current?.releaseVersion === job.version) {
    const expected = await objects.putJson(
      `releases/${job.version}/manifest.json`,
      manifest,
    );
    if (expected.sha256 !== current.manifest.sha256)
      throw Error("POINTER_MISMATCH");
    jobs.complete(job);
    return current;
  }
  if ((current?.releaseVersion ?? 0) > job.version)
    throw Error("VERSION_REGRESSION");
  const sources = new Map(snapshot.files.map((f) => [f.url, f]));
  for (const resource of resourcesOf(manifest)) {
    const source = sources.get(resource.url);
    if (!source) throw Error("ASSET_MISSING");
    jobs.heartbeat(job.owner);
    const input = await fs.realpath(
      safeKey(options.inputRoot, source.relativePath),
    );
    const inputRoot = await fs.realpath(options.inputRoot);
    if (!input.startsWith(inputRoot + path.sep)) throw Error("UNSAFE_KEY");
    const actual = await hashFile(input);
    if (
      actual.sha256 !== resource.sha256 ||
      actual.sizeBytes !== resource.sizeBytes
    )
      throw Error("INTEGRITY_ERROR");
    await validateMp3(input, resource.durationMs);
    const key = decodeURIComponent(new URL(resource.url).pathname.slice(1));
    await objects.putFile(key, input, resource);
  }
  jobs.assertLease(job.owner);
  const reference = await objects.putJson(
    `releases/${job.version}/manifest.json`,
    manifest,
  );
  const latest = {
    schemaVersion: 1,
    releaseVersion: job.version,
    publishedAt: manifest.publishedAt,
    manifest: {
      url: `${options.publicOrigin}/releases/${job.version}/manifest.json`,
      ...reference,
    },
  };
  // Local driver uses one lease holder; storage pointer changes only after all objects exist.
  await jobs.commitPointer(job, async () => {
    await objects.point(latest, current?.releaseVersion ?? 0);
    await afterPointer();
  });
  return latest;
}
