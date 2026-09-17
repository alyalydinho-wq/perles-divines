import { requireAdmin } from "@/lib/auth";
import { config } from "@/lib/config";
import {
  AdminError,
  assertOrigin,
  errorResponse,
  readJson,
} from "@/lib/security";
export async function POST(request: Request) {
  try {
    assertOrigin(request, config().origin);
    const { client } = await requireAdmin();
    const body = await readJson(request, 10000);
    if (
      typeof body.password !== "string" ||
      body.password.length < 12 ||
      body.password.length > 1024
    )
      throw new AdminError("INVALID_REQUEST", 400);
    const result = await client.auth.updateUser({ password: body.password });
    if (result.error) throw new AdminError("INVALID_PASSWORD", 400);
    return Response.json({ ok: true });
  } catch (e) {
    return errorResponse(e);
  }
}
