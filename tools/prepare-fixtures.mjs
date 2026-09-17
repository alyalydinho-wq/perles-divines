import ffmpeg from 'ffmpeg-static';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs/promises';
import {sha256,stableId} from './import-site/content.mjs';
await fs.mkdir('content/fixtures',{recursive:true});
await fs.mkdir('apps/mobile/assets/fixtures',{recursive:true});
const tracks=[];
for(const [index,seconds,hz] of [[1,20,440],[2,25,660],[3,3600,220]]){
 const file=`tone-${index}.mp3`, output=`content/fixtures/${file}`;
 // A quiet synthetic tone, generated locally. No speaker/author attribution.
 execFileSync(ffmpeg,['-hide_banner','-loglevel','error','-y','-f','lavfi','-i',`sine=frequency=${hz}:duration=${seconds}:sample_rate=22050`,'-af','volume=0.1','-codec:a','libmp3lame','-b:a','32k',output]);
 const bytes=await fs.readFile(output);
 tracks.push({id:stableId(`fixture:${index}`),title:`ESSAI — Son synthétique ${index} (${seconds===3600?'1 heure':`${seconds} s`})`,author:null,description:'Fixture technique locale, sans contenu religieux. Ne pas publier.',collection:'Essais techniques',version:1,durationMs:seconds*1000,sizeBytes:bytes.length,sha256:sha256(bytes),file,fixture:true});
 if(index<3)await fs.copyFile(output,`apps/mobile/assets/fixtures/${file}`);
}
await fs.writeFile('content/fixtures/catalog.json',JSON.stringify(tracks,null,2));
await fs.copyFile('content/fixtures/catalog.json','apps/mobile/assets/fixtures/catalog.json');
await fs.writeFile('content/fixtures/invalid.mp3','Ceci ne contient pas de flux MP3.');
await fs.copyFile('content/fixtures/tone-1.mp3','content/fixtures/duplicate.mp3');
console.log(tracks.map(t=>({title:t.title,sizeBytes:t.sizeBytes,sha256:t.sha256})));
