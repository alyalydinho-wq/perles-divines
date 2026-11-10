import assert from "node:assert/strict";
import test from "node:test";
import { harmonizeAudioTitle } from "../audio-titles.mjs";

test("les titres audio prennent l'orthographe des textes", () => {
  const cases = [
    ["Douà é Tawassoul", "Doua-e-Tawassoul"],
    ["Doua E Ahlil Qobour", "Doua-e-Ahlil Qobour"],
    ["Douà é TAWBÀ", "Doua-e-Tawbà"],
    ["Douà du lundi", "Doua du lundi"],
    ["Douà 10 Mahé Ramzane", "Doua 10 Mahé Ramzane"],
    ["Sehri ni Douà", "Sehri ni Doua"],
    ["Ziarat Imam Ali Raza as", "Zyaarat Imam Ali Raza as"],
    ["Ziarat é Bibi Khadijà sa", "Zyaarat-e-Bibi Khadijà sa"],
    ["Ziarat E Ale Yassine", "Zyaarat-e-Ale Yassine"],
    ["Ziarat H Mouhammad Moustapha saw", "Zyaarat H Mouhammad Moustapha saw"],
    ["Hadiçe é Kissà", "Hadith-e-Kissà"],
    ["Mounajat é Shabaniya", "Mounajat-e-Shabaniya"],
    ["Salàwat é Mahé Shabàne", "Salàwat-e-Mahé Shabàne"],
  ];
  for (const [source, expected] of cases) {
    assert.equal(harmonizeAudioTitle(source), expected, source);
  }
});

test("un titre déjà aligné ne change pas", () => {
  for (const title of [
    "Doua-e-Kumayl",
    "Zyaarat-e-Amin-Allàh",
    "Zyaarat Imam Moussa é Kazim as",
  ]) {
    assert.equal(harmonizeAudioTitle(title), title);
  }
});

test("une liaison au milieu d'un nom propre reste telle quelle", () => {
  assert.equal(
    harmonizeAudioTitle("Ziarat Imam Moussa é Kazim as"),
    "Zyaarat Imam Moussa é Kazim as",
  );
});
