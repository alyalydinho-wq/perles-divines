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
  'çćč': 'c',
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
    // On les cherche dans le titre et la translittération, pas dans le corps.
    final inBody = words.isNotEmpty && words.every((word) => word.length >= 3);
    final titles = <DevotionalText>[];
    final others = <DevotionalText>[];
    for (final doc in _docsOf(this)) {
      if (kind != null && doc.item.kind != kind) continue;
      if (words.isEmpty) {
        others.add(doc.item);
        continue;
      }
      if (!words.every((word) => _wordMatches(word, doc, inBody))) continue;
      if (words.every((word) => doc.title.contains(word))) {
        titles.add(doc.item);
      } else {
        others.add(doc.item);
      }
    }
    return [...titles, ...others];
  }
}

List<_SearchDoc> _docsOf(LocalDevotionalCatalog catalog) =>
    _searchDocs[catalog] ??= [
      for (final item in catalog.items) _SearchDoc.from(item),
    ];

class _SearchDoc {
  const _SearchDoc({
    required this.item,
    required this.haystack,
    required this.heading,
    required this.title,
    required this.tokensByLength,
  });

  final DevotionalText item;
  final String haystack;
  final String heading;
  final String title;
  final Map<int, List<String>> tokensByLength;

  factory _SearchDoc.from(DevotionalText item) {
    final title = _searchable(item.title);
    final heading = _searchable('${item.title} ${item.transliteration}');
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
    final tokensByLength = <int, List<String>>{};
    final seen = <String>{};
    for (final token in heading.split(' ')) {
      if (token.length < 3 || !seen.add(token)) continue;
      (tokensByLength[token.length] ??= []).add(token);
    }
    return _SearchDoc(
      item: item,
      haystack: haystack,
      heading: heading,
      title: title,
      tokensByLength: tokensByLength,
    );
  }

  factory _SearchDoc.fromPlain(String text) {
    final heading = _searchable(text);
    final tokensByLength = <int, List<String>>{};
    final seen = <String>{};
    for (final token in heading.split(' ')) {
      if (token.length < 3 || !seen.add(token)) continue;
      (tokensByLength[token.length] ??= []).add(token);
    }
    return _SearchDoc(
      item: DevotionalText(
        id: '',
        kind: DevotionalKind.dua,
        title: text,
        arabic: '',
        translation: '',
        transliteration: '',
        references: const [],
        audioIds: const [],
      ),
      haystack: heading,
      heading: heading,
      title: heading,
      tokensByLength: tokensByLength,
    );
  }
}

bool _wordMatches(String word, _SearchDoc doc, bool inBody) {
  if ((inBody ? doc.haystack : doc.heading).contains(word)) return true;
  if (word.length < 4) return false;
  final maxDistance = word.length >= 6 ? 2 : 1;
  final shortest = word.length - maxDistance;
  final longest = word.length + maxDistance;
  for (var length = shortest; length <= longest; length++) {
    final tokens = doc.tokensByLength[length];
    if (tokens == null) continue;
    for (final token in tokens) {
      if (_distance(word, token) <= maxDistance) return true;
    }
  }
  return false;
}

int _distance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var previous = List<int>.generate(b.length + 1, (index) => index);
  for (var i = 0; i < a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0);
    current[0] = i + 1;
    for (var j = 0; j < b.length; j++) {
      final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
      current[j + 1] = [
        current[j] + 1,
        previous[j + 1] + 1,
        previous[j] + cost,
      ].reduce((left, right) => left < right ? left : right);
    }
    previous = current;
  }
  return previous.last;
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
/// tolérances que la recherche du catalogue (titre ou corps).
bool matchesSearchQuery(String query, String text) {
  final words = _searchable(query)
      .split(' ')
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return false;
  final doc = _SearchDoc.fromPlain(text);
  final inBody = words.every((word) => word.length >= 3);
  return words.every((word) => _wordMatches(word, doc, inBody));
}
