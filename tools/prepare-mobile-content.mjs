import fs from 'node:fs/promises';
import {extractCatalog} from './extract-devotional-catalog.mjs';
import {prepareEmbeddedAudio} from './prepare-embedded-audio.mjs';
import {prepareMobilePages} from './prepare-mobile-pages.mjs';
const current=JSON.parse(await fs.readFile('content/current-import.json','utf8'));
const inventory=JSON.parse(await fs.readFile('content/source-inventory.json','utf8'));
const catalog=await extractCatalog({importDirectory:current.directory,inventory});
await fs.mkdir('apps/mobile/assets/content',{recursive:true});
await fs.writeFile('apps/mobile/assets/content/catalog.json',`${JSON.stringify(catalog,null,2)}\n`);
const audioCatalog='apps/mobile/assets/content/audio-catalog.json';
try {
  const tracks=JSON.parse(await fs.readFile(audioCatalog,'utf8'));
  const remote=tracks.filter((track)=>track.bundled!==true).length;
  console.log(`${tracks.length} pistes audio déjà cataloguées, ${remote} servies depuis R2.`);
} catch (error) {
  if (error.code!=='ENOENT') throw error;
  const audio=await prepareEmbeddedAudio();
  if(!audio.skipped){
    console.log(`${audio.files} pistes cataloguées, ${audio.associated} associées à un texte.`);
  }
}
const {pages}=await prepareMobilePages();
console.log(`${pages.pages} pages d'origine et ${pages.images} images (${(pages.imageBytes/1048576).toFixed(1)} Mo), ${catalog.length} textes préparés pour Flutter.`);
