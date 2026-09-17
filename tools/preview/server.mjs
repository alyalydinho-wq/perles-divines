import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import { CSP } from '../import-site/content.mjs';
const current = JSON.parse(await fs.readFile('content/current-import.json', 'utf8'));
const base = path.resolve(current.directory, 'normalized');
const inventory = JSON.parse(await fs.readFile('content/source-inventory.json', 'utf8'));
const report = JSON.parse(await fs.readFile('content/import-report.json', 'utf8'));
const mime = { '.html':'text/html; charset=utf-8','.css':'text/css; charset=utf-8','.js':'text/javascript; charset=utf-8','.png':'image/png','.gif':'image/gif','.jpg':'image/jpeg','.jpeg':'image/jpeg','.ico':'image/x-icon','.svg':'image/svg+xml','.woff':'font/woff','.woff2':'font/woff2','.ttf':'font/ttf','.pdf':'application/pdf' };
const port = Number(process.env.PORT ?? 4173);
http.createServer(async (req, res) => {
  try {
    if (req.method !== 'GET' && req.method !== 'HEAD') { res.writeHead(405).end(); return; }
    const u = new URL(req.url, `http://127.0.0.1:${port}`);
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Referrer-Policy', 'no-referrer');
    if (u.pathname === '/api/inventory') {
      const report = JSON.parse(await fs.readFile('content/import-report.json', 'utf8'));
      res.setHeader('Content-Type', 'application/json; charset=utf-8');
      res.end(JSON.stringify({ report: { pages: report.pages, missing: report.missing.length, brokenLinks: report.brokenLinks.length }, pages: inventory.filter(r=>r.kind==='html' && r.localPath).map(r=>({id:r.id,url:r.url,title:r.title,path:r.localPath})) })); return;
    }
    const isContent = u.pathname.startsWith('/content/');
    const root = isContent ? base : path.resolve('tools/preview/public');
    const relative = decodeURIComponent(isContent ? u.pathname.slice(9) : u.pathname === '/' ? 'index.html' : u.pathname.slice(1));
    const file = path.resolve(root, relative);
    if (!file.startsWith(root + path.sep) || relative.includes('\0')) { res.writeHead(403).end(); return; }
    if (isContent) res.setHeader('Content-Security-Policy', CSP);
    else res.setHeader('Content-Security-Policy', "default-src 'self'; script-src 'self'; style-src 'self'; frame-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'none'");
    res.setHeader('Content-Type', mime[path.extname(file)] ?? 'application/octet-stream');
    const bytes = await fs.readFile(file);
    res.end(req.method === 'HEAD' ? undefined : bytes);
  } catch { res.writeHead(404, { 'Content-Type':'text/plain; charset=utf-8' }).end('Ressource locale introuvable.'); }
}).listen(port, '127.0.0.1', () => console.log(`Lecture locale : http://127.0.0.1:${port} — ${report.pages} pages. Aucun accès au site en navigation.`));
