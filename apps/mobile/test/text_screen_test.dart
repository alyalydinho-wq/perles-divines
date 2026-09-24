import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perles_divines/core/store.dart';
import 'package:perles_divines/features/catalog/text_screen.dart';
import 'package:perles_divines/features/duas/dua.dart';
import 'package:perles_divines/features/reader/content_install.dart';
import 'package:perles_divines/ui/heritage.dart';

void main() {
  test('le chronomètre de lecture reste lisible', () {
    expect(formatPlaybackClock(Duration.zero), '0:00');
    expect(
      formatPlaybackClock(const Duration(minutes: 9, seconds: 16)),
      '9:16',
    );
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

  testWidgets('l’écran de texte a les trois onglets sans second lecteur', (
    tester,
  ) async {
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
    expect(
      find.text('Au nom d’Allàh, le Tout Miséricordieux.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Transliteration'));
    await tester.pumpAndSettle();
    expect(find.text('BISMILLAHIR RAHMANIR RAHEEM'), findsOneWidget);

    await tester.tap(find.text('Arabic'));
    await tester.pumpAndSettle();
    final arabic = tester.widget<Text>(find.text('بِسْمِ اللّٰهِ'));
    expect(arabic.style!.height, lessThan(2.2));
    await tester.tap(find.byTooltip('Taille du texte'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Agrandir l’arabe'), findsOneWidget);
    expect(find.byTooltip('Agrandir la traduction'), findsOneWidget);
    expect(find.byTooltip('Agrandir la translittération'), findsOneWidget);

    await tester.tap(find.byTooltip('Lire'));
    await tester.pumpAndSettle();
    expect(
      find.text('Aucun audio n’est encore associé à ce texte.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'une sourate montre le numéro de chaque verset et des tailles indépendantes',
    (tester) async {
      const verse1 = 'اِذَا وَقَعَتِ الْوَاقِعَةُ';
      const verse2 = 'لَيْسَ لِوَقْعَتِهَا كَاذِبَةٌ';
      const item = DevotionalText(
        id: 'quran-56',
        kind: DevotionalKind.quran,
        title: "Sourate al-Wâqi'ah (56)",
        arabic: 'بِسْمِ اللّٰهِ\n\nاِذَا وَقَعَتِ الْوَاقِعَةُ ﴿١﴾\nلَيْسَ لِوَقْعَتِهَا كَاذِبَةٌ ﴿٢﴾',
        translation: 'Quand l’événement arrivera.',
        transliteration: 'Bismillaah\n\nIzaa waqa\nLaisa liwaq',
        references: [],
        audioIds: [],
      );
      final store = AppStore(NativeDatabase.memory());
      addTearDown(store.close);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: TextScreen(
            item: item,
            edition: LocalEdition('/tmp', const {'home': 'index.html'}),
            favorite: false,
            onFavorite: () async {},
            store: store,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Quand l’événement arrivera.'), findsOneWidget);

      await tester.tap(find.text('Arabic'));
      await tester.pumpAndSettle();
      expect(find.text('بِسْمِ اللّٰهِ'), findsOneWidget);
      expect(find.text(verse1), findsOneWidget);
      expect(find.text(verse2), findsOneWidget);
      expect(find.textContaining('﴿'), findsNothing);
      expect(find.text('\u06F1'), findsOneWidget);
      expect(find.text('\u06F2'), findsOneWidget);

      final first = tester.getTopLeft(find.text(verse1));
      final second = tester.getTopLeft(find.text(verse2));
      expect(first.dy, lessThan(second.dy - 8));
      expect(tester.widget<Text>(find.text(verse1)).maxLines, isNull);
      expect(
        tester.widget<Text>(find.text(verse1)).style!.fontSize,
        tester.widget<Text>(find.text(verse2)).style!.fontSize,
      );
      expect(
        tester.getTopLeft(find.text('بِسْمِ اللّٰهِ')).dy,
        lessThan(first.dy),
      );
      expect(tester.getTopLeft(find.text('\u06F1')).dx, lessThan(first.dx));

      final before = tester.widget<Text>(find.text(verse1)).style!.fontSize;
      await tester.tap(find.byTooltip('Taille du texte'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Agrandir l’arabe'));
      await tester.pump();
      expect(
        tester.widget<Text>(find.text(verse1)).style!.fontSize,
        before! + 2,
      );

      await tester.tap(find.byTooltip('Agrandir la traduction'));
      await tester.pump();
      await tester.tap(find.text('Translation'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.text('Quand l’événement arrivera.'))
            .style!
            .fontSize,
        19,
      );

      await tester.tap(find.text('Transliteration'));
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Izaa waqa'), findsOneWidget);

      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      final saved = await store.readState('readingFonts');
      expect(saved['arabic'], 30);
      expect(saved['translation'], 19);

      await tester.pumpWidget(
        MaterialApp(
          home: TextScreen(
            item: item,
            edition: LocalEdition('/tmp', const {'home': 'index.html'}),
            favorite: false,
            onFavorite: () async {},
            store: store,
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Arabic'));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.text(verse1)).style!.fontSize, 30);
    },
  );

  testWidgets('un long verset garde la même taille et passe à la ligne', (
    tester,
  ) async {
    const short = 'تَنْزِيلَ الْعَزِيزِ الرَّحِيمِ';
    const long =
        'إِنَّمَا تُنْذِرُ مَنِ اتَّبَعَ الذِّكْرَ وَخَشِيَ الرَّحْمَٰنَ بِالْغَيْبِ فَبَشِّرْهُ بِمَغْفِرَةٍ وَأَجْرٍ كَرِيمٍ';
    final item = DevotionalText(
      id: 'quran-long',
      kind: DevotionalKind.quran,
      title: 'Sourate',
      arabic: '$short ﴿٥﴾\n$long ﴿١١﴾',
      translation: 'Traduction.',
      transliteration: 'Translit',
      references: [],
      audioIds: [],
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
    await tester.tap(find.text('Arabic'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Taille du texte'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 10; i++) {
      await tester.tap(find.byTooltip('Agrandir l’arabe'));
      await tester.pump();
    }
    final shortText = tester.widget<Text>(find.text(short));
    final longText = tester.widget<Text>(find.text(long));
    expect(shortText.style!.fontSize, 48);
    expect(longText.style!.fontSize, shortText.style!.fontSize);
    expect(find.byType(FittedBox), findsNothing);
    expect(
      tester.getSize(find.text(long)).height,
      greaterThan(tester.getSize(find.text(short)).height * 1.4),
    );
  });
}
