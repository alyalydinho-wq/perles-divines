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

  test('une ziyarat déjà mise à jour quitte l’ancienne page', () {
    const waressa = DevotionalText(
      id: 'bbdbbae1-f4c7-5fba-abbc-76f7522b88df',
      kind: DevotionalKind.ziyarat,
      title: 'Zyaarat-e-Wâressa',
      arabic: 'اَلسَّلَامُ',
      translation: '',
      transliteration: '',
      references: [],
      audioIds: [],
    );
    const stillOriginal = DevotionalText(
      id: 'b272d8c5-a3d9-541b-b260-44618c9d3dd5',
      kind: DevotionalKind.ziyarat,
      title: 'Zyaarate de tous les jours',
      arabic: 'اَلسَّلَامُ',
      translation: '',
      transliteration: '',
      references: [],
      audioIds: [],
      pagePath: 'pages/b272d8c5-a3d9-541b-b260-44618c9d3dd5.html',
    );
    const safarDua = DevotionalText(
      id: 'c97581bf-b0ab-5a0b-8c74-0c4813dce712',
      kind: DevotionalKind.dua,
      title: 'Doua du mois de Safar',
      arabic: 'يَا',
      translation: '',
      transliteration: '',
      references: [],
      audioIds: [],
    );
    expect(waressa.opensUpdatedReading, isTrue);
    expect(stillOriginal.opensUpdatedReading, isFalse);
    expect(safarDua.opensUpdatedReading, isFalse);
    for (final id in [
      'aa86b04c-fb45-5c4a-9943-170dddb31104',
      '9bbdc6dc-c3fc-50d3-b79a-45b63216bc69',
      '213aa396-99b9-535f-bf8f-a862abbc66e3',
      // Jawshan-e-Kabir depuis les nuits de Qadr, Kumayl depuis le 15 Shabaan.
      'a6a50d78-0076-5d00-95f2-c3a732c97077',
      'fda4b6e3-5c57-5c03-a292-1981a9768248',
    ]) {
      expect(
        DevotionalText(
          id: id,
          kind: DevotionalKind.dua,
          title: 'Doua',
          arabic: 'يَا',
          translation: '',
          transliteration: '',
          references: [],
          audioIds: [],
        ).opensUpdatedReading,
        isTrue,
        reason: id,
      );
    }
    final edition = p.join(Directory.systemTemp.path, 'pd-edition');
    expect(
      decideReaderNavigation(
        Uri.file(p.join(edition, 'pages', '${waressa.id}.html')),
        editionDirectory: edition,
        opensUpdatedText: (id) =>
            id == waressa.id && waressa.opensUpdatedReading,
      ),
      ReaderNavigation.openUpdatedText,
    );
  });

  test('une page d’origine seule n’a pas d’onglets de traduction', () {
    const aamal = DevotionalText(
      id: 'moharram',
      kind: DevotionalKind.aamal,
      title: 'Aamal du mois de Moharram',
      arabic: '',
      translation: '',
      transliteration: '',
      references: [],
      audioIds: [],
      pagePath: 'pages/moharram.html',
    );
    const translated = DevotionalText(
      id: 'zyaarate',
      kind: DevotionalKind.ziyarat,
      title: 'Zyaarate de tous les jours',
      arabic: '',
      translation: 'Que la paix soit sur toi.',
      transliteration: '',
      references: [],
      audioIds: [],
      pagePath: 'pages/zyaarate.html',
    );
    expect(aamal.onlyOriginalPage, isTrue);
    expect(translated.onlyOriginalPage, isFalse);
  });
}
