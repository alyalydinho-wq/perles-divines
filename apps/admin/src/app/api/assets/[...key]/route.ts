import fs from "node:fs/promises";
import path from "node:path";
import { requireAdmin } from "@/lib/auth";
import { AdminError, errorResponse } from "@/lib/security";
const types: Record<string, string> = {
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",
  ".svg": "image/svg+xml",
  ".webp": "image/webp",
  ".css": "text/css",
  ".woff": "font/woff",
  ".woff2": "font/woff2",
  ".ttf": "font/ttf",
};
export async function GET(
  _request: Request,
  context: { params: Promise<{ key: string[] }> },
) {
  try {
    await requireAdmin();
    const key = (await context.params).key;
    if (!process.env.ADMIN_CONTENT_ROOT)
      throw new AdminError("NOT_CONFIGURED", 503);
    if (
      key[0] !== "assets" ||
      key.some(
        (x) =>
          !x || x === "." || x === ".." || x.includes("\\") || x.includes("/"),
      )
    )
      throw new AdminError("NOT_FOUND", 404);
    const mime = types[path.extname(key.at(-1)!).toLowerCase()];
    if (!mime) throw new AdminError("NOT_FOUND", 404);
    const root = await fs.realpath(process.env.ADMIN_CONTENT_ROOT);
    let file: string;
    try {
      file = await fs.realpath(path.join(root, ...key));
    } catch {
      throw new AdminError("NOT_FOUND", 404);
    }
    if (!file.startsWith(root + path.sep))
      throw new AdminError("NOT_FOUND", 404);
    const size = (await fs.stat(file)).size;
    if (size > 64 * 1024 * 1024) throw new AdminError("NOT_FOUND", 404);
    return new Response(new Uint8Array(await fs.readFile(file)), {
      headers: {
        "Content-Type": mime,
        "Cache-Control": "private, no-store",
        "Content-Security-Policy":
          "default-src 'none'; script-src 'none'; style-src 'unsafe-inline'",
      },
    });
  } catch (e) {
    return errorResponse(e);
  }
}
