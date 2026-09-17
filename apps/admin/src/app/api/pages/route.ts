import { requireAdmin } from "@/lib/auth";
import { errorResponse } from "@/lib/security";
export async function GET() {
  try {
    const { client } = await requireAdmin();
    const result = await client
      .from("pages")
      .select("id,title,current_revision")
      .order("title")
      .limit(10000);
    if (result.error) throw result.error;
    return Response.json({ pages: result.data });
  } catch (e) {
    return errorResponse(e);
  }
}
