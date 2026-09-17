import test from "node:test";
import assert from "node:assert/strict";
import { load } from "cheerio";
import {
  resolveUrl,
  decode,
  inspectHtml,
  rewriteCss,
  normalizeHtml,
  localPath,
  stableId,
} from "../import-site/content.mjs";

test("URL : casse, ancre, déduplication et frontière des hôtes", () => {
  const r = resolveUrl(
    "../Quran.html#arabe",
    "http://www.perlesdivines.fr/fr/a.html",
  );
  assert.equal(r.url, "https://www.perlesdivines.fr/Quran.html");
  assert.equal(r.fragment, "#arabe");
  assert.equal(
    resolveUrl("https://www.perlesdivines.fr.evil.test/a", r.url).internal,
    false,
  );
  assert.equal(resolveUrl("javascript:alert(1)", r.url), null);
  assert.equal(
    resolveUrl("https://user:secret@perlesdivines.fr/a", r.url),
    null,
  );
  assert.notEqual(stableId("A"), stableId("a"));
});
test("Les octets ISO-8859-1 sont décodés sans modifier les accents", () => {
  assert.equal(
    decode(Buffer.from([0xe9, 0xe0]), "text/html; charset=iso-8859-1").text,
    "éà",
  );
  assert.throws(
    () => decode(Buffer.from([0xff]), "text/html; charset=utf-8"),
    /remplacement/,
  );
});
test("HTML, srcset et CSS imbriquée inventorient les dépendances", () => {
  const audit = inspectHtml(
    '<img src="a.gif" srcset="b.png 2x, c.png 3x"><style>@import "a.css"; p{background:url(d.png)}</style><a href="x.html#z">texte</a>',
    "https://www.perlesdivines.fr/",
  );
  for (const p of ["a.gif", "b.png", "c.png", "a.css", "d.png", "x.html"])
    assert(
      audit.dependencies.some((d) => d.url.endsWith(p)),
      p,
    );
});
test("Nettoyage : conserve arabe, traduction, références et ancres ; retire le code et réseau distant", () => {
  const record = {
    url: "https://www.perlesdivines.fr/a.html",
    kind: "html",
    anchors: ["ar"],
  };
  record.localPath = localPath(record);
  const image = {
    url: "https://www.perlesdivines.fr/arabe.gif",
    kind: "asset",
  };
  image.localPath = localPath(image);
  const html =
    '<html><head><script>fetch("https://evil.test")</script></head><body onload="evil()"><p id="ar" lang="ar" dir="rtl">بِسْمِ اللَّهِ</p><p>Traduction inchangée — Réf. 1:1</p><img src="arabe.gif"><img src="https://evil.test/pixel"><iframe src="https://evil.test"></iframe><a href="#ar" onclick="evil()">Arabe</a><a href="javascript:evil()">piège</a><div style="background:url(https://evil.test/x)"></div></body></html>';
  const $ = load(
    normalizeHtml(
      html,
      record,
      new Map([
        [record.url, record],
        [image.url, image],
      ]),
    ),
  );
  assert.equal($("script,iframe,[onload],[onclick]").length, 0);
  assert.equal($("[lang=ar]").text(), "بِسْمِ اللَّهِ");
  assert.equal($("[lang=ar]").attr("dir"), "rtl");
  assert($("body").text().includes("Traduction inchangée — Réf. 1:1"));
  assert.equal($("img[src^=https]").length, 0);
  assert.equal($("a[href^=javascript]").length, 0);
  assert($("a").first().attr("href").endsWith("#ar"));
});
test("CSS : aucune sous-ressource distante ni expression exécutable", () => {
  const css = rewriteCss(
    '@import "https://evil.test/e.css"; p{background:url(https://evil.test/x);color:green; width:expression(evil());behavior:url(x)}',
    () => null,
  );
  assert(!/evil|expression|behavior|@import/.test(css));
  assert(css.includes("color:green"));
});
test("Une page absente devient une destination explicite", () => {
  const r = { url: "https://www.perlesdivines.fr/a.html", kind: "html" };
  const $ = load(
    normalizeHtml('<a href="missing.html">Texte</a>', r, new Map()),
  );
  assert($("a").attr("href").startsWith("../unavailable.html?source="));
});
