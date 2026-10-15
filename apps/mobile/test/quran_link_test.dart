import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:perles_divines/features/duas/dua.dart';
import 'package:perles_divines/features/reader/reader_screen.dart';

void main() {
  const fatihah = '7918100a-56f9-5035-b4b0-46e1e2c53b32';

  test('un lien de sourate dans une page locale désigne le catalogue', () {
    final edition = p.join(Directory.systemTemp.path, 'pd-edition');
    final page = Uri.file(p.join(edition, 'pages', '$fatihah.html'));
    expect(localCatalogId(page, edition), fatihah);
    expect(
      localCatalogId(page.replace(fragment: 'TRADUCTION'), edition),
      fatihah,
    );
    expect(
      localCatalogId(Uri.file(p.join(edition, 'pages', 'index.html')), edition),
      isNull,
    );
    expect(
      localCatalogId(
        Uri.file(p.join(Directory.systemTemp.path, '$fatihah.html')),
        edition,
      ),
      isNull,
    );
    expect(
      localCatalogId(Uri.parse('https://example.test/fateha.html'), edition),
      isNull,
    );
  });

  test('seule une sourate déjà mise à jour quitte l’ancienne page', () {
    const updated = DevotionalText(
      id: fatihah,
      kind: DevotionalKind.quran,
      title: 'Sourate al-Fâtihah (1)',
      arabic: 'بِسْمِ',
      translation: '',
      transliteration: '',
      references: [],
      audioIds: [],
    );
    const stillOriginal = DevotionalText(
      id: 'ancienne',
      kind: DevotionalKind.quran,
      title: 'Ancienne',
      arabic: 'بِسْمِ',
      translation: '',
      transliteration: '',
      references: [],
      audioIds: [],
      pagePath: 'pages/ancienne.html',
    );
    const namaz = DevotionalText(
      id: 'ghofaylah',
      kind: DevotionalKind.namaz,
      title: 'Namaz-e-Ghofaylah',
      arabic: '',
      translation: '',
      transliteration: '',
      references: [],
      audioIds: [],
      pagePath: 'pages/ghofaylah.html',
    );
    expect(updated.opensUpdatedReading, isTrue);
    expect(stillOriginal.opensUpdatedReading, isFalse);
    expect(namaz.opensUpdatedReading, isFalse);
  });
}
