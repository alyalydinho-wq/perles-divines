import { authClient, requireAdmin } from "@/lib/auth";
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
    const body = await readJson(request, 10000);
    if (
      typeof body.email !== "string" ||
      body.email.length > 320 ||
      typeof body.password !== "string" ||
      body.password.length > 1024
    )
      throw new AdminError("INVALID_REQUEST", 400);
    const client = await authClient();
    const result = await client.auth.signInWithPassword({
      email: body.email,
      password: body.password,
    });
    if (result.error) throw new AdminError("UNAUTHORIZED", 401);
    try {
      await requireAdmin();
    } catch (e) {
      await client.auth.signOut();
      throw e;
    }
    return Response.json({ ok: true });
  } catch (e) {
    return errorResponse(e);
  }
}
export async function DELETE(request: Request) {
  try {
    assertOrigin(request, config().origin);
    const client = await authClient();
    await client.auth.signOut();
    return Response.json({ ok: true });
  } catch (e) {
    return errorResponse(e);
  }
}
