import fs from 'node:fs/promises';
import {sha256} from './import-site/content.mjs';
import {extractCatalog} from './extract-devotional-catalog.mjs';
import {prepareEmbeddedAudio} from './prepare-embedded-audio.mjs';
const current=JSON.parse(await fs.readFile('content/current-import.json','utf8'));
const inventory=JSON.parse(await fs.readFile('content/source-inventory.json','utf8'));
const catalog=await extractCatalog({importDirectory:current.directory,inventory});
await fs.mkdir('apps/mobile/assets/content',{recursive:true});
await fs.writeFile('apps/mobile/assets/content/catalog.json',`${JSON.stringify(catalog,null,2)}\n`);
const audio=await prepareEmbeddedAudio();
if(!audio.skipped){
  console.log(`${audio.files} pistes embarquées, ${audio.associated} associées à un texte.`);
}
const destination='apps/mobile/assets/site';
await fs.mkdir(destination,{recursive:true});
await fs.cp(`${current.directory}/normalized`,destination,{recursive:true});
const files=[];
for(const r of inventory.filter(r=>r.localPath))files.push({path:r.localPath,sha256:r.normalizedSha256,sizeBytes:r.normalizedSizeBytes});
const unavailable=await fs.readFile(`${destination}/unavailable.html`);
files.push({path:'unavailable.html',sha256:sha256(unavailable),sizeBytes:unavailable.length});
const home=inventory.find(r=>r.url.endsWith('/sommaire.html'));
await fs.writeFile(`${destination}/bundle.json`,JSON.stringify({version:`initial-2026-09-17-${sha256(JSON.stringify(files)).slice(0,12)}`,home:home.localPath,files,pages:inventory.filter(r=>r.kind==='html'&&r.localPath).map(r=>({id:r.id,path:r.localPath,url:r.url,title:r.title,anchors:r.anchors}))},null,2));
  console.log(`${files.length} fichiers locaux et ${catalog.length} textes préparés pour Flutter.`);
