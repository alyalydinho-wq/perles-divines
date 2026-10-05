import { DeleteObjectCommand } from "@aws-sdk/client-s3";
import { loadR2Env, r2Client } from "./r2-client.mjs";

const key = process.argv[2];
if (!key) throw new Error("Usage: node tools/delete-r2-object.mjs <key>");
const env = await loadR2Env();
await r2Client(env).send(
  new DeleteObjectCommand({ Bucket: env.R2_BUCKET, Key: key }),
);
console.log(JSON.stringify({ deleted: key }));
