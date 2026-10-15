import 'dart:convert';

import 'package:flutter/services.dart';

import 'dua.dart';

final _arabicDiacritics = RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED]');
final _alefVariants = RegExp('[أإآٱ]');
final _apostrophes = RegExp("[’'`´ʿʾ]");
final _notSearchable = RegExp(
  r'[^a-z0-9\u0600-\u06ff\u0A80-\u0AFF]+',
  unicode: true,
);
final _whitespace = RegExp(r'\s+');

const _folds = <String, String>{
  'àáâäãåāăą': 'a',
  'ćč': 'c',
  'ç': 's',
  'ďđḍ': 'd',
  'èéêëēĕėę': 'e',
  'ìíîïī': 'i',
  'ñń': 'n',
  'òóôöõō': 'o',
  'ùúûüūŭů': 'u',
  'ýÿ': 'y',
  'ḥħ': 'h',
  'ṣš': 's',
  'ṭþ': 't',
  'ẓżž': 'z',
  'ġğ': 'g',
};

final _foldPatterns = [
  for (final entry in _folds.entries)
    MapEntry(RegExp('[${entry.key}]'), entry.value),
];

final _searchDocs = Expando<List<_SearchDoc>>();

class LocalDevotionalCatalog {
  const LocalDevotionalCatalog(this.items);
  final List<DevotionalText> items;

  static Future<LocalDevotionalCatalog> load() async {
    final rows = jsonDecode(
      await rootBundle.loadString('assets/content/catalog.json'),
    ) as List<dynamic>;
    final catalog = LocalDevotionalCatalog([
      for (final row in rows)
        DevotionalText.fromJson(row as Map<String, dynamic>),
    ]);
    _docsOf(catalog);
    return catalog;
  }

  List<DevotionalText> get duas => ofKind(DevotionalKind.dua);

  List<DevotionalText> ofKind(DevotionalKind kind) =>
      items.where((item) => item.kind == kind).toList();

  List<DevotionalText> search(String query, {DevotionalKind? kind}) {
    final words = _searchable(query)
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList();
    // Une ou deux lettres se trouvent dans presque chaque prière.
    // On les cherche dans le titre, pas dans le corps.
    // Dès qu’un titre correspond, les autres textes qui ne font que
    // citer le mot ne sont pas proposés.
    final inBody = words.isNotEmpty && words.every((word) => word.length >= 3);
    final titles = <DevotionalText>[];
    final others = <DevotionalText>[];
    for (final doc in _docsOf(this)) {
      if (kind != null && doc.item.kind != kind) continue;
      if (words.isEmpty) {
        others.add(doc.item);
        continue;
      }
      if (words.every((word) => _titleMatches(word, doc))) {
        titles.add(doc.item);
      } else if (inBody && words.every((word) => _bodyMatches(word, doc))) {
        others.add(doc.item);
      }
    }
    if (titles.isNotEmpty) return titles;
    return others;
  }
}

List<_SearchDoc> _docsOf(LocalDevotionalCatalog catalog) =>
    _searchDocs[catalog] ??= [
      for (final item in catalog.items) _SearchDoc.from(item),
    ];

class _SearchDoc {
  const _SearchDoc({
    required this.item,
    required this.title,
    required this.forms,
    required this.tokenKeys,
    required this.bodyTokens,
  });

  final DevotionalText item;
  final String title;

  /// Mots du titre, mots collés (Ya-Sin, al-Fatiha) et leurs graphies.
  final Set<String> forms;
  final List<String> tokenKeys;
  final Set<String> bodyTokens;

  factory _SearchDoc.from(DevotionalText item) {
    final title = _searchable(item.title);
    final haystack = _searchable(
      [
        item.title,
        item.arabic,
        item.translation,
        item.transliteration,
        item.gujarati,
        item.introduction,
        ...item.references,
      ].join(' '),
    );
    return _SearchDoc._(item, title, _tokenSet(haystack));
  }

  factory _SearchDoc.fromPlain(String text) {
    final title = _searchable(text);
    final tokens = _tokenSet(title);
    return _SearchDoc._(
      DevotionalText(
        id: '',
        kind: DevotionalKind.dua,
        title: text,
        arabic: '',
        translation: '',
        transliteration: '',
        references: const [],
        audioIds: const [],
      ),
      title,
      tokens,
    );
  }

  factory _SearchDoc._(DevotionalText item, String title, Set<String> body) {
    final tokens = title.split(' ').where((token) => token.isNotEmpty).toList();
    return _SearchDoc(
      item: item,
      title: title,
      forms: _forms(tokens),
      tokenKeys: _tokenKeys(tokens),
      bodyTokens: body,
    );
  }
}

final _digits = RegExp(r'^\d+$');

Set<String> _tokenSet(String text) {
  final tokens = <String>{};
  for (final token in text.split(' ')) {
    if (token.isEmpty) continue;
    tokens.addAll(_keys(token));
  }
  return tokens;
}

