import "server-only";
import type { SupabaseClient } from "@supabase/supabase-js";
import { AdminError } from "./security";
import { editorView } from "../../../../packages/content-schema/editor.mjs";
export async function readPage(client: SupabaseClient, id: string) {
  if (!/^[a-f0-9-]{36}$/i.test(id)) throw new AdminError("NOT_FOUND", 404);
  const page = await client
    .from("pages")
    .select("id,title,slug,current_revision")
    .eq("id", id)
    .maybeSingle();
  if (page.error) throw page.error;
  if (!page.data) throw new AdminError("NOT_FOUND", 404);
  const revision = await client
    .from("page_revisions")
    .select("html")
    .eq("page_id", id)
    .eq("revision", page.data.current_revision)
    .single();
  if (revision.error) throw revision.error;
  return { ...page.data, html: revision.data.html as string };
}
export function pageView(page: Awaited<ReturnType<typeof readPage>>) {
  return {
    id: page.id,
    title: page.title,
    revision: page.current_revision,
    fragments: editorView(page.html),
  };
}
