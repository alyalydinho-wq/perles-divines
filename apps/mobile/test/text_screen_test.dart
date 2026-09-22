import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perles_divines/features/catalog/text_screen.dart';
import 'package:perles_divines/features/duas/dua.dart';
import 'package:perles_divines/features/reader/content_install.dart';
import 'package:perles_divines/ui/heritage.dart';

void main() {
  test('le chronomètre de lecture reste lisible', () {
    expect(formatPlaybackClock(Duration.zero), '0:00');
    expect(formatPlaybackClock(const Duration(minutes: 9, seconds: 16)), '9:16');
    expect(formatPlaybackClock(const Duration(seconds: -3)), '0:00');
  });

  testWidgets('la recherche est au-dessus des catégories', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              HeritageSearchField(controller: controller),
              HeritageCategoryTile(title: 'Duas', onTap: () {}),
            ],
          ),
        ),
      ),
    );
    expect(
      tester.getTopLeft(find.byType(HeritageSearchField)).dy,
      lessThan(tester.getTopLeft(find.byType(HeritageCategoryTile)).dy),
    );
  });

  testWidgets(
    'l’écran de texte a les trois onglets sans second lecteur',
    (tester) async {
      const item = DevotionalText(
        id: 'ziyarat-1',
        kind: DevotionalKind.ziyarat,
        title: 'Ziyarat e Aale Yasin',
        arabic: 'بِسْمِ اللّٰهِ',
        translation: 'Au nom d’Allàh, le Tout Miséricordieux.',
        transliteration: 'BISMILLAHIR RAHMANIR RAHEEM',
        references: [],
        audioIds: [],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: TextScreen(
            item: item,
            edition: LocalEdition('/tmp', const {'home': 'index.html'}),
            favorite: false,
            onFavorite: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Arabic'), findsOneWidget);
      expect(find.text('Translation'), findsOneWidget);
      expect(find.text('Transliteration'), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
      expect(find.text('Au nom d’Allàh, le Tout Miséricordieux.'), findsOneWidget);

      await tester.tap(find.text('Transliteration'));
      await tester.pumpAndSettle();
      expect(find.text('BISMILLAHIR RAHMANIR RAHEEM'), findsOneWidget);

      await tester.tap(find.text('Arabic'));
      await tester.pumpAndSettle();
      expect(find.text('بِسْمِ اللّٰهِ'), findsOneWidget);

      await tester.tap(find.byTooltip('Lire'));
      await tester.pumpAndSettle();
      expect(
        find.text('Aucun audio n’est encore associé à ce texte.'),
        findsOneWidget,
      );
    },
  );
}
