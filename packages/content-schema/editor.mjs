import { parse } from "parse5";
import { createHash } from "node:crypto";

const preserved = new Set([
  "head",
  "script",
  "style",
  "svg",
  "math",
  "template",
  "noscript",
  "textarea",
  "title",
]);
const hash = (value) => createHash("sha256").update(value).digest("hex");
const escapeText = (value) =>
  value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");

// Source locations let us replace one text node without serializing its ancestors.
// Images, attributes, whitespace, tables and all other bytes remain untouched.
export function editableFragments(html) {
  if (Buffer.byteLength(html, "utf8") > 5 * 1024 * 1024)
    throw Error("DOCUMENT_TOO_LARGE");
  const result = [];
  function visit(node, blocked = false, label = "Texte") {
    blocked ||=
      preserved.has(node.tagName) ||
      node.attrs?.some(
        (a) =>
          a.name === "hidden" ||
          a.name === "data-preserved" ||
          (a.name === "aria-hidden" && a.value === "true"),
      );
    if (node.tagName && /^(h[1-6]|p|li|td|th|caption|a)$/.test(node.tagName))
      label = node.tagName;
    if (
      !blocked &&
      node.nodeName === "#text" &&
      node.value.trim() &&
      node.sourceCodeLocation
    ) {
      const { startOffset: start, endOffset: end } = node.sourceCodeLocation;
      const raw = html.slice(start, end);
      result.push({
        id: hash(`${start}:${end}:${raw}`),
        text: node.value,
        label,
        start,
        end,
      });
    }
    for (const child of node.childNodes ?? []) visit(child, blocked, label);
  }
  visit(parse(html, { sourceCodeLocationInfo: true }));
  return result;
}

export function replaceFragment(html, id, text) {
  if (typeof text !== "string" || text.length > 100000 || text.includes("\0"))
    throw Error("INVALID_TEXT");
  const fragment = editableFragments(html).find((f) => f.id === id);
  if (!fragment) throw Error("FRAGMENT_CONFLICT");
  if (fragment.text === text) return html;
  return (
    html.slice(0, fragment.start) + escapeText(text) + html.slice(fragment.end)
  );
}

export function editorView(html) {
  return editableFragments(html).map(({ id, text, label }) => ({
    id,
    text,
    label,
  }));
}
