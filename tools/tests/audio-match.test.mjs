import test from "node:test";
import assert from "node:assert/strict";
import { matchAudioToCatalog } from "../audio-match.mjs";

const catalog = [
  { id: "kumayl", title: "Doua-e-Kumayl", kind: "dua" },
  { id: "ahad", title: "Doua-e-Ahad", kind: "dua" },
  { id: "iftetah", title: "Doua-e-Iftetah", kind: "dua" },
  { id: "makarim", title: "Doua-e-Makarimoul-Akhlak", kind: "dua" },
  { id: "amin", title: "Zyaarat-e-Amin-Allàh", kind: "ziyarat" },
  { id: "yasin", title: "Sourate Yâ-Sîn (36)", kind: "quran" },
  { id: "fatema", title: "Zyaarat du Dimanche Imam Ali (as) Sayyada Fatema Zehra (sa)", kind: "ziyarat" },
];

test("associe seulement les noms clairement identifiables, sans inventer de texte", () => {
  assert.equal(matchAudioToCatalog("Doua E Iftitah.m4a.mp4", catalog)?.id, "iftetah");
  assert.equal(matchAudioToCatalog("Doua E Qomel.m4a.mp4", catalog)?.id, "kumayl");
  assert.equal(matchAudioToCatalog("Doua E Ahad.m4a.mp4", catalog)?.id, "ahad");
  assert.equal(matchAudioToCatalog("Doua Maqarimoul Akhlaq.m4a.mp4", catalog)?.id, "makarim");
  assert.equal(matchAudioToCatalog("Ziarat E Aminullah.m4a.mp4", catalog)?.id, "amin");
  assert.equal(matchAudioToCatalog("Doua E Ahlil Qobour.m4a.mp4", catalog), null);
  assert.equal(matchAudioToCatalog("Doua E Hajate.m4a.mp4", catalog), null);
  assert.equal(matchAudioToCatalog("Ziarat E Ale Yassine.m4a.mp4", catalog), null);
  assert.equal(matchAudioToCatalog("Ziarat Fatema Zahra Sa.m4a.mp4", catalog), null);
});
