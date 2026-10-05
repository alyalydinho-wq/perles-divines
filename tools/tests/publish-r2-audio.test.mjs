import test from "node:test";
import assert from "node:assert/strict";
import { assetName, uniqueAudioKey } from "../publish-r2-audio.mjs";

test("les slugs audio restent stables et désambiguïsés", () => {
  assert.equal(assetName("Doua E Ahad.m4a.mp4"), "doua-e-ahad.m4a");
  const used = new Set();
  assert.equal(
    uniqueAudioKey("Doua E Iftitah.m4a.mp4", "aaaa1111bbbb", used),
    "audio/doua-e-iftitah.m4a",
  );
  assert.equal(
    uniqueAudioKey("Douà é Iftitah.mp4", "cccc2222dddd", used),
    "audio/doua-e-iftitah-cccc2222.m4a",
  );
});
