import fs from 'node:fs/promises';
const names=['flutter_riverpod','go_router','just_audio','audio_service','audio_session','background_downloader','drift','drift_flutter','path_provider','path','crypto','webview_flutter','webview_flutter_android','webview_flutter_wkwebview','share_plus','url_launcher','connectivity_plus','drift_dev','build_runner'];
const packages=await Promise.all(names.map(async name=>{
 const r=await fetch(`https://pub.dev/api/packages/${name}`); if(!r.ok)throw Error(`${name}: ${r.status}`);
 const data=await r.json();return {name,version:data.latest.version,environment:data.latest.pubspec.environment,dependencies:data.latest.pubspec.dependencies};
}));
const dep=packages.filter(p=>!['drift_dev','build_runner'].includes(p.name));
const dev=packages.filter(p=>['drift_dev','build_runner'].includes(p.name));
await fs.writeFile('apps/mobile/pubspec.yaml',`name: perles_divines\ndescription: Perles Divines — lecture et audio hors connexion\npublish_to: none\nversion: 0.1.0+1\nenvironment:\n  sdk: '>=3.13.0 <4.0.0'\ndependencies:\n  flutter:\n    sdk: flutter\n${dep.map(p=>`  ${p.name}: ${p.version}`).join('\n')}\ndev_dependencies:\n  flutter_test:\n    sdk: flutter\n  flutter_lints: 6.0.0\n${dev.map(p=>`  ${p.name}: ${p.version}`).join('\n')}\nflutter:\n  uses-material-design: true\n  assets:\n    - assets/content/\n    - assets/site/\n    - assets/site/pages/\n    - assets/site/assets/\n    - assets/fixtures/\n    - assets/audio/\n`);
await fs.writeFile('docs/evidence/pub-versions.json',JSON.stringify({checkedAt:new Date().toISOString(),source:'https://pub.dev/api/packages/',packages},null,2));
console.log(packages.map(p=>`${p.name} ${p.version}`).join('\n'));
