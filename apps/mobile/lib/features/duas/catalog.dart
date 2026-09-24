import 'dart:convert';

import 'package:flutter/services.dart';

import 'dua.dart';

class LocalDevotionalCatalog {
  const LocalDevotionalCatalog(this.items);
  final List<DevotionalText> items;

  static Future<LocalDevotionalCatalog> load() async {
    final rows = jsonDecode(
      await rootBundle.loadString('assets/content/catalog.json'),
    ) as List<dynamic>;
    return LocalDevotionalCatalog([
      for (final row in rows)
        DevotionalText.fromJson(row as Map<String, dynamic>),
    ]);
  }

  List<DevotionalText> get duas => ofKind(DevotionalKind.dua);

  List<DevotionalText> ofKind(DevotionalKind kind) =>
      items.where((item) => item.kind == kind).toList();

  List<DevotionalText> search(String query, {DevotionalKind? kind}) {
    final words = _searchable(
      query,
    ).split(' ').where((word) => word.isNotEmpty);
    return items.where((item) {
      if (kind != null && item.kind != kind) return false;
      final value = _searchable([
        item.title,
        item.arabic,
        item.translation,
        item.transliteration,
        item.introduction,
        ...item.references,
      ].join(' '));
      return words.every((word) => _wordMatches(word, value));
    }).toList();
  }
}

bool _wordMatches(String word, String haystack) {
  if (haystack.contains(word)) return true;
  if (word.length < 4) return false;
  final maxDistance = word.length >= 6 ? 2 : 1;
  for (final token in haystack.split(' ')) {
    if ((token.length - word.length).abs() > maxDistance) continue;
    if (_distance(word, token) <= maxDistance) return true;
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
  text = text.replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED]'), '');
  text = text.replaceAll(RegExp('[أإآٱ]'), 'ا');
  text = text.replaceAll('ة', 'ه');
  text = text.replaceAll('ى', 'ي');
  const folds = <String, String>{
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
  for (final entry in folds.entries) {
    text = text.replaceAll(RegExp('[${entry.key}]'), entry.value);
  }
  text = text.replaceAll(RegExp("[’'`´ʿʾ]"), '');
  text = text.replaceAll('ch', 'sh');
  text = text.replaceAll('ou', 'u');
  text = text.replaceAll('aa', 'a');
  return text
      .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06ff]+', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
