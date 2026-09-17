import "server-only";
import { AdminError } from "./security";
export function configured() {
  return Boolean(
    process.env.ADMIN_ORIGIN &&
    process.env.SUPABASE_URL &&
    process.env.SUPABASE_PUBLISHABLE_KEY &&
    process.env.SUPABASE_SERVICE_ROLE_KEY,
  );
}
export function config() {
  if (!configured()) throw new AdminError("NOT_CONFIGURED", 503);
  const origin = new URL(process.env.ADMIN_ORIGIN!);
  const local = ["127.0.0.1", "localhost", "[::1]"].includes(origin.hostname);
  if (
    origin.username ||
    origin.password ||
    origin.pathname !== "/" ||
    origin.search ||
    origin.hash ||
    (origin.protocol !== "https:" && !(local && origin.protocol === "http:"))
  )
    throw new AdminError("NOT_CONFIGURED", 503);
  return {
    origin: origin.origin,
    url: process.env.SUPABASE_URL!,
    key: process.env.SUPABASE_PUBLISHABLE_KEY!,
    serviceKey: process.env.SUPABASE_SERVICE_ROLE_KEY!,
  };
}
