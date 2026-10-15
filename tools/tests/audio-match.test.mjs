import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import { matchAudioToCatalog } from "../audio-match.mjs";

const catalog = [
  { id: "kumayl", title: "Doua-e-Kumayl", kind: "dua" },
  { id: "ahad", title: "Doua-e-Ahad", kind: "dua" },
  { id: "iftetah", title: "Doua-e-Iftetah", kind: "dua" },
  { id: "makarim", title: "Doua-e-Makarimoul-Akhlak", kind: "dua" },
  { id: "amin", title: "Zyaarat-e-Amin-Allàh", kind: "ziyarat" },
  { id: "yasin", title: "Sourate Yâ-Sîn (36)", kind: "quran" },
  { id: "fatema", title: "Zyaarat du Dimanche Imam Ali (as) Sayyada Fatema Zehra (sa)", kind: "ziyarat" },
  { id: "kissa", title: "Hadith-e-Kissa", kind: "dua" },
  { id: "tawassoul", title: "Doua-e-Tawassoul", kind: "dua" },
  { id: "baha", title: "Doua-e-Baha", kind: "dua" },
  { id: "mashlool", title: "Doua-e-Mashlool", kind: "dua" },
  { id: "mujir", title: "Doua-e-Mujir", kind: "dua" },
  { id: "vendredi", title: "Zyaarat du Vendredi (Jum'a) Imam al Mahdi (aj)", kind: "ziyarat" },
  { id: "samedi", title: "Zyaarat du Samedi Prophète Mohammad (saw)", kind: "ziyarat" },
  { id: "jeudi", title: "Zyaarat du Jeudi Imam Hassan al Askari (as)", kind: "ziyarat" },
  { id: "lundi", title: "Zyaarat du Lundi Imam Hassan (as) Imam Houssein (as)", kind: "ziyarat" },
  { id: "ramadan", title: "Aamal du mois de Ramadhan", kind: "aamal" },
  { id: "shabaniya", title: "Mounajat de l'Imam Ali (as)", kind: "dua" },
];

test("associe seulement les noms clairement identifiables, sans inventer de texte", () => {
  assert.equal(matchAudioToCatalog("Doua E Iftitah.m4a.mp4", catalog)?.id, "iftetah");
  assert.equal(matchAudioToCatalog("Doua E Qomel.m4a.mp4", catalog)?.id, "kumayl");
  assert.equal(matchAudioToCatalog("Doua E Ahad.m4a.mp4", catalog)?.id, "ahad");
  assert.equal(matchAudioToCatalog("Doua Maqarimoul Akhlaq.m4a.mp4", catalog)?.id, "makarim");
  assert.equal(matchAudioToCatalog("Ziarat E Aminullah.m4a.mp4", catalog)?.id, "amin");
  assert.equal(matchAudioToCatalog("Hadiçe é Kissà.mp4", catalog)?.id, "kissa");
  assert.equal(matchAudioToCatalog("audio/hadic-e-e-kissa.m4a", catalog)?.id, "kissa");
  assert.equal(matchAudioToCatalog("Douà é Tawassoul.mp4", catalog)?.id, "tawassoul");
  assert.equal(matchAudioToCatalog("Douà é Bahà.m4a.mp4", catalog)?.id, "baha");
  assert.equal(matchAudioToCatalog("Douà é Mashlou.m4a.mp4", catalog)?.id, "mashlool");
  assert.equal(matchAudioToCatalog("Douà é Moudjir.m4a.mp4", catalog)?.id, "mujir");
  assert.equal(matchAudioToCatalog("Ziarat é Imamé Zaman atfs du vendredi.mp4", catalog)?.id, "vendredi");
  assert.equal(matchAudioToCatalog("Ziarat H Mouhammad Moustapha saw.mp4", catalog)?.id, "samedi");
  assert.equal(matchAudioToCatalog("Ziarat Imam Hassan Askari as.m4a.mp4", catalog)?.id, "jeudi");
  assert.equal(matchAudioToCatalog("Doua E Ahlil Qobour.m4a.mp4", catalog), null);
  assert.equal(matchAudioToCatalog("Doua E Hajate.m4a.mp4", catalog), null);
  assert.equal(matchAudioToCatalog("Ziarat E Ale Yassine.m4a.mp4", catalog), null);
  assert.equal(matchAudioToCatalog("Ziarat Fatema Zahra Sa.m4a.mp4", catalog), null);
  assert.equal(matchAudioToCatalog("Ziarat Imam Hassan as.m4a.mp4", catalog), null);
  assert.equal(matchAudioToCatalog("Douà du dimanche.mp4", catalog), null);
  assert.equal(matchAudioToCatalog("Douà 10 Mahé Ramzane.mp4", catalog), null);
  assert.equal(matchAudioToCatalog("Mounajat é Shabaniya.mp4", catalog), null);
});

test("le catalogue embarqué relie chaque texte à son audio déjà publié", () => {
  const texts = JSON.parse(fs.readFileSync("apps/mobile/assets/content/catalog.json", "utf8"));
  const tracks = JSON.parse(fs.readFileSync("apps/mobile/assets/content/audio-catalog.json", "utf8"));
  const byTitle = new Map(texts.map((item) => [item.title, item]));
  const audioId = (title) => tracks.find((track) => track.title === title).id;
  const linked = (textTitle, ...audioTitles) => {
    assert.deepEqual(
      byTitle.get(textTitle).audioIds,
      audioTitles.map(audioId),
    );
  };
  linked("Hadith-e-Kissa", "Hadiçe é Kissà");
  linked("Doua-e-Tawassoul", "Douà é Tawassoul");
  linked("Doua-e-Baha", "Douà é Bahà");
  linked("Doua-e-Mashlool", "Douà é Mashlou");
  linked("Doua-e-Mujir", "Douà é Moudjir");
  linked("Doua-e-Kumayl", "Doua-e-Kumayl");
  linked("Doua-e-Ahad", "Doua-e-Ahad");
  linked("Doua-e-Makarimoul-Akhlak", "Doua-e-Makarimoul-Akhlak");
  const iftetah = byTitle.get("Doua-e-Iftetah");
  assert.deepEqual(
    iftetah.audioIds.map((id) => tracks.find((track) => track.id === id).title),
    ["Doua-e-Iftetah", "Doua-e-Iftetah"],
  );
  linked("Zyaarat-e-Amin-Allàh", "Zyaarat-e-Amin-Allàh");
  linked("Zyaarat du Vendredi (Jum'a) Imam al Mahdi (aj)", "Ziarat é Imamé Zaman atfs du vendredi");
  linked("Zyaarat du Samedi Prophète Mohammad (saw)", "Ziarat H Mouhammad Moustapha saw");
  linked("Zyaarat du Jeudi Imam Hassan al Askari (as)", "Ziarat Imam Hassan Askari as");
  assert.deepEqual(byTitle.get("Doua-e-Nudba").audioIds, []);
  assert.deepEqual(
    byTitle.get("Zyaarat du Dimanche Imam Ali (as) Sayyada Fatema Zehra (sa)").audioIds,
    [],
  );
  assert.deepEqual(
    byTitle.get("Zyaarat du Lundi Imam Hassan (as) Imam Houssein (as)").audioIds,
    [],
  );
});
