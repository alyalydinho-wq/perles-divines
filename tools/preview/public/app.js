const $ = id => document.getElementById(id);
const reader = $('reader'), stack = [];
const inventory = await fetch('/api/inventory').then(r => r.json());
const home = inventory.pages.find(p => p.url.endsWith('/sommaire.html'));
$('status').textContent = `${inventory.report.pages} pages préparées · ${inventory.report.brokenLinks} liens internes signalés dans le rapport`;
function openPage(url) { reader.src = url; }
$('home').onclick = () => openPage(`/content/${home.path}`);
$('back').onclick = () => { stack.pop(); const previous = stack.pop(); openPage(previous ?? `/content/${home.path}`); };
$('close-dialog').onclick = () => $('external').close();
reader.addEventListener('load', () => {
  const doc = reader.contentDocument, win = reader.contentWindow;
  if (!doc || !win) return;
  const key = win.location.pathname;
  if (stack.at(-1) !== win.location.href) stack.push(win.location.href);
  $('label').textContent = 'Lecture locale';
  // The source remains script-free. Only this bundled parent owns interactions.
  const saved = Number(localStorage.getItem(`reader:${key}`) ?? 0);
  if (!win.location.hash) win.scrollTo(0, saved);
  win.addEventListener('scroll', () => {
    const maximum = doc.documentElement.scrollHeight - win.innerHeight;
    $('progress').value = maximum > 0 ? win.scrollY / maximum * 100 : 100;
    localStorage.setItem(`reader:${key}`, win.scrollY);
  });
  doc.addEventListener('click', e => {
    const anchor = e.target.closest('a[href]');
    if (!anchor) return;
    const url = new URL(anchor.href, win.location.href);
    if (url.origin === location.origin) return;
    e.preventDefault();
    $('external-message').textContent = navigator.onLine ? `Une connexion Internet est nécessaire : ${url.href}` : 'Vous êtes hors connexion. Cette destination externe nécessite Internet.';
    $('open-external').href = url.href;
    $('open-external').hidden = !navigator.onLine;
    $('external').showModal();
  });
  $('anchors').replaceChildren();
  const seen = new Set();
  for (const a of doc.querySelectorAll('a[href*="#"]')) {
    const url = new URL(a.href, win.location.href);
    if (url.pathname !== win.location.pathname || !url.hash || seen.has(url.hash)) continue;
    const text = a.textContent.trim() || ({'#TRADUCTION':'Traduction','#TRANSLITTERATION':'Translittération','#INFO':'Informations'}[url.hash] ?? '');
    if (!/traduc|translit|inform|infos/i.test(text)) continue;
    const button = document.createElement('button'); button.textContent = text;
    button.onclick = () => { win.location.hash = url.hash; };
    $('anchors').append(button); seen.add(url.hash);
  }
});
openPage(`/content/${home.path}`);
