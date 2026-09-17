import { requireAdmin, privilegedClient } from "@/lib/auth";
import { config } from "@/lib/config";
import {
  AdminError,
  assertOrigin,
  errorResponse,
  readJson,
} from "@/lib/security";
import { readPage, pageView } from "@/lib/pages";
import { replaceFragment } from "../../../../../../../packages/content-schema/editor.mjs";
type Context = { params: Promise<{ id: string }> };
export async function GET(_request: Request, context: Context) {
  try {
    const { client } = await requireAdmin();
    return Response.json(
      pageView(await readPage(client, (await context.params).id)),
    );
  } catch (e) {
    return errorResponse(e);
  }
}
export async function POST(request: Request, context: Context) {
  try {
    assertOrigin(request, config().origin);
    const { client, user } = await requireAdmin();
    const body = await readJson(request);
    if (
      !Number.isInteger(body.expectedRevision) ||
      typeof body.fragmentId !== "string" ||
      typeof body.text !== "string"
    )
      throw new AdminError("INVALID_REQUEST", 400);
    const page = await readPage(client, (await context.params).id);
    if (page.current_revision !== body.expectedRevision)
      throw new AdminError("REVISION_CONFLICT", 409);
    let html: string;
    try {
      html = replaceFragment(page.html, body.fragmentId, body.text);
    } catch {
      throw new AdminError("INVALID_FRAGMENT", 400);
    }
    if (html === page.html) return Response.json(pageView(page));
    const result = await privilegedClient().rpc("save_page_revision", {
      actor: user.id,
      target: page.id,
      expected_revision: page.current_revision,
      new_html: html,
    });
    if (result.error) {
      if (result.error.code === "40001")
        throw new AdminError("REVISION_CONFLICT", 409);
      if (result.error.code === "42501") throw new AdminError("FORBIDDEN", 403);
      throw result.error;
    }
    return Response.json(
      pageView({ ...page, html, current_revision: result.data as number }),
    );
  } catch (e) {
    return errorResponse(e);
  }
}
