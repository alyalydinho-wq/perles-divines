import fs from 'node:fs/promises';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import * as cheerio from 'cheerio';

/// Transforme les pages d'origine (HTML du site) en blocs que l'application
/// affiche sans WebView : paragraphes, images, boutons, rangées et repères.
///
/// Format d'un bloc (clés courtes, le fichier est embarqué) :
/// - `{p: [span], a, d, ar, k}` paragraphe ; `a` alignement (c, j, l, r ; c par
///   défaut, comme le `text-align: center` du site), `d: 'rtl'`, `ar: 1` pour
///   de l'arabe en texte, `k` repères (`<a name>`) posés sur ce bloc ;
/// - span `{t, b, i, u, c, s, h}` : texte, gras, italique, souligné, couleur
///   `#rrggbb`, taille en points (14 par défaut), lien ;
/// - `{img, iw, ih, w, f, a, h, k}` image de `assets/pages/`, taille d'origine
///   `iw`×`ih`, largeur voulue en pixels `w` ou en fraction `f` ;
/// - `{button, green, h}`, `{hr: 1}`, `{gap: n}` (n demi-lignes),
///   `{row: [[bloc]]}` cellules d'un tableau de mise en page.
///
/// Un lien `h` vaut `sommaire`, `#ancre` (même page), `page:<id>[#ancre]`
/// (texte du catalogue ou autre page d'origine) ou une adresse externe.
/// Un lien qui ne mène nulle part dans l'application est retiré.

/// Ancien sommaire (`sommaire.html`) et ancienne page d'accueil (`index.html`).
export const legacySommairePageIds = new Set([
  '1af50233-0b26-5c4b-993e-c96c078fdb46',
  '386bba3e-88c0-5136-bd4e-8215613a7064',
]);

const uuid = '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}';
const pageHref = new RegExp(`(?:^|/)(${uuid})\\.html(?:#(.*))?$`, 'i');
const imageSrc = new RegExp(`(${uuid}\\.(?:gif|png|jpe?g|webp))$`, 'i');
const legacySitePaths = new Set(['/', '/index.html', '/sommaire.html', '/fr', '/fr/index.html', '/fr/sommaire.html']);

/// Vrai pour le sommaire ou l'accueil du site en ligne.
export function isLegacySommaireUrl(href) {
  let url;
  try {
    url = new URL(href);
  } catch {
    return false;
  }
  if (!['http:', 'https:'].includes(url.protocol)) return false;
  if (!['perlesdivines.fr', 'www.perlesdivines.fr'].includes(url.hostname.toLowerCase())) return false;
  const name = url.pathname.split('/').pop().toLowerCase();
  if (name === 'index.html' || name === 'sommaire.html') return true;
  const trimmed = url.pathname.length > 1 ? url.pathname.replace(/\/$/, '') : url.pathname;
  return legacySitePaths.has(trimmed.toLowerCase());
}

const sizeClasses = {tb: 18, tg: 16, tm: 10, tp: 8};
const blockTags = new Set(['p', 'div', 'center', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'ul', 'ol', 'li', 'blockquote', 'tbody', 'thead', 'tr', 'form']);
const skippedTags = new Set(['script', 'style', 'head', 'title', 'meta', 'link', 'iframe', 'noscript']);

