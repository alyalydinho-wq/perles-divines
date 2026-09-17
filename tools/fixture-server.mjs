import http from 'node:http';
import fs from 'node:fs';
import fsp from 'node:fs/promises';
import path from 'node:path';
import {sha256} from './import-site/content.mjs';
const root=path.resolve('content/fixtures'),port=Number(process.env.PORT??4174);
http.createServer(async(req,res)=>{
 try{
  if(!['GET','HEAD'].includes(req.method)){res.writeHead(405).end();return;}
  const filename=decodeURIComponent(new URL(req.url,'http://localhost').pathname).slice(1);
  if(!/^[\w.-]+$/.test(filename)){res.writeHead(400).end();return;}
  const file=path.join(root,filename), stat=await fsp.stat(file);
  const etag=`"${sha256(await fsp.readFile(file))}"`;
  res.setHeader('Accept-Ranges','bytes');res.setHeader('ETag',etag);res.setHeader('Content-Type',filename.endsWith('.mp3')?'audio/mpeg':'application/json');
  let start=0,end=stat.size-1,status=200;
  if(req.headers.range && (!req.headers['if-range']||req.headers['if-range']===etag)){
   const m=/^bytes=(\d+)-(\d*)$/.exec(req.headers.range);
   if(!m || Number(m[1])>=stat.size || (m[2] && Number(m[2])<Number(m[1]))){res.writeHead(416,{'Content-Range':`bytes */${stat.size}`}).end();return;}
   start=Number(m[1]);end=m[2]?Math.min(Number(m[2]),end):end;status=206;res.setHeader('Content-Range',`bytes ${start}-${end}/${stat.size}`);
  }
  res.writeHead(status,{'Content-Length':end-start+1});
  if(req.method==='HEAD')res.end();else fs.createReadStream(file,{start,end}).pipe(res);
 }catch{res.writeHead(404).end('Fixture absente');}
}).listen(port,'127.0.0.1',()=>console.log(`Fixtures privées locales : http://127.0.0.1:${port}. Android USB : adb reverse tcp:${port} tcp:${port}.`));
