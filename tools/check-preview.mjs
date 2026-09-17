import { chromium } from '@playwright/test';
import fs from 'node:fs/promises';
const browser = await chromium.launch({ channel: 'msedge', headless: true });
const context = await browser.newContext({ viewport: {width:390,height:844} });
const page = await context.newPage();
const requests = [], errors = [];
await context.route('**/*', route => {
  const url = route.request().url(); requests.push(url);
  if (new URL(url).hostname !== '127.0.0.1') return route.abort('internetdisconnected');
  return route.continue();
});
page.on('pageerror', e => errors.push(e.message));
await page.goto('http://127.0.0.1:4173/');
await page.frameLocator('#reader').locator('a.button').first().waitFor();
const inventory = await page.evaluate(() => fetch('/api/inventory').then(r => r.json()));
const results = [];
for (const width of [320,390,430]) {
  await page.setViewportSize({width,height:844});
  for (const suffix of ['/sommaire.html','/quran.html','/fr/fateha.html','/fr/namaz-en-general.html','/fr/suppl_eachday.html','/a-propos.html','/tafsir.html','/diapo-coran.html']) {
    const record=inventory.pages.find(r=>r.url.endsWith(suffix));
    await page.locator('#reader').evaluate((el,src)=>new Promise(resolve=>{el.addEventListener('load',resolve,{once:true});el.src=src;}), `/content/${record.path}`);
    await page.waitForFunction(p=>document.querySelector('#reader').contentWindow.location.pathname===`/content/${p}` && document.querySelector('#reader').contentDocument.readyState==='complete',record.path);
    const frame = page.frames().find(f=>f.url().includes(record.id));
    await frame.evaluate(()=>document.fonts.ready);
    await frame.locator('img').evaluateAll(images=>Promise.all(images.map(i=>i.complete ? Promise.resolve() : new Promise(r=>{i.onload=r;i.onerror=r;}))));
    const metrics=await frame.evaluate(()=>({width:innerWidth,scrollWidth:document.documentElement.scrollWidth,images:[...document.images].filter(i=>!i.complete||i.naturalWidth===0).map(i=>i.src),scripts:document.scripts.length,legacyNav:!!document.querySelector('#foo'),text:document.body.textContent.length}));
    results.push({width,page:suffix,...metrics});
    if(width===390) await page.screenshot({path:`docs/evidence/reader-${suffix.replaceAll('/','_').replace('.html','')}.png`});
  }
}
await fs.writeFile('docs/evidence/reader-browser.json',JSON.stringify({date:new Date().toISOString(),browser:browser.version(),network:'Toutes les destinations non locales bloquées par le navigateur de test',requests:requests.length,externalRequests:requests.filter(u=>new URL(u).hostname!=='127.0.0.1'),errors,results},null,2));
await browser.close();
const failed=results.filter(r=>r.scrollWidth>r.width+1||r.images.length||r.scripts||r.legacyNav);
console.log(JSON.stringify({checks:results.length,failures:failed,errors},null,2));
if(failed.length||errors.length)process.exitCode=1;
