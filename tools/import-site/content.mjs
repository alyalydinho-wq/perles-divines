import { createHash } from 'node:crypto';
import path from 'node:path';
import { load } from 'cheerio';
import iconv from 'iconv-lite';
import postcss from 'postcss';
import values from 'postcss-value-parser';
import { parseSrcset, stringifySrcset } from 'srcset';

export const HOSTS = new Set(['www.perlesdivines.fr', 'perlesdivines.fr']);
export const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');
export function stableId(url) {
  const h = sha256(url).slice(0, 32).split('');
  h[12] = '5'; h[16] = ((parseInt(h[16], 16) & 3) | 8).toString(16);
  const s = h.join('');
  return `${s.slice(0, 8)}-${s.slice(8, 12)}-${s.slice(12, 16)}-${s.slice(16, 20)}-${s.slice(20)}`;
}
export function resolveUrl(value, base) {
  try {
    const u = new URL(value.trim(), base);
    if (!['http:', 'https:', 'mailto:', 'tel:'].includes(u.protocol)) return null;
    if (u.username || u.password || (u.port && u.port !== '443')) return null;
    if (HOSTS.has(u.hostname)) u.protocol = 'https:';
    const fragment = u.hash; u.hash = '';
    return { url: u.href, fragment, internal: HOSTS.has(u.hostname) && u.protocol === 'https:' };
  } catch { return null; }
}
export function decode(bytes, type = '') {
  const head = bytes.subarray(0, 4096).toString('latin1');
  let encoding = /charset\s*=\s*["']?([\w-]+)/i.exec(type)?.[1]
    ?? /charset\s*=\s*["']?([\w-]+)/i.exec(head)?.[1]
    ?? /@charset\s+["']([^"']+)/i.exec(head)?.[1] ?? 'utf-8';
  if (bytes[0] === 0xef && bytes[1] === 0xbb && bytes[2] === 0xbf) encoding = 'utf-8';
  if (!iconv.encodingExists(encoding)) throw new Error(`Encodage inconnu : ${encoding}`);
  const text = iconv.decode(bytes, encoding);
  if (text.includes('\uFFFD')) throw new Error(`Caractère de remplacement détecté (${encoding})`);
  return { text, encoding };
}
export function kindOf(type, url) {
  if (/image\/svg\+xml/i.test(type)) return 'asset';
  if (/text\/html|application\/xhtml/i.test(type)) return 'html';
  if (/text\/css/i.test(type)) return 'css';
  if (/javascript/i.test(type) || /\.js(?:\?|$)/i.test(url)) return 'script';
  if (/xml/i.test(type) || /\.xml(?:\?|$)/i.test(url)) return 'xml';
  if (/manifest/i.test(type) || /\.webmanifest(?:\?|$)/i.test(url)) return 'manifest';
  return 'asset';
}
export function localPath(record) {
  const id = record.id ?? stableId(record.url);
  if (record.kind === 'html') return `pages/${id}.html`;
  const ext = path.posix.extname(new URL(record.url).pathname);
  return `assets/${id}${/^\.[a-z0-9]{1,8}$/i.test(ext) ? ext.toLowerCase() : '.bin'}`;
}
export function cssUrls(css) {
  const urls = [];
  const root = postcss.parse(css, { map: false });
  root.walkDecls(d => values(d.value).walk(n => {
    if (n.type === 'function' && n.value.toLowerCase() === 'url') urls.push(values.stringify(n.nodes).replace(/^["']|["']$/g, ''));
  }));
  root.walkAtRules('import', rule => {
    const v = values(rule.params).nodes[0];
    if (v?.type === 'string') urls.push(v.value);
    else if (v?.type === 'function') urls.push(values.stringify(v.nodes).replace(/^["']|["']$/g, ''));
  });
  return urls;
}
export function inspectHtml(html, base) {
  const $ = load(html), dependencies = [], interactions = [];
  const actualBase = resolveUrl($('base[href]').attr('href') ?? base, base)?.url ?? base;
  const add = (value, role) => {
    if (!value || value.startsWith('data:')) return;
    const ref = resolveUrl(value, actualBase);
    if (ref) dependencies.push({ ...ref, role });
  };
  $('*').each((_, el) => {
    const tag = el.tagName;
    for (const [attr, v] of Object.entries(el.attribs ?? {})) {
      if (attr.startsWith('on')) interactions.push({ kind: 'handler', tag, attribute: attr, value: v });
      if (['src', 'poster', 'background', 'data', 'xlink:href'].includes(attr)) add(v, ['script', 'iframe', 'embed', 'object'].includes(tag) ? 'active' : 'resource');
      if (attr === 'href') add(v, tag === 'a' || tag === 'area' ? 'navigation' : 'resource');
      if (attr === 'srcset') for (const item of parseSrcset(v)) add(item.url, 'resource');
      if (attr === 'style') for (const u of cssUrls(`x{${v}}`)) add(u, 'resource');
    }
  });
  $('style').each((_, el) => cssUrls($(el).html() ?? '').forEach(u => add(u, 'resource')));
  $('script,iframe,form,object,embed,audio,video').each((_, el) => interactions.push({ kind: el.tagName, src: $(el).attr('src'), code: $(el).text().slice(0, 2000) }));
  const refresh = $('meta[http-equiv]').filter((_, el) => ($(el).attr('http-equiv') ?? '').toLowerCase() === 'refresh');
  refresh.each((_, el) => {
    const v = $(el).attr('content') ?? '';
    interactions.push({ kind: 'redirect', value: v });
    const target = /url\s*=\s*(.+)/i.exec(v)?.[1]?.replace(/^["']|["']$/g, '');
    if (target) add(target, 'navigation');
  });
  // Plain-text external addresses on Tafsir/Diaporama are source data too.
  const passive = load($.html()); passive('script,style').remove();
  for (const m of passive('body').text().matchAll(/https?:\/\/[^\s<>"']+/g)) add(m[0], 'navigation');
  return { title: $('title').text().trim(), dependencies, interactions, base: actualBase,
    anchors: $('[id],a[name]').map((_, el) => $(el).attr('id') ?? $(el).attr('name')).get(),
    arabicText: /[\u0600-\u06ff]/.test($('body').text()), images: $('img').length, tables: $('table').length };
}
export function rewriteCss(css, resolve) {
  const root = postcss.parse(css, { map: false });
  root.walkAtRules(rule => {
    if (['charset', 'namespace'].includes(rule.name.toLowerCase())) rule.remove();
    else if (rule.name.toLowerCase() === 'import') {
      const parsed = values(rule.params), n = parsed.nodes[0];
      const source = n?.type === 'string' ? n.value : n?.type === 'function' ? values.stringify(n.nodes).replace(/^["']|["']$/g, '') : '';
      const target = resolve(source);
      if (!target) rule.remove(); else { n.type = 'string'; n.quote = '"'; n.value = target; delete n.nodes; rule.params = parsed.toString(); }
    }
  });
  root.walkDecls(d => {
    if (/expression\s*\(|javascript:|vbscript:/i.test(d.value) || /behavior|binding/i.test(d.prop)) { d.remove(); return; }
    const v = values(d.value);
    v.walk(n => {
      if (n.type !== 'function' || n.value.toLowerCase() !== 'url') return;
      const source = values.stringify(n.nodes).replace(/^["']|["']$/g, '');
      const target = /^data:image\/(png|gif|jpeg|webp);/i.test(source) ? source : resolve(source);
      n.nodes = [{ type: 'string', quote: '"', value: target ?? '' }];
    });
    d.value = v.toString();
  });
  return root.toString();
}
export const MOBILE_CSS = `html{box-sizing:border-box;-webkit-text-size-adjust:100%}*,*:before,*:after{box-sizing:inherit}body{margin:0 auto!important;padding:12px!important;width:auto!important;max-width:760px!important;overflow-wrap:break-word}img{max-width:100%;height:auto}table{max-width:100%}a.button{max-width:100%;min-height:44px}a{touch-action:manipulation}iframe{display:none}.pd-table{overflow-x:auto;max-width:100%}.pd-notice{font:14px/1.5 system-ui,sans-serif;background:#f0f7ef;border:1px solid #58764b;border-radius:6px;padding:12px;margin:12px 0}body>div#topbar{position:static!important} [lang=ar]{direction:rtl}`;
export const CSP = "default-src 'none'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; font-src 'self'; script-src 'none'; connect-src 'none'; media-src 'none'; frame-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'";
export function normalizeHtml(html, record, records) {
  const $ = load(html), from = localPath(record), audit = inspectHtml(html, record.url);
  const resolve = (value, navigation = false) => {
    const ref = resolveUrl(value, audit.base);
    if (!ref) return null;
    if (!ref.internal) return navigation ? ref.url + ref.fragment : null;
    const target = records.get(ref.url);
    if (!target?.localPath) return navigation ? `../unavailable.html?source=${encodeURIComponent(ref.url)}` : null;
    if (navigation && ref.fragment && target.kind === 'html' && !target.anchors?.includes(decodeURIComponent(ref.fragment.slice(1)))) return `../unavailable.html?source=${encodeURIComponent(ref.url + ref.fragment)}`;
    return path.posix.relative(path.posix.dirname(from), target.localPath) + ref.fragment;
  };
  $('script,iframe,object,embed,base,link[rel=manifest],svg,math').remove();
  // This audited legacy bar contains only back/home/top and an obsolete 0% counter.
  // Those commands belong to the native reader / trusted preview shell.
  $('#foo').filter((_, el) => $(el).find('img[src$="retour.png"]').length > 0).remove();
  // Remove spacing formerly reserved for the fixed navigation bar, not editorial content.
  while ($('body').contents().length) {
    const first = $('body').contents().first();
    if (first[0].type === 'text' && !first.text().trim() || first[0].tagName === 'br') first.remove(); else break;
  }
  $('meta[http-equiv],meta[charset],meta[name=viewport]').remove();
  $('form').each((_, el) => $(el).replaceWith($(el).contents()));
  $('input,button,select,textarea').attr('disabled', 'disabled');
  $('*').each((_, el) => {
    for (const [attr, value] of Object.entries(el.attribs ?? {})) {
      if (attr.startsWith('on') || ['srcdoc', 'action', 'formaction', 'ping', 'integrity', 'crossorigin', 'xmlns', 'xlink:href'].includes(attr)) { $(el).removeAttr(attr); continue; }
      if (attr === 'href' || ['src', 'poster', 'background', 'data'].includes(attr)) {
        const navigation = attr === 'href' && ['a', 'area'].includes(el.tagName);
        const next = /^data:image\/(png|gif|jpeg|webp);/i.test(value) && attr === 'src' ? value : resolve(value, navigation);
        if (next) $(el).attr(attr, next); else $(el).removeAttr(attr);
        if (navigation && resolveUrl(value, audit.base)?.internal === false) $(el).attr('data-external', 'true').attr('rel', 'noopener noreferrer');
      }
      if (attr === 'srcset') {
        const candidates = parseSrcset(value).flatMap(c => { const u = resolve(c.url); return u ? [{ ...c, url: u }] : []; });
        if (candidates.length) $(el).attr(attr, stringifySrcset(candidates)); else $(el).removeAttr(attr);
      }
      if (attr === 'style') $(el).attr(attr, rewriteCss(`x{${value}}`, resolve).replace(/^x\{|\}$/g, ''));
    }
  });
  $('style').each((_, el) => $(el).text(rewriteCss($(el).html() ?? '', resolve)));
  $('table').wrap('<div class="pd-table"></div>');
  // Removed redirect scripts are replaced with explicit destinations, never auto-navigation.
  for (const dep of audit.dependencies.filter(d => !d.internal && d.role === 'navigation')) {
    if (!$('[data-external]').toArray().some(el => $(el).attr('href') === dep.url + dep.fragment)) {
      const a = $('<a>').attr('href', dep.url + dep.fragment).attr('data-external', 'true').text('Ouvrir la ressource externe');
      $('body').append($('<p>').append(a));
    }
  }
  if ($('[data-external]').length) $('body').prepend('<aside class="pd-notice">Cette page est disponible localement. Les liens vers des sites externes nécessitent une connexion Internet.</aside>');
  if (!($('html').attr('lang'))) $('html').attr('lang', 'fr');
  $('head').prepend('<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">');
  $('head').prepend($('<meta>').attr('http-equiv', 'Content-Security-Policy').attr('content', CSP));
  $('head').append($('<style>').text(MOBILE_CSS));
  return $.html();
}
