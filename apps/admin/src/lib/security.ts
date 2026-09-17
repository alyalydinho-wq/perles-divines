export class AdminError extends Error {
  code: string;
  status: number;
  constructor(code: string, status: number) {
    super(code);
    this.code = code;
    this.status = status;
  }
}
export function assertOrigin(request: Request, origin: string) {
  if (
    request.headers.get("origin") !== origin ||
    request.headers.get("sec-fetch-site") === "cross-site"
  )
    throw new AdminError("FORBIDDEN", 403);
}
export async function readJson(request: Request, maxBytes = 500000) {
  if (!request.headers.get("content-type")?.startsWith("application/json"))
    throw new AdminError("INVALID_REQUEST", 415);
  const reader = request.body?.getReader();
  if (!reader) throw new AdminError("INVALID_REQUEST", 400);
  const chunks: Uint8Array[] = [];
  let size = 0;
  try {
    while (true) {
      const part = await reader.read();
      if (part.done) break;
      size += part.value.length;
      if (size > maxBytes) throw new AdminError("REQUEST_TOO_LARGE", 413);
      chunks.push(part.value);
    }
  } finally {
    await reader.cancel();
  }
  try {
    const value = JSON.parse(Buffer.concat(chunks).toString("utf8"));
    if (value === null || typeof value !== "object" || Array.isArray(value))
      throw Error();
    return value;
  } catch {
    throw new AdminError("INVALID_REQUEST", 400);
  }
}
export function errorResponse(error: unknown) {
  const known = error instanceof AdminError;
  // Do not send credentials, provider errors, SQL or stack traces to a browser.
  return Response.json(
    { error: known ? error.code : "TEMPORARY_FAILURE" },
    {
      status: known ? error.status : 500,
      headers: { "Cache-Control": "no-store" },
    },
  );
}
