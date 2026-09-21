import { load } from 'cheerio';

const MARKER = /^(TRANSLITT[EÉ]RATION|TRADUCTION|INFO(?:RMATIONS?)?)$/i;

export function visibleText(value) {
  return String(value ?? '')
    .replace(/\u00a0/g, ' ')
    .replace(/[ \t\f\v]+/g, ' ')
    .replace(/\s*\n\s*/g, '\n')
    .trim();
}

export function compactText(value) {
  return visibleText(value).replace(/\s+/g, ' ').trim();
}

export function extractSections(html) {
  const $ = load(html);
  $('script,style').remove();
  $('br').replaceWith('\n');
  const blocks = [];
  $('body p, body h1, body h2, body h3, body li').each((_, el) => {
    const text = compactText($(el).text());
    if (text) blocks.push(text);
  });
  const idxTrans = blocks.findIndex(block => /^TRANSLITT[EÉ]RATION$/i.test(block));
  const idxTrad = blocks.findIndex(block => /^TRADUCTION$/i.test(block));
  const idxInfo = blocks.findIndex(block => /^INFO(?:RMATIONS?)?$/i.test(block));
  const firstMarker = [idxTrans, idxTrad, idxInfo]
    .filter(i => i >= 0)
    .sort((a, b) => a - b)[0] ?? blocks.length;
  const slice = (from, until) => {
    if (from < 0) return '';
    const end = until.filter(i => i > from).sort((a, b) => a - b)[0] ?? blocks.length;
    return blocks.slice(from + 1, end).filter(block => !MARKER.test(block)).join('\n\n').trim();
  };
  const preface = blocks.slice(0, firstMarker).filter(block => !MARKER.test(block));
  const arabic = compactText(
    $('body')
      .text()
      .match(/[\u0600-\u06FF][\u0600-\u06FF\s\u064B-\u065F\u0670\u0640]*/g)
      ?.join('\n') ?? '',
  );
  return {
    blocks,
    title: preface[0] ?? '',
    introduction: preface.slice(1).join('\n\n').trim(),
    transliteration: slice(idxTrans, [idxTrad, idxInfo]),
    translation: slice(idxTrad, [idxTrans, idxInfo]),
    info: slice(idxInfo, [idxTrans, idxTrad]),
    arabic,
  };
}

export function indexButtons(html) {
  const $ = load(html);
  $('br').replaceWith(' ');
  return $('a.button')
    .map((_, el) => ({
      title: compactText($(el).text()),
      href: ($(el).attr('href') ?? '').split(/[?#]/)[0],
    }))
    .get()
    .filter(item => item.title && item.href && !/^retour/i.test(item.title));
}

export function kindLabel(kind) {
  return {
    dua: 'Duʿā',
    ziyarat: 'Ziyārāt',
    quran: 'Qurʾan',
    namaz: 'Namaz',
    aamal: 'Aamal',
  }[kind] ?? kind;
}
