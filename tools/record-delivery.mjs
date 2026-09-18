import fs from 'node:fs/promises';
import {createReadStream} from 'node:fs';
import {createHash} from 'node:crypto';
const filename='artifacts/Perles-Divines-0.1.0-essai.apk';
const hash=createHash('sha256');for await(const chunk of createReadStream(filename))hash.update(chunk);
const record={createdAt:new Date().toISOString(),file:filename,sizeBytes:(await fs.stat(filename)).size,sha256:hash.digest('hex'),version:'0.1.0+1',variant:'debug',fixtures:true,androidPhysicalDeviceTested:false,iosBuilt:false,iosPhysicalDeviceTested:false,sourceDate:'2026-09-17',limitations:'Preuve technique intermédiaire. Catalogue synthétique. Analyse Flutter et cinq tests locaux réussis. Fonctions natives à essayer sur téléphone ; catalogue religieux relu et essais sur appareils non livrés.'};
await fs.writeFile('docs/evidence/android-artifact.json',JSON.stringify(record,null,2));console.log(record);
