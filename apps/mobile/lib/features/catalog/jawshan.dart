import 'dart:convert';

import 'package:flutter/services.dart';

/// Doua-e-Jawshan-e-Kabir. Les textes restent ceux du catalogue :
/// ce module ne fait que reconnaître les 100 parties déjà délimitées.
const jawshanKabirId = 'a6a50d78-0076-5d00-95f2-c3a732c97077';

bool isJawshanKabirId(String id) => id == jawshanKabirId;

class JawshanTitle {
  const JawshanTitle({
    required this.number,
    required this.english,
    required this.french,
  });

  final int number;
  final String english;
  final String french;
}

class JawshanTranslation {
  const JawshanTranslation({required this.preamble, required this.parts});

  /// Basmala française, avant « 1 - ». Vide s’il n’y en a pas.
  final String preamble;

  /// Parties 1 à 100, texte du catalogue inchangé, y compris « N - ».
  final List<String> parts;
}

/// Parties séparées par une ligne vide. Le texte interne de chaque partie
/// reste tel quel, retours à la ligne compris.
List<String> jawshanBlocks(String value) => value
    .split(RegExp(r'\n{2,}'))
    .map((block) => block.trim())
    .where((block) => block.isNotEmpty)
    .toList();

/// La traduction du catalogue est un seul paragraphe. Chaque partie commence
/// par « N - », de 1 à 100, dans l’ordre. Tout autre découpage renvoie null.
JawshanTranslation? parseJawshanTranslation(String value) {
  final markers = RegExp(r'(?:^|\s)(\d{1,3}) - ').allMatches(value).toList();
  if (markers.length != 100) return null;
  final parts = <String>[];
  for (var i = 0; i < markers.length; i++) {
    final match = markers[i];
    final number = int.parse(match.group(1)!);
    if (number != i + 1) return null;
    final start = match.start + (value[match.start] == ' ' ? 1 : 0);
    final end = i + 1 < markers.length ? markers[i + 1].start : value.length;
    final part = value.substring(start, end).trim();
    if (part.isEmpty) return null;
    parts.add(part);
  }
  return JawshanTranslation(
    preamble: value.substring(0, markers.first.start).trim(),
    parts: parts,
  );
}

/// Hadith d’introduction, sans la liste « Doua - N » qui sert de sommaire.
String jawshanHadith(String introduction) => introduction
    .split(RegExp(r'\n+'))
    .map((line) => line.trim())
    .where(
      (line) =>
          line.isNotEmpty && !RegExp(r'^Doua\s*-\s*\d+\s*$').hasMatch(line),
    )
    .join('\n\n');

Future<List<JawshanTitle>> loadJawshanTitles() async {
  final raw = await rootBundle.loadString(
    'assets/content/jawshan_titles_fr.json',
  );
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return [
    for (final entry in json['titles'] as List)
      JawshanTitle(
        number: (entry as Map<String, dynamic>)['n'] as int,
        english: entry['en'] as String,
        french: entry['fr'] as String,
      ),
  ];
}