Set<String> _forms(List<String> tokens) {
  final forms = <String>{};
  for (final token in tokens) {
    forms.addAll(_keys(token));
  }
  for (var i = 0; i < tokens.length - 1; i++) {
    if (_digits.hasMatch(tokens[i]) || _digits.hasMatch(tokens[i + 1])) {
      continue;
    }
    forms.addAll(_keys(tokens[i] + tokens[i + 1]));
  }
  return forms;
}

List<String> _tokenKeys(List<String> tokens) {
  final keys = <String>{};
  for (final token in tokens) {
    for (final key in _keys(token)) {
      if (key.length >= 4) keys.add(key);
    }
  }
  return keys.toList();
}

/// Lettres doublées, h final et e muet comptent pour la même graphie.
String _stem(String word) {
  final buffer = StringBuffer();
  var previous = 0;
  for (final code in word.codeUnits) {
    if (code == previous) continue;
    buffer.writeCharCode(code);
    previous = code;
  }
  final stem = buffer.toString();
  if (stem.endsWith('h') && stem.length >= 6) {
    return stem.substring(0, stem.length - 1);
  }
  return stem;
}

Set<String> _keys(String word) {
  final stem = _stem(word);
  final keys = <String>{stem};
  if (stem.endsWith('e') && stem.length > 4) {
    keys.add(stem.substring(0, stem.length - 1));
  }
  final swapped = <String>[];
  for (final key in keys) {
    if (key.length <= 4) continue;
    if (key.endsWith('c')) {
      swapped.add('${key.substring(0, key.length - 1)}s');
    } else if (key.endsWith('s')) {
      swapped.add('${key.substring(0, key.length - 1)}c');
    }
  }
  keys.addAll(swapped);
  return keys;
}

bool _titleMatches(String word, _SearchDoc doc) {
  if (word.length < 3) return doc.title.contains(word);
  for (final key in _keys(word)) {
    if (doc.forms.contains(key)) return true;
  }
  final stem = _stem(word);
  if (stem.length < 4) return false;
  for (final token in doc.tokenKeys) {
    if (_nearName(stem, token)) return true;
  }
  return false;
}

bool _bodyMatches(String word, _SearchDoc doc) {
  if (_titleMatches(word, doc)) return true;
  for (final key in _keys(word)) {
    if (doc.bodyTokens.contains(key)) return true;
  }
  return false;
}

bool _isVowel(int code) =>
    code == 0x61 ||
    code == 0x65 ||
    code == 0x69 ||
    code == 0x6f ||
    code == 0x75 ||
    code == 0x79;

/// Une voyelle changée, ou une lettre en plus ou en moins.
/// Une consonne remplacée (hassan / yassin, qadr / qabr) ne correspond pas.
bool _nearName(String a, String b) {
  if (a == b || (a.length - b.length).abs() > 1) return false;
  if (a.length < 4 || b.length < 4) return false;
  if (a.length == b.length) {
    var diffs = 0;
    for (var i = 0; i < a.length; i++) {
      if (a.codeUnitAt(i) == b.codeUnitAt(i)) continue;
      if (!_isVowel(a.codeUnitAt(i)) || !_isVowel(b.codeUnitAt(i))) {
        return false;
      }
      if (++diffs > 1) return false;
    }
    return diffs == 1;
  }
  final longer = a.length > b.length ? a : b;
  final shorter = a.length > b.length ? b : a;
  var i = 0;
  var j = 0;
  var skipped = false;
  while (i < longer.length && j < shorter.length) {
    if (longer.codeUnitAt(i) == shorter.codeUnitAt(j)) {
      i++;
      j++;
    } else if (skipped) {
      return false;
    } else {
      skipped = true;
      i++;
    }
  }
  return true;
}

String _searchable(String value) {
  var text = value.toLowerCase();
  text = text.replaceAll(_arabicDiacritics, '');
  text = text.replaceAll(_alefVariants, 'ا');
  text = text.replaceAll('ة', 'ه');
  text = text.replaceAll('ى', 'ي');
  for (final entry in _foldPatterns) {
    text = text.replaceAll(entry.key, entry.value);
  }
  text = text.replaceAll(_apostrophes, '');
  text = text.replaceAll('ch', 'sh');
  text = text.replaceAll('ou', 'u');
  text = text.replaceAll('aa', 'a');
  text = text.replaceAll('ee', 'i');
  text = text.replaceAll('ii', 'i');
  return text
      .replaceAll(_notSearchable, ' ')
      .replaceAll(_whitespace, ' ')
      .replaceAll(_ramadanSpellings, 'ramadan')
      .trim();
}

final _ramadanSpellings = RegExp(
  r'\bramadha+n\b|\bramzane\b|\bramzan\b|\bramadan\b',
);

/// Vrai quand [text] contient chaque mot de [query], avec les mêmes
/// tolérances que la recherche du catalogue.
bool matchesSearchQuery(String query, String text) {
  final words = _searchable(query)
      .split(' ')
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return false;
  final doc = _SearchDoc.fromPlain(text);
  return words.every((word) => _bodyMatches(word, doc));
}
