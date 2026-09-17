export type Resource = {
  url: string;
  sha256: string;
  sizeBytes: number;
  mime: string;
};
export type Media = Resource & {
  id: string;
  version: number;
  durationMs: number;
  mime: "audio/mpeg";
};
export type Section = {
  id: string;
  title: string;
  parentId: string | null;
  order: number;
};
export type Page = {
  id: string;
  title: string;
  sectionId: string | null;
  revision: number;
  package: Resource;
};
export type Track = {
  id: string;
  title: string;
  description: string;
  authorId: string | null;
  contentVersion: number;
  media: Media;
  themeIds: string[];
  fixture?: boolean;
};
export type Manifest = {
  schemaVersion: 1;
  releaseVersion: number;
  publishedAt: string;
  sections: Section[];
  authors: { id: string; name: string }[];
  themes: { id: string; name: string }[];
  collections: { id: string; title: string; description: string }[];
  tracks: Track[];
  pages: Page[];
  collectionTracks: { collectionId: string; trackId: string; order: number }[];
  audioPageLinks: { trackId: string; pageId: string }[];
  removedTrackIds: string[];
};
export type Latest = {
  schemaVersion: 1;
  releaseVersion: number;
  publishedAt: string;
  manifest: Resource;
};
