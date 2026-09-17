import { NextResponse } from "next/server";
import { authClient, requireAdmin } from "@/lib/auth";
import { config } from "@/lib/config";
export async function GET(request: Request) {
  const settings = config();
  try {
    const code = new URL(request.url).searchParams.get("code");
    if (!code) throw Error();
    const client = await authClient();
    const result = await client.auth.exchangeCodeForSession(code);
    if (result.error) throw result.error;
    await requireAdmin();
    return NextResponse.redirect(`${settings.origin}/password`);
  } catch {
    return NextResponse.redirect(`${settings.origin}/?access=expired`);
  }
}
