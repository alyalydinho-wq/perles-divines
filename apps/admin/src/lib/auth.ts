import "server-only";
import { cookies } from "next/headers";
import { createServerClient } from "@supabase/ssr";
import { createClient } from "@supabase/supabase-js";
import { config } from "./config";
import { AdminError } from "./security";

export async function authClient() {
  const settings = config(),
    jar = await cookies();
  return createServerClient(settings.url, settings.key, {
    cookieOptions: {
      httpOnly: true,
      secure: settings.origin.startsWith("https:"),
      sameSite: "lax",
      path: "/",
    },
    cookies: {
      getAll: () => jar.getAll(),
      setAll(values) {
        try {
          values.forEach(({ name, value, options }) =>
            jar.set(name, value, options),
          );
        } catch {
          /* Server component: refreshed cookies are written by proxy. */
        }
      },
    },
  });
}
export async function requireAdmin() {
  const client = await authClient();
  const {
    data: { user },
    error,
  } = await client.auth.getUser();
  if (error || !user) throw new AdminError("UNAUTHORIZED", 401);
  const membership = await client
    .from("admin_members")
    .select("role,active")
    .eq("user_id", user.id)
    .maybeSingle();
  if (
    membership.error ||
    membership.data?.role !== "owner" ||
    !membership.data.active
  )
    throw new AdminError("FORBIDDEN", 403);
  return { client, user };
}
export function privilegedClient() {
  const c = config();
  return createClient(c.url, c.serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
