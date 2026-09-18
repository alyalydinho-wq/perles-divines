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

  List<DevotionalText> get duas =>
      items.where((item) => item.kind == DevotionalKind.dua).toList();

  List<DevotionalText> search(String query) {
    final words = _searchable(
      query,
    ).split(' ').where((word) => word.isNotEmpty);
    return items.where((item) {
      final value = _searchable([
        item.title,
        item.arabic,
        item.translation,
        item.transliteration,
        ...item.references,
      ].join(' '));
      return words.every(value.contains);
    }).toList();
  }
}

String _searchable(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[àáâäãå]'), 'a')
    .replaceAll(RegExp('[ç]'), 'c')
    .replaceAll(RegExp('[èéêë]'), 'e')
    .replaceAll(RegExp('[ìíîï]'), 'i')
    .replaceAll(RegExp('[ñ]'), 'n')
    .replaceAll(RegExp('[òóôöõ]'), 'o')
    .replaceAll(RegExp('[ùúûü]'), 'u')
    .replaceAll(RegExp('[ýÿ]'), 'y')
    .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06ff]+', unicode: true), ' ')
    .trim();
