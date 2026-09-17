import { redirect } from "next/navigation";
import { requireAdmin } from "@/lib/auth";
import { AdminError } from "@/lib/security";
import Editor from "../ui/editor";
export const dynamic = "force-dynamic";
export default async function Admin() {
  try {
    await requireAdmin();
  } catch (e) {
    if (e instanceof AdminError && [401, 403, 503].includes(e.status))
      redirect("/");
    throw e;
  }
  return <Editor />;
}
