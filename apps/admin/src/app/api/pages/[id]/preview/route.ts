import { load } from "cheerio";
import { requireAdmin } from "@/lib/auth";
import { readPage } from "@/lib/pages";
import { errorResponse } from "@/lib/security";
export async function GET(
  _request: Request,
  context: { params: Promise<{ id: string }> },
) {
  try {
    const { client } = await requireAdmin();
    const page = await readPage(client, (await context.params).id);
    // This is a display-only derivative. The canonical revision is never serialized here.
    const $ = load(page.html);
    $("base,script,iframe,object,embed,form").remove();
    $("meta[http-equiv]").remove();
    $("a").each((_, element) => {
      const a = $(element);
      if (!a.attr("href")?.startsWith("#")) a.removeAttr("href");
    });
    $("head").prepend('<base href="/api/assets/pages/">');
    return new Response($.html(), {
      headers: {
        "Content-Type": "text/html; charset=utf-8",
        "Cache-Control": "private, no-store",
        "Content-Security-Policy":
          "default-src 'none'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; font-src 'self'; script-src 'none'; base-uri 'self'; form-action 'none'; frame-ancestors 'self'",
      },
    });
  } catch (e) {
    return errorResponse(e);
  }
}
