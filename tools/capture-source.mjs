import {chromium} from '@playwright/test';
const browser=await chromium.launch({channel:'msedge',headless:true});
try{
 const context=await browser.newContext({viewport:{width:390,height:844}});
 await context.route('**/*',route=>['www.perlesdivines.fr','perlesdivines.fr'].includes(new URL(route.request().url()).hostname)&&route.request().method()==='GET'?route.continue():route.abort());
 const page=await context.newPage();
 for(const suffix of ['/sommaire.html','/quran.html','/fr/fateha.html','/fr/namaz-en-general.html','/a-propos.html']){
  await page.goto(`https://www.perlesdivines.fr${suffix}`,{waitUntil:'networkidle'});
  await page.screenshot({path:`docs/evidence/source-${suffix.replaceAll('/','_').replace('.html','')}.png`});
 }
}finally{await browser.close();}
