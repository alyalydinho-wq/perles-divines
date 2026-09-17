import fs from 'node:fs/promises';
import path from 'node:path';
import { setTimeout as delay } from 'node:timers/promises';
import { load } from 'cheerio';
import { HOSTS, sha256, stableId, resolveUrl, decode, kindOf, localPath, inspectHtml, cssUrls, rewriteCss, normalizeHtml, CSP } from './content.mjs';

const rebuild = process.argv.includes('--normalize');
const root = rebuild ? path.resolve(JSON.parse(await fs.readFile('content/current-import.json', 'utf8')).directory) : path.resolve('content/imports', new Date().toISOString().replace(/[:.]/g, '-'));
await fs.mkdir(path.join(root, 'raw'), { recursive: true });
await fs.mkdir(path.join(root, 'normalized/pages'), { recursive: true });
await fs.mkdir(path.join(root, 'normalized/assets'), { recursive: true });
const records = new Map(), queue = [], external = new Map();
const MAX_RESOURCES = 10000, MAX_BYTES = 64 * 1024 * 1024, MAX_TOTAL = 2 * 1024 ** 3;
let totalBytes = 0;
function enqueue(url, referrer = null, role = 'resource') {
  const ref = resolveUrl(url, 'https://www.perlesdivines.fr/');
  if (!ref?.internal) { if (ref) external.set(ref.url, { url: ref.url, referrer, role }); return; }
  if (records.has(ref.url)) return;
  if (records.size >= MAX_RESOURCES) throw new Error('Plafond de sécurité de ressources dépassé');
  const record = { id: stableId(ref.url), url: ref.url, referrer, role, status: null, dependencies: [] };
  records.set(ref.url, record); queue.push(record);
}
if (rebuild) {
  for (const record of JSON.parse(await fs.readFile(path.join(root, 'source-inventory.json'), 'utf8'))) {
    records.set(record.url, record); totalBytes += record.sizeBytes ?? 0;
    if (record.status !== 200) continue;
    record.kind = kindOf(record.mime, record.url);
    if (!['script','manifest','xml'].includes(record.kind)) record.localPath = localPath(record);
    if (record.kind === 'html') Object.assign(record, inspectHtml(decode(await fs.readFile(path.join(root, record.rawPath)), record.mime).text, record.finalUrl));
    for (const dep of record.dependencies.filter(d => !d.internal)) external.set(dep.url, {url:dep.url,referrer:record.url,role:dep.role});
  }
} else ['sommaire.html', 'index.html', 'historique.html', 'robots.txt', 'sitemap.xml'].forEach(p => enqueue(`https://www.perlesdivines.fr/${p}`, null, 'seed'));
async function get(url) {
  let current = url;
  for (let redirects = 0; redirects < 6; redirects++) {
    if (!HOSTS.has(new URL(current).hostname)) throw new Error('Redirection hors des hôtes autorisés');
    const response = await fetch(current, { redirect: 'manual', signal: AbortSignal.timeout(30000), headers: { 'User-Agent': 'PerlesDivinesInitialImport/0.1 (owner-authorized; read-only)', Accept: '*/*' } });
    if (response.status >= 300 && response.status < 400) {
      await response.body?.cancel();
      const next = resolveUrl(response.headers.get('location') ?? '', current);
      if (!next?.internal) throw new Error(`Redirection externe : ${next?.url ?? 'invalide'}`);
      current = next.url; continue;
    }
    const chunks = []; let size = 0;
    if (Number(response.headers.get('content-length') ?? 0) > MAX_BYTES) { await response.body?.cancel(); throw new Error('Ressource trop volumineuse'); }
    for await (const chunk of response.body ?? []) {
      size += chunk.length;
      if (size > MAX_BYTES || totalBytes + size > MAX_TOTAL) throw new Error('Plafond de sécurité de taille dépassé');
      chunks.push(chunk);
    }
    return { status: response.status, type: response.headers.get('content-type') ?? '', bytes: Buffer.concat(chunks), finalUrl: current };
  }
  throw new Error('Trop de redirections');
}
async function collect(record) {
  record.fetchedAt = new Date().toISOString();
  let response;
  for (let attempt = 0; attempt < 3; attempt++) {
    record.attempts = attempt + 1;
    try {
      response = await get(record.url);
      if (response.status >= 500 || response.status === 429) throw new Error(`HTTP ${response.status}`);
      break;
    } catch (e) { record.error = e.message; if (attempt < 2) await delay(500 * 2 ** attempt); }
  }
  if (!response) return;
  Object.assign(record, { status: response.status, mime: response.type, sizeBytes: response.bytes.length, sha256: sha256(response.bytes), finalUrl: response.finalUrl });
  totalBytes += response.bytes.length;
  record.rawPath = `raw/${record.sha256}`;
  try { await fs.writeFile(path.join(root, record.rawPath), response.bytes, { flag: 'wx' }); } catch (e) { if (e.code !== 'EEXIST') throw e; }
  if (response.status !== 200) { record.error = `HTTP ${response.status}`; return; }
  delete record.error;
  record.kind = kindOf(record.mime, record.url);
  if (!['script', 'manifest', 'xml'].includes(record.kind)) record.localPath = localPath(record);
  try {
    if (['html', 'css', 'xml', 'manifest'].includes(record.kind) || record.url.endsWith('/robots.txt')) {
      const decoded = decode(response.bytes, record.mime); record.encoding = decoded.encoding;
      if (record.kind === 'html') Object.assign(record, inspectHtml(decoded.text, record.finalUrl));
      if (record.kind === 'css') record.dependencies = cssUrls(decoded.text).map(v => resolveUrl(v, record.finalUrl)).filter(Boolean).map(d => ({ ...d, role: 'resource' }));
      if (record.kind === 'xml') {
        const $ = load(decoded.text, { xml: true });
        record.dependencies = $('loc').map((_, el) => resolveUrl($(el).text(), record.finalUrl)).get().filter(Boolean).map(d => ({ ...d, role: 'sitemap' }));
      }
      if (record.kind === 'manifest') {
        const manifest = JSON.parse(decoded.text);
        record.dependencies = (manifest.icons ?? []).map(i => resolveUrl(i.src, record.finalUrl)).filter(Boolean).map(d => ({ ...d, role: 'resource' }));
      }
      if (record.url.endsWith('/robots.txt')) record.dependencies = [...decoded.text.matchAll(/^sitemap:\s*(.+)$/gim)].map(m => resolveUrl(m[1], record.url)).filter(Boolean).map(d => ({ ...d, role: 'sitemap' }));
    }
    for (const dep of record.dependencies) enqueue(dep.url, record.url, dep.role);
  } catch (e) { record.error = `Analyse : ${e.message}`; delete record.localPath; }
}
let done = 0;
while (queue.length) {
  const batch = queue.splice(0, 2);
  await Promise.all(batch.map(collect)); done += batch.length;
  if (done % 20 === 0 || !queue.length) console.log(`${done} ressources lues, ${queue.length} en attente, ${(totalBytes / 1048576).toFixed(1)} Mio`);
  await fs.writeFile(path.join(root, 'source-inventory.partial.json'), JSON.stringify([...records.values()], null, 2));
  await delay(120);
}
for (const record of records.values()) {
  if (!record.localPath) continue;
  const bytes = await fs.readFile(path.join(root, record.rawPath));
  let normalized = bytes;
  if (record.kind === 'html') normalized = Buffer.from(normalizeHtml(decode(bytes, record.mime).text, record, records));
  if (record.kind === 'css') normalized = Buffer.from(rewriteCss(decode(bytes, record.mime).text, value => {
    const ref = resolveUrl(value, record.finalUrl), target = records.get(ref?.url);
    return target?.localPath ? path.posix.relative(path.posix.dirname(record.localPath), target.localPath) + ref.fragment : null;
  }));
  await fs.writeFile(path.join(root, 'normalized', record.localPath), normalized);
  record.normalizedSha256 = sha256(normalized); record.normalizedSizeBytes = normalized.length;
}
const entries = [...records.values()];
const missing = entries.filter(r => r.error);
const brokenLinks = entries.flatMap(r => r.dependencies.filter(d => d.internal && !records.get(d.url)?.localPath && !['active', 'sitemap'].includes(d.role)).map(d => ({ from: r.url, to: d.url, role: d.role, error: records.get(d.url)?.error ?? 'Ressource active exclue' })));
const anchors = entries.flatMap(r => r.dependencies.filter(d => d.internal && d.fragment && records.get(d.url)?.kind === 'html').filter(d => !records.get(d.url).anchors?.includes(decodeURIComponent(d.fragment.slice(1)))).map(d => ({ from: r.url, to: d.url + d.fragment })));
const report = { createdAt: new Date().toISOString(), importDirectory: path.relative(process.cwd(), root), resources: entries.length, pages: entries.filter(r => r.kind === 'html' && r.localPath).length, sourceBytes: totalBytes, normalizedBytes: entries.reduce((s,r) => s + (r.normalizedSizeBytes ?? 0), 0), missing, brokenLinks, missingAnchors: anchors, external: [...external.values()], interactions: entries.filter(r => r.interactions?.length).map(r => ({ url: r.url, items: r.interactions })), scope: 'Ressources référencées et sitemaps accessibles ; aucun fichier orphelin prétendument découvert.' };
const unavailable = `<!doctype html><html lang="fr"><meta charset="utf-8"><meta http-equiv="Content-Security-Policy" content="${CSP}"><meta name="viewport" content="width=device-width"><title>Page indisponible</title><h1>Page indisponible</h1><p>Cette destination manque dans la source importée. Elle est signalée dans le rapport d’import.</p></html>`;
await fs.writeFile(path.join(root, 'normalized/unavailable.html'), unavailable);
await fs.writeFile(path.join(root, 'source-inventory.json'), JSON.stringify(entries, null, 2));
await fs.writeFile(path.join(root, 'report.json'), JSON.stringify(report, null, 2));
await fs.writeFile('content/source-inventory.json', JSON.stringify(entries, null, 2));
await fs.writeFile('content/import-report.json', JSON.stringify(report, null, 2));
await fs.writeFile('content/current-import.json', JSON.stringify({ directory: path.relative(process.cwd(), root).replaceAll('\\', '/'), preparedAt: report.createdAt }, null, 2));
console.log(JSON.stringify({ directory: root, pages: report.pages, resources: report.resources, missing: missing.length, brokenLinks: brokenLinks.length, missingAnchors: anchors.length }, null, 2));
