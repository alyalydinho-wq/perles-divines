import fs from "node:fs/promises";
const uuid = {
  type: "string",
  pattern:
    "^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
};
const title = { type: "string", minLength: 1, maxLength: 500, pattern: "\\S" };
const version = {
  type: "integer",
  minimum: 1,
  maximum: Number.MAX_SAFE_INTEGER,
};
const order = { type: "integer", minimum: 0, maximum: 1000000 };
const nullableId = { anyOf: [uuid, { type: "null" }] };
const description = { type: "string", maxLength: 20000 };
const object = (properties) => ({
  type: "object",
  additionalProperties: false,
  required: Object.keys(properties),
  properties,
});
const array = (items, maxItems = 100000) => ({
  type: "array",
  items,
  maxItems,
});
const resource = object({
  url: { type: "string", maxLength: 2048 },
  sha256: { type: "string", pattern: "^[a-f0-9]{64}$" },
  sizeBytes: { type: "integer", minimum: 1, maximum: 8 * 1024 ** 3 },
  mime: { type: "string", minLength: 1, maxLength: 100 },
});
const media = object({
  ...resource.properties,
  id: uuid,
  version,
  durationMs: { type: "integer", minimum: 1, maximum: 7 * 24 * 3600 * 1000 },
  mime: { const: "audio/mpeg" },
});
const track = object({
  id: uuid,
  title,
  description,
  authorId: nullableId,
  contentVersion: version,
  media,
  themeIds: { ...array(uuid), uniqueItems: true },
});
track.properties.fixture = { type: "boolean" };
const publishedAt = {
  type: "string",
  pattern: "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\.\\d{3})?Z$",
};
const manifest = object({
  schemaVersion: { const: 1 },
  releaseVersion: version,
  publishedAt,
  sections: array(
    object({ id: uuid, title, parentId: nullableId, order }),
    10000,
  ),
  authors: array(object({ id: uuid, name: title })),
  themes: array(object({ id: uuid, name: title })),
  collections: array(object({ id: uuid, title, description })),
  tracks: array(track),
  pages: array(
    object({
      id: uuid,
      title,
      sectionId: nullableId,
      revision: version,
      package: object({
        ...resource.properties,
        mime: { const: "application/zip" },
      }),
    }),
    10000,
  ),
  collectionTracks: array(
    object({ collectionId: uuid, trackId: uuid, order }),
    500000,
  ),
  audioPageLinks: array(object({ trackId: uuid, pageId: uuid })),
  removedTrackIds: { ...array(uuid), uniqueItems: true },
});
await fs.writeFile(
  new URL("./manifest.schema.json", import.meta.url),
  JSON.stringify(
    {
      $schema: "http://json-schema.org/draft-07/schema#",
      $id: "https://perlesdivines.app/schemas/manifest-v1.json",
      ...manifest,
    },
    null,
    2,
  ),
);
await fs.writeFile(
  new URL("./latest.schema.json", import.meta.url),
  JSON.stringify(
    {
      $schema: "http://json-schema.org/draft-07/schema#",
      ...object({
        schemaVersion: { const: 1 },
        releaseVersion: version,
        publishedAt,
        manifest: object({
          ...resource.properties,
          mime: { const: "application/json" },
        }),
      }),
    },
    null,
    2,
  ),
);
