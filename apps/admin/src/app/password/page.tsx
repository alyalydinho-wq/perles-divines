import { redirect } from "next/navigation";
import { requireAdmin } from "@/lib/auth";
import Password from "../ui/password";
export const dynamic = "force-dynamic";
export default async function Page() {
  try {
    await requireAdmin();
  } catch {
    redirect("/");
  }
  return <Password />;
}
