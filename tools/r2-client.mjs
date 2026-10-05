import fs from "node:fs/promises";
import { S3Client } from "@aws-sdk/client-s3";

export async function loadR2Env(file = ".env.r2") {
  const env = Object.fromEntries(
    (await fs.readFile(file, "utf8"))
      .split(/\r?\n/)
      .filter((line) => line && !line.startsWith("#"))
      .map((line) => {
        const i = line.indexOf("=");
        return [line.slice(0, i).trim(), line.slice(i + 1).trim()];
      }),
  );
  for (const key of [
    "R2_ACCOUNT_ID",
    "R2_BUCKET",
    "R2_ACCESS_KEY_ID",
    "R2_SECRET_ACCESS_KEY",
  ]) {
    if (!env[key]) throw new Error(`Missing ${key} in ${file}`);
  }
  env.R2_PUBLIC_URL = (env.R2_PUBLIC_URL || "").replace(/\/+$/, "");
  return env;
}

export function r2Client(env) {
  return new S3Client({
    region: "auto",
    endpoint: `https://${env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
    credentials: {
      accessKeyId: env.R2_ACCESS_KEY_ID,
      secretAccessKey: env.R2_SECRET_ACCESS_KEY,
    },
    requestChecksumCalculation: "WHEN_REQUIRED",
    responseChecksumValidation: "WHEN_REQUIRED",
  });
}

export function publicObjectUrl(env, key) {
  if (!env.R2_PUBLIC_URL) return null;
  return `${env.R2_PUBLIC_URL}/${key}`;
}
