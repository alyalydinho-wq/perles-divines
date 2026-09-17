import fs from 'node:fs/promises';
import {load} from 'cheerio';
import {decode,sha256} from './import-site/content.mjs';
const current=JSON.parse(await fs.readFile('content/current-import.json','utf8'));
const records=JSON.parse(await fs.readFile('content/source-inventory.json','utf8'));
const failures=[];let pages=0,images=0;
for(const r of records){
 if(!r.rawPath)continue;
 const raw=await fs.readFile(`${current.directory}/${r.rawPath}`);
 if(sha256(raw)!==r.sha256)failures.push({url:r.url,reason:'Empreinte source'});
 if(!r.localPath)continue;
 const local=await fs.readFile(`${current.directory}/normalized/${r.localPath}`);
 if(sha256(local)!==r.normalizedSha256)failures.push({url:r.url,reason:'Empreinte normalisée'});
 if(r.kind!=='html')continue;pages++;
 const a=load(decode(raw,r.mime).text),b=load(local.toString('utf8'));
 a('script,style,#foo').remove();b('script,style,.pd-notice').remove();
 // Explicit external destination actions are utility additions, recorded by normalization.
 b('a[data-external]').filter((_,el)=>b(el).text()==='Ouvrir la ressource externe').parent('p').remove();
 const text=$=>$('body').text().replace(/\s+/g,' ').trim();
 if(text(a)!==text(b))failures.push({url:r.url,reason:'Différence de texte visible à examiner'});
 images+=a('img').length;
 if(a('img').length!==b('img').length)failures.push({url:r.url,reason:'Différence de nombre d’images'});
 for(const el of b('img[src],link[href]').toArray()){
   const value=b(el).attr(el.tagName==='img'?'src':'href');
   if(/^https?:|^\/\//.test(value))failures.push({url:r.url,reason:'Sous-ressource distante',value});
 }
}
const result={date:new Date().toISOString(),pages,images,rawHashesChecked:records.filter(r=>r.rawPath).length,failures};
await fs.writeFile('docs/evidence/content-integrity.json',JSON.stringify(result,null,2));
console.log(JSON.stringify(result,null,2));if(failures.length)process.exitCode=1;
