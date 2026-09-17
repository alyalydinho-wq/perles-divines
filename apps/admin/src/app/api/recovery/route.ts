import { authClient } from "@/lib/auth";
import { config } from "@/lib/config";
import {
  AdminError,
  assertOrigin,
  errorResponse,
  readJson,
} from "@/lib/security";
export async function POST(request: Request) {
  try {
    const settings = config();
    assertOrigin(request, settings.origin);
    const body = await readJson(request, 5000);
    if (typeof body.email !== "string" || body.email.length > 320)
      throw new AdminError("INVALID_REQUEST", 400);
    const client = await authClient();
    await client.auth.resetPasswordForEmail(body.email, {
      redirectTo: `${settings.origin}/auth/callback`,
    });
    return Response.json({ ok: true });
  } catch (e) {
    return errorResponse(e);
  }
}
