import fs from "node:fs";
import Ajv from "ajv";
const ajv = new Ajv({ allErrors: true, strict: true });
const schemas = Object.fromEntries(
  ["manifest", "latest"].map((name) => [
    name,
    JSON.parse(
      fs.readFileSync(
        new URL(`./${name}.schema.json`, import.meta.url),
        "utf8",
      ),
    ),
  ]),
);
const validators = Object.fromEntries(
  Object.entries(schemas).map(([name, schema]) => [name, ajv.compile(schema)]),
);
export class ContentError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "ContentError";
    this.code = code;
  }
}
export function validateResource(
  resource,
  { allowedOrigins, development = false },
) {
  let url;
  try {
    url = new URL(resource.url);
  } catch {
    throw new ContentError("INVALID_URL", "Adresse de ressource invalide.");
  }
  const local = ["localhost", "127.0.0.1", "[::1]"].includes(url.hostname);
  if (
    url.username ||
    url.password ||
    url.hash ||
    url.search ||
    !allowedOrigins.includes(url.origin) ||
    (url.protocol !== "https:" &&
      !(development && local && url.protocol === "http:")) ||
    (!development &&
      (local ||
        url.hostname.endsWith(".invalid") ||
        url.hostname.endsWith(".r2.dev") ||
        url.hostname === "example.com"))
  ) {
    throw new ContentError(
      "UNTRUSTED_ORIGIN",
      "Domaine ou adresse de ressource non autorisé.",
    );
  }
  if (
    !/^[a-f0-9]{64}$/.test(resource.sha256) ||
    /^0{64}$/.test(resource.sha256)
  )
    throw new ContentError("INVALID_HASH", "Empreinte absente ou fictive.");
  return resource;
}
export function resourcesOf(manifest) {
  return [
    ...manifest.tracks.map((t) => t.media),
    ...manifest.pages.map((p) => p.package),
  ];
}
function validateShape(kind, value) {
  if (!validators[kind](value))
    throw new ContentError(
      "INVALID_SCHEMA",
      `Publication non conforme : ${ajv.errorsText(validators[kind].errors)}`,
    );
  if (
    !Number.isFinite(Date.parse(value.publishedAt)) ||
    new Date(value.publishedAt).toISOString().replace(".000Z", "Z") !==
      value.publishedAt.replace(".000Z", "Z")
  )
    throw new ContentError("INVALID_DATE", "Date de publication invalide.");
}
export function validateLatest(value, options) {
  validateShape("latest", value);
  validateResource(value.manifest, options);
  if (
    new URL(value.manifest.url).pathname !==
    `/releases/${value.releaseVersion}/manifest.json`
  )
    throw new ContentError(
      "INVALID_OBJECT_KEY",
      "Chemin de manifeste incohérent.",
    );
  return value;
}
export function validateManifest(value, options) {
  validateShape("manifest", value);
  const ids = {};
  for (const kind of [
    "sections",
    "authors",
    "themes",
    "collections",
    "tracks",
    "pages",
  ]) {
    ids[kind] = new Set();
    for (const item of value[kind]) {
      if (ids[kind].has(item.id))
        throw new ContentError(
          "DUPLICATE_ID",
          `Identifiant en double : ${kind}`,
        );
      ids[kind].add(item.id);
    }
  }
  const ref = (kind, id) => {
    if (id != null && !ids[kind].has(id))
      throw new ContentError(
        "MISSING_REFERENCE",
        `Référence absente : ${kind}`,
      );
  };
  const parents = new Map(value.sections.map((s) => [s.id, s.parentId]));
  for (const section of value.sections) {
    ref("sections", section.parentId);
    const seen = new Set([section.id]);
    let parent = section.parentId;
    while (parent) {
      if (seen.has(parent))
        throw new ContentError("SECTION_CYCLE", "Cycle de rubriques.");
      seen.add(parent);
      parent = parents.get(parent);
    }
  }
  for (const page of value.pages) {
    ref("sections", page.sectionId);
    if (
      new URL(page.package.url).pathname !==
      `/pages/${page.id}/${page.revision}/package.zip`
    )
      throw new ContentError(
        "INVALID_OBJECT_KEY",
        "Chemin de paquet incohérent.",
      );
  }
  for (const track of value.tracks) {
    if (track.fixture && !options.development)
      throw new ContentError(
        "FIXTURE_REFUSED",
        "Les fixtures ne sont pas publiables en production.",
      );
    ref("authors", track.authorId);
    for (const theme of track.themeIds) ref("themes", theme);
    if (
      new URL(track.media.url).pathname !==
      `/media/${track.media.id}/${track.media.version}.mp3`
    )
      throw new ContentError(
        "INVALID_OBJECT_KEY",
        "Chemin de média incohérent.",
      );
  }
  const unique = (items, key) => {
    const seen = new Set();
    for (const item of items) {
      const id = key(item);
      if (seen.has(id))
        throw new ContentError("DUPLICATE_RELATION", "Relation en double.");
      seen.add(id);
    }
  };
  for (const item of value.collectionTracks) {
    ref("collections", item.collectionId);
    ref("tracks", item.trackId);
  }
  unique(value.collectionTracks, (x) => `${x.collectionId}/${x.trackId}`);
  unique(value.collectionTracks, (x) => `${x.collectionId}/${x.order}`);
  for (const item of value.audioPageLinks) {
    ref("pages", item.pageId);
    ref("tracks", item.trackId);
  }
  unique(value.audioPageLinks, (x) => `${x.pageId}/${x.trackId}`);
  for (const id of value.removedTrackIds)
    if (ids.tracks.has(id))
      throw new ContentError(
        "ACTIVE_AND_REMOVED",
        "Une piste ne peut pas être publiée et retirée simultanément.",
      );
  for (const resource of resourcesOf(value))
    validateResource(resource, options);
  return value;
}