function hex(color) {
  const value = color?.trim().toLowerCase();
  if (!value) return undefined;
  if (/^#[0-9a-f]{6}$/.test(value)) return value;
  if (/^#[0-9a-f]{3}$/.test(value)) return `#${[...value.slice(1)].map((c) => c + c).join('')}`;
  return {black: '#000000', white: '#ffffff', red: '#ff0000', green: '#008000', blue: '#0000ff', maroon: '#800000', navy: '#000080', purple: '#800080'}[value];
}

function cssDeclarations(style) {
  const out = {};
  for (const part of (style ?? '').split(';')) {
    const [name, ...rest] = part.split(':');
    if (!name || !rest.length) continue;
    out[name.trim().toLowerCase()] = rest.join(':').trim().toLowerCase();
  }
  return out;
}

function alignOf(value) {
  switch ((value ?? '').toLowerCase()) {
    case 'center': case 'middle': return 'c';
    case 'justify': return 'j';
    case 'left': return 'l';
    case 'right': return 'r';
    default: return undefined;
  }
}

/// Largeur et hauteur d'une image GIF ou PNG, lues dans son en-tête.
export function imageSize(bytes) {
  if (bytes.length >= 10 && bytes.toString('latin1', 0, 3) === 'GIF') {
    return {width: bytes.readUInt16LE(6), height: bytes.readUInt16LE(8)};
  }
  if (bytes.length >= 24 && bytes.readUInt32BE(0) === 0x89504e47) {
    return {width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20)};
  }
  if (bytes.length >= 30 && bytes.toString('latin1', 0, 4) === 'RIFF' && bytes.toString('latin1', 8, 12) === 'WEBP') {
    const chunk = bytes.toString('latin1', 12, 16);
    if (chunk === 'VP8L') {
      const bits = bytes.readUInt32LE(21);
      return {width: (bits & 0x3fff) + 1, height: ((bits >> 14) & 0x3fff) + 1};
    }
    if (chunk === 'VP8X') {
      return {width: 1 + bytes.readUIntLE(24, 3), height: 1 + bytes.readUIntLE(27, 3)};
    }
    if (chunk === 'VP8 ') {
      return {width: bytes.readUInt16LE(26) & 0x3fff, height: bytes.readUInt16LE(28) & 0x3fff};
    }
  }
  throw new Error('Format d’image inconnu');
}

const sameStyle = (a, b) => ['b', 'i', 'u', 'c', 's', 'h'].every((k) => a[k] === b[k]);

/// Convertit le `<body>` d'une page en blocs.
///
/// [resolveLink] reçoit l'attribut `href` et rend le lien de l'application
/// (ou `undefined`) ; [imageOf] reçoit `src` et rend `{name, width, height}`
/// ou `undefined` pour une image absente.
export function convertPage(html, {resolveLink, imageOf}) {
  const $ = cheerio.load(html);
  const anchors = new Set();
  const images = new Set();

  function convertChildren(nodes, inherited) {
    const blocks = [];
    let para = null;
    let pending = [];

    const takeAnchors = (block) => {
      if (pending.length) {
        block.k = [...(block.k ?? []), ...pending];
        pending = [];
      }
      return block;
    };
    const push = (block) => {
      flush();
      blocks.push(takeAnchors(block));
    };
    const gap = (lines) => {
      if (lines <= 0) return;
      const last = blocks.at(-1);
      if (last && last.gap !== undefined && !last.k) {
        last.gap = Math.min(4, last.gap + lines);
      } else {
        blocks.push(takeAnchors({gap: Math.min(4, lines)}));
      }
    };

    function flush() {
      if (!para) return;
      const current = para;
      para = null;
      // Espaces repliés comme en HTML, sauf autour des retours à la ligne.
      let spans = [];
      for (const span of current.spans) {
        const last = spans.at(-1);
        if (last && sameStyle(last, span)) last.t += span.t;
        else spans.push({...span});
      }
      const text = () => spans.map((s) => s.t).join('');
      for (const span of spans) span.t = span.t.replace(/[ \t\r\f\v ]*\n[ \t\r\f\v ]*/g, '\n').replace(/[ \t\r\f\v]+/g, ' ');
      // Retours à la ligne au début et à la fin : un espace entre deux blocs.
      let leading = 0;
      while (spans.length) {
        const first = spans[0];
        const stripped = first.t.replace(/^[ \n]+/, '');
        leading += (first.t.slice(0, first.t.length - stripped.length).match(/\n/g) ?? []).length;
        first.t = stripped;
        if (first.t) break;
        spans.shift();
      }
      let trailing = 0;
      while (spans.length) {
        const last = spans.at(-1);
        const stripped = last.t.replace(/[ \n]+$/, '');
        trailing += (last.t.slice(stripped.length).match(/\n/g) ?? []).length;
        last.t = stripped;
        if (last.t) break;
        spans.pop();
      }
      // Un espace en fin de ligne ne sert à rien et décale le centrage.
      spans = spans.filter((s) => s.t);
      for (let n = 0; n < spans.length - 1; n++) {
        if ((spans[n].t.endsWith(' ') || spans[n].t.endsWith('\n')) && spans[n + 1].t.startsWith(' ')) spans[n + 1].t = spans[n + 1].t.slice(1);
        if (spans[n].t.endsWith(' ') && spans[n + 1].t.startsWith('\n')) spans[n].t = spans[n].t.slice(0, -1);
      }
      spans = spans.filter((s) => s.t);
      gap(leading - 1);
      if (!spans.length || !text().trim()) {
        if (current.anchors.length) pending.push(...current.anchors);
        gap(Math.max(leading, trailing) > 0 ? 1 : 0);
        return;
      }
      const block = {p: spans.map((s) => Object.fromEntries(Object.entries(s).filter(([, v]) => v !== undefined)))};
      if (current.align && current.align !== 'c') block.a = current.align;
      if (current.rtl) block.d = 'rtl';
      if (current.ar) block.ar = 1;
      blocks.push(takeAnchors(block));
      if (current.anchors.length) block.k = [...(block.k ?? []), ...current.anchors];
      gap(trailing - 1);
    }

    const open = (style) => {
      if (!para) para = {spans: [], align: style.align, rtl: style.rtl, ar: style.ar, anchors: []};
      return para;
    };
    const text = (value, style) => {
      if (!value) return;
      if (!para && !value.trim()) return;
      open(style).spans.push({t: value, b: style.b, i: style.i, u: style.u, c: style.c, s: style.s, h: style.h});
    };

    function walk(node, style) {
      if (node.type === 'text') {
        text(node.data.replace(/\s+/g, ' '), style);
        return;
      }
      if (node.type !== 'tag') return;
      const tag = node.tagName.toLowerCase();
      if (skippedTags.has(tag)) return;
      const attrs = node.attribs ?? {};
      const classes = new Set((attrs.class ?? '').split(/\s+/).filter(Boolean));
      const css = cssDeclarations(attrs.style);
      const next = {...style};
      if (attrs.name && tag === 'a') {
        anchors.add(attrs.name);
        if (para) para.anchors.push(attrs.name);
        else pending.push(attrs.name);
      }
      if (attrs.id) anchors.add(attrs.id);
      switch (tag) {
        case 'br':
          if (para) para.spans.push({...(para.spans.at(-1) ?? {}), t: '\n'});
          else gap(1);
          return;
        case 'hr':
          push({hr: 1});
          return;
        case 'img': {
          // Bandeau du site, ou flèche vers une destination absente.
          if (classes.has('logo') || style.dead) return;
          const image = imageOf(attrs.src ?? '');
          if (!image) return;
          images.add(image.name);
          const block = {img: image.name, iw: image.width, ih: image.height};
          const width = attrs.width ?? css.width;
          if (width?.endsWith('%')) block.f = Math.min(1, Number.parseFloat(width) / 100);
          else if (width && Number.parseFloat(width) > 0) block.w = Number.parseFloat(width);
          const align = alignOf(attrs.align) ?? style.align;
          if (align && align !== 'c') block.a = align;
          if (style.h) block.h = style.h;
          push(block);
          return;
        }
        case 'table': {
          flush();
          const rows = $(node).find('tr').toArray().filter((tr) => $(tr).parents('table').first()[0] === node);
          for (const tr of rows) {
            const cells = $(tr).children('td,th').toArray().map((td) => {
              const cellStyle = {...style, align: alignOf(td.attribs?.align) ?? style.align};
              return convertChildren(td.children ?? [], cellStyle);
            }).filter((cell) => cell.some((block) => block.gap === undefined));
            if (cells.length === 1) for (const block of cells[0]) push(block);
            else if (cells.length) push({row: cells});
          }
          return;
        }
        case 'a': {
          if (attrs.href) {
            const link = resolveLink(attrs.href);
            if (classes.has('button')) {
              const label = $(node).text().replace(/\s+/g, ' ').trim();
              // Un bouton sans destination dans l'application ne mènerait nulle part.
              if (link && label) push({button: label, ...(classes.has('green') ? {green: 1} : {}), h: link});
              return;
            }
            next.h = link;
            next.dead = link ? undefined : 1;
            if (link) {
              next.c = '#124e12';
              next.u = 1;
              next.s = 14;
            }
          }
          break;
        }
        case 'b': case 'strong': next.b = 1; break;
        case 'i': case 'em': next.i = 1; break;
        case 'u': next.u = 1; break;
        case 'small': next.s = Math.round((style.s ?? 14) * 0.83 * 10) / 10; break;
        case 'big': next.s = Math.round((style.s ?? 14) * 1.2 * 10) / 10; break;
        case 'font':
          if (hex(attrs.color)) next.c = hex(attrs.color);
          break;
        case 'h1': case 'h2': case 'h3': case 'h4': case 'h5': case 'h6':
          next.b = 1;
          if (tag === 'h1') next.i = 1;
          break;
        default:
          break;
      }
      if (classes.has('g')) next.b = 1;
      if (classes.has('vert')) next.c = '#145014';
      if (classes.has('noir')) next.c = '#000000';
      for (const [name, size] of Object.entries(sizeClasses)) if (classes.has(name)) next.s = size;
      if (css['font-weight'] === 'bold' || Number(css['font-weight']) >= 600) next.b = 1;
      if (css['font-style'] === 'italic') next.i = 1;
      if (css.color && hex(css.color)) next.c = hex(css.color);
      const pt = css['font-size']?.match(/^([\d.]+)pt$/);
      if (pt) next.s = Number(pt[1]);
      if (classes.has('ar') || attrs.lang === 'ar') next.ar = 1;
      const block = blockTags.has(tag);
      if (block) {
        flush();
        if (tag === 'center') next.align = 'c';
        const align = alignOf(attrs.align) ?? alignOf(css['text-align']);
        if (align && tag !== 'span') next.align = align;
        if (attrs.dir) next.rtl = attrs.dir.toLowerCase() === 'rtl' ? 1 : undefined;
      }
      for (const child of node.children ?? []) walk(child, next);
      if (block) flush();
    }

    for (const node of nodes) walk(node, inherited);
    flush();
    if (pending.length) blocks.push({gap: 0, k: pending});
    // Pas d'espace au début ni à la fin d'une suite de blocs.
    while (blocks.length && blocks[0].gap !== undefined && !blocks[0].k) blocks.shift();
    while (blocks.length && blocks.at(-1).gap !== undefined && !blocks.at(-1).k) blocks.pop();
    return blocks;
  }

  const body = $('body')[0];
  const blocks = convertChildren(body?.children ?? [], {align: 'c'});
  return {blocks, anchors, images};
}

/// Premier paragraphe en titre (souvent en vert et plus grand).
export function pageTitle(blocks) {
  for (const block of blocks) {
    if (!block.p) continue;
    const text = block.p.map((s) => s.t).join('').replace(/\s+/g, ' ').trim();
    if (text) return text.length > 80 ? `${text.slice(0, 77)}…` : text;
  }
  return '';
}

function visitLinks(blocks, visit) {
  for (const block of blocks) {
    if (block.p) for (const span of block.p) if (span.h) visit(span);
    if (block.h) visit(block);
    if (block.row) for (const cell of block.row) visitLinks(cell, visit);
  }
}

/// Construit `pages.json` et le dossier d'images à partir d'une édition élaguée.
///
/// [siteDir] contient `bundle.json`, `pages/` et `assets/` ; [catalog] est
/// `catalog.json`. Les pages de l'ancien sommaire ne sont pas converties.
export async function buildNativePages({siteDir, catalog, outJson, outImages}) {
  const bundle = JSON.parse(await fs.readFile(path.join(siteDir, 'bundle.json'), 'utf8'));
  const pageIds = new Set();
  for (const page of bundle.pages) {
    const id = page.path.match(new RegExp(uuid, 'i'))?.[0]?.toLowerCase();
    if (id && !legacySommairePageIds.has(id)) pageIds.add(id);
  }
  const catalogIds = new Set(catalog.map((item) => item.id.toLowerCase()));
  for (const item of catalog.filter((item) => item.pagePath)) {
    const id = item.pagePath.match(new RegExp(uuid, 'i'))?.[0]?.toLowerCase();
    if (!pageIds.has(id)) throw new Error(`Page du catalogue absente de l'édition : ${item.pagePath}`);
  }
  const known = new Set([...pageIds, ...catalogIds]);
  const imageCache = new Map();
  const imageOf = async (src) => {
    const name = src.match(imageSrc)?.[1];
    if (!name) return undefined;
    if (!imageCache.has(name)) {
      try {
        const bytes = await fs.readFile(path.join(siteDir, 'assets', name));
        const {width, height} = imageSize(bytes);
        imageCache.set(name, {name, width, height, bytes});
      } catch (error) {
        if (error.code !== 'ENOENT') throw error;
        imageCache.set(name, undefined);
      }
    }
    return imageCache.get(name);
  };
  // Les tailles d'image sont lues avant la conversion, qui reste synchrone.
  const sources = new Map();
  for (const id of [...pageIds].sort()) {
    const html = await fs.readFile(path.join(siteDir, 'pages', `${id}.html`), 'utf8');
    sources.set(id, html);
    for (const match of html.matchAll(new RegExp(`${uuid}\\.(?:gif|png|jpe?g|webp)`, 'gi'))) await imageOf(match[0]);
  }
  const pages = {};
  const anchorsOf = new Map();
  let dropped = 0;
  for (const [id, html] of sources) {
    const resolveLink = (href) => {
      const value = href.trim();
      if (/^mailto:/i.test(value)) return value;
      if (/^https?:/i.test(value)) return isLegacySommaireUrl(value) ? 'sommaire' : value;
      const local = value.match(pageHref);
      if (local) {
        const target = local[1].toLowerCase();
        const fragment = local[2] ? decodeURIComponent(local[2]) : '';
        if (legacySommairePageIds.has(target)) return 'sommaire';
        if (target === id) return fragment ? `#${fragment}` : undefined;
        if (known.has(target)) return `page:${target}${fragment ? `#${fragment}` : ''}`;
        dropped++;
        return undefined;
      }
      if (value.startsWith('#') && value.length > 1) return `#${decodeURIComponent(value.slice(1))}`;
      dropped++;
      return undefined;
    };
    const {blocks, anchors} = convertPage(html, {
      resolveLink,
      imageOf: (src) => imageCache.get(src.match(imageSrc)?.[1]),
    });
    anchorsOf.set(id, anchors);
    pages[id] = {title: pageTitle(blocks), blocks};
  }
  // Une page vide n'a rien à montrer : ses liens partent avec elle.
  for (const [id, page] of Object.entries(pages)) {
    if (!page.blocks.length && !catalogIds.has(id)) delete pages[id];
  }
  for (const [id, page] of Object.entries(pages)) {
    visitLinks(page.blocks, (holder) => {
      const unlink = () => {
        delete holder.h;
        // Une image ou un bouton de navigation sans destination ne servirait à rien.
        if (holder.button || holder.img) holder.drop = 1;
        dropped++;
      };
      const link = holder.h;
      if (link.startsWith('#')) {
        if (!anchorsOf.get(id).has(link.slice(1))) unlink();
        return;
      }
      const [, target, fragment] = link.match(new RegExp(`^page:(${uuid})(?:#(.+))?$`)) ?? [];
      if (!target) return;
      if (pages[target]) {
        // Une ancre absente de la page visée : le lien ouvre la page, en haut.
        if (fragment && !anchorsOf.get(target).has(fragment)) holder.h = `page:${target}`;
      } else if (catalogIds.has(target)) {
        holder.h = `page:${target}`;
      } else {
        unlink();
      }
    });
    const clean = (blocks) => blocks.filter((block) => {
      if (block.row) for (const cell of block.row) cell.splice(0, cell.length, ...clean(cell));
      return !block.drop;
    });
    page.blocks = clean(page.blocks);
  }
  for (const page of Object.values(pages)) {
    const unlink = (blocks) => {
      for (const block of blocks) {
        if (block.p) for (const span of block.p) if (span.u && span.c === '#124e12' && !span.h) {
          delete span.u;
          delete span.c;
        }
        if (block.row) for (const cell of block.row) unlink(cell);
      }
    };
    unlink(page.blocks);
  }
  const used = new Set();
  const collect = (blocks) => {
    for (const block of blocks) {
      if (block.img) used.add(block.img);
      if (block.row) for (const cell of block.row) collect(cell);
    }
  };
  for (const page of Object.values(pages)) collect(page.blocks);
  await fs.rm(outImages, {recursive: true, force: true});
  await fs.mkdir(outImages, {recursive: true});
  let bytes = 0;
  for (const name of [...used].sort()) {
    const image = imageCache.get(name);
    bytes += image.bytes.length;
    await fs.writeFile(path.join(outImages, name), image.bytes);
  }
  await fs.mkdir(path.dirname(outJson), {recursive: true});
  await fs.writeFile(outJson, `${JSON.stringify(pages)}\n`);
  return {pages: Object.keys(pages).length, images: used.size, imageBytes: bytes, droppedLinks: dropped};
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const siteDir = process.argv[2] ?? 'apps/mobile/assets/site';
  const catalog = JSON.parse(await fs.readFile('apps/mobile/assets/content/catalog.json', 'utf8'));
  const result = await buildNativePages({
    siteDir,
    catalog,
    outJson: 'apps/mobile/assets/content/pages.json',
    outImages: 'apps/mobile/assets/pages',
  });
  console.log(`${result.pages} pages d'origine converties, ${result.images} images (${(result.imageBytes / 1048576).toFixed(1)} Mo), ${result.droppedLinks} liens sans destination retirés.`);
}
