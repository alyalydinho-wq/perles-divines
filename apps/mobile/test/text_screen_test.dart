import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perles_divines/core/store.dart';
import 'package:perles_divines/features/catalog/text_screen.dart';
import 'package:perles_divines/features/duas/dua.dart';
import 'package:perles_divines/features/reader/content_install.dart';
import 'package:perles_divines/ui/heritage.dart';
import 'package:perles_divines/ui/site.dart';

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
    expect(find.text('بِسْمِ اللّٰهِ'), findsOneWidget);
    expect(find.text('Au nom d’Allàh, le Tout Miséricordieux.'), findsNothing);

    await tester.tap(find.text('Translation'));
    await tester.pumpAndSettle();
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
    expect(arabic.style!.decoration, TextDecoration.underline);
    expect(arabic.style!.decorationColor, siteBlack);
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

  testWidgets('le cœur devient blanc quand le favori arrive après l’ouverture', (
    tester,
  ) async {
    const item = DevotionalText(
      id: 'ghofaylah',
      kind: DevotionalKind.namaz,
      title: 'Namaz-e-Ghofaylah',
      arabic: 'بِسْمِ اللّٰهِ',
      translation: '',
      transliteration: '',
      references: [],
      audioIds: [],
    );
    var favorite = false;
    Future<void> show() {
      return tester.pumpWidget(
        MaterialApp(
          home: TextScreen(
            item: item,
            edition: LocalEdition('/tmp', const {'home': 'index.html'}),
            favorite: favorite,
            onFavorite: () async {},
          ),
        ),
      );
    }

    await show();
    await tester.pump();
    expect(find.byTooltip('Ajouter aux favoris'), findsOneWidget);

    favorite = true;
    await show();
    await tester.pump();
    expect(find.byTooltip('Retirer des favoris'), findsOneWidget);
    expect(
      tester.widgetList<Icon>(find.byIcon(Icons.favorite)).map((icon) => icon.color),
      [const Color(0xffffffff)],
    );
  });

  testWidgets(
    'les onglets ne laissent pas de bande blanche au-dessus du lecteur',
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
          home: MediaQuery(
            data: const MediaQueryData(padding: EdgeInsets.only(bottom: 48)),
            child: TextScreen(
              item: item,
              edition: LocalEdition('/tmp', const {'home': 'index.html'}),
              favorite: false,
              onFavorite: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(SiteTextTabs)).height, 44);
    },
  );

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
        translation: 'Quand l’événement arrivera.\n\nInfos sur la sourate\n\nLieu de révélation:\n\nLa Mecque',
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
      expect(find.text('بِسْمِ اللّٰهِ'), findsOneWidget);
      expect(find.text('Quand l’événement arrivera.'), findsNothing);
      expect(_verse(verse1), findsOneWidget);
      expect(_verse(verse2), findsOneWidget);
      expect(find.textContaining('﴿'), findsNothing);
      expect(find.text('\u06F1'), findsOneWidget);
      expect(find.text('\u06F2'), findsOneWidget);

      final first = tester.getTopLeft(_verse(verse1));
      final second = tester.getTopLeft(_verse(verse2));
      expect(first.dy, lessThan(second.dy - 8));
      expect(tester.widget<Text>(_verse(verse1)).maxLines, isNull);
      expect(
        tester.widget<Text>(_verse(verse1)).style!.fontSize,
        tester.widget<Text>(_verse(verse2)).style!.fontSize,
      );
      expect(
        tester.getTopLeft(find.text('بِسْمِ اللّٰهِ')).dy,
        lessThan(first.dy),
      );
      final paragraph = _paragraph(tester, verse1);
      final boxes = paragraph.getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: verse1.length),
      );
      final origin = paragraph.localToGlobal(Offset.zero);
      final number = tester.getRect(find.text('\u06F1'));
      final nearestEnd = boxes
          .map((box) => (origin.dx + box.left - number.right).abs())
          .reduce((a, b) => a < b ? a : b);
      expect(nearestEnd, lessThan(12));
      expect(number.left, greaterThan(origin.dx + 24));
      expect(
        number.center.dy,
        inInclusiveRange(origin.dy, origin.dy + paragraph.size.height),
      );
      expect(
        tester.widget<Text>(_verse(verse1)).style!.decoration,
        TextDecoration.underline,
      );
      expect(
        tester.widget<Text>(find.text('بِسْمِ اللّٰهِ')).style!.decoration,
        TextDecoration.underline,
      );
      expect(find.text('Infos sur la sourate'), findsOneWidget);
      expect(find.text('La Mecque'), findsNothing);
      await tester.tap(find.text('Infos sur la sourate'));
      await tester.pumpAndSettle();
      expect(find.text('La Mecque'), findsOneWidget);

      final before = tester.widget<Text>(_verse(verse1)).style!.fontSize;
      await tester.tap(find.byTooltip('Taille du texte'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Agrandir l’arabe'));
      await tester.pump();
      expect(
        tester.widget<Text>(_verse(verse1)).style!.fontSize,
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
            key: const ValueKey('reopen'),
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
      expect(tester.widget<Text>(_verse(verse1)).style!.fontSize, 30);
    },
  );

  testWidgets('chaque ligne arabe d’une rubrique a un trait noir', (
    tester,
  ) async {
    const first = 'نَادِ عَلِيًّا مَظْهَرَ الْعَجَائِبِ';
    const second = 'تَجِدْهُ عَوْنًا لَكَ فِي النَّوَائِبِ';
    const item = DevotionalText(
      id: 'dua-naad',
      kind: DevotionalKind.dua,
      title: 'Naad-e-Ali',
      arabic: '$first\n$second',
      translation: 'Traduction.',
      transliteration: 'Naad',
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
    final text = tester.widget<Text>(find.text('$first\n$second'));
    expect(text.style!.decoration, TextDecoration.underline);
    expect(text.style!.decorationColor, siteBlack);
    expect(text.textAlign, TextAlign.center);

    await tester.tap(find.text('Translation'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('Traduction.')).style!.decoration,
      isNot(TextDecoration.underline),
    );
  });

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
    expect(_verse(short), findsOneWidget);
    await tester.tap(find.byTooltip('Taille du texte'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 10; i++) {
      await tester.tap(find.byTooltip('Agrandir l’arabe'));
      await tester.pump();
    }
    final shortText = tester.widget<Text>(_verse(short));
    final longText = tester.widget<Text>(_verse(long));
    expect(shortText.style!.fontSize, 48);
    expect(longText.style!.fontSize, shortText.style!.fontSize);
    expect(find.byType(FittedBox), findsNothing);
    expect(
      tester.getSize(_verse(long)).height,
      greaterThan(tester.getSize(_verse(short)).height * 1.4),
    );
  });

  testWidgets(
    'les infos d’une longue sourate s’affichent au tap',
    (tester) async {
      final verses = [
        for (var i = 1; i <= 40; i++) 'نَصُّ الْآيَةِ $i ﴿$i﴾',
      ].join('\n');
      final item = DevotionalText(
        id: 'quran-long-info',
        kind: DevotionalKind.quran,
        title: 'Sourate',
        arabic: verses,
        translation:
            'Traduction du verset.\n\nInfos sur la sourate\n\nLieu de révélation:\n\nLa Mecque\n\nNombre de versets: 40 versets',
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
      expect(find.text('La Mecque'), findsNothing);
      await tester.tap(find.text('Infos sur la sourate'));
      await tester.pumpAndSettle();
      expect(find.text('La Mecque'), findsOneWidget);
      expect(find.text('Nombre de versets:'), findsOneWidget);
      expect(find.text('40 versets'), findsOneWidget);
    },
  );

  testWidgets(
    'l’introduction d’un doua est encadrée en traduction et en translittération',
    (tester) async {
      const intro =
          'En cas de difficulté sérieuse, cet appel à Hazrat Ali (as) est recommandé.';
      const item = DevotionalText(
        id: 'dua-naad-info',
        kind: DevotionalKind.dua,
        title: 'Naad-e-Ali',
        arabic: 'نَادِ عَلِيًّا',
        translation: 'Faites appel à Ali.',
        transliteration: 'Naad-e-ali',
        introduction: intro,
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
      _expectInfoCard(tester, intro);

      await tester.tap(find.text('Translation'));
      await tester.pumpAndSettle();
      _expectInfoCard(tester, intro);
      expect(find.text('Faites appel à Ali.'), findsOneWidget);

      await tester.tap(find.text('Transliteration'));
      await tester.pumpAndSettle();
      _expectInfoCard(tester, intro);
      expect(find.text('Naad-e-ali'), findsOneWidget);
    },
  );
}

RenderParagraph _paragraph(WidgetTester tester, String value) {
  final element = tester.element(_verse(value));
  RenderParagraph? found;
  void walk(Element node) {
    final render = node.renderObject;
    if (render is RenderParagraph &&
        render.text.toPlainText(includePlaceholders: false) == value) {
      found = render;
    }
    node.visitChildElements(walk);
  }

  walk(element);
  return found!;
}

void _expectInfoCard(WidgetTester tester, String value) {
  final text = tester.widget<Text>(find.text(value));
  expect(text.style!.fontStyle, isNot(FontStyle.italic));
  final box = tester.widget<DecoratedBox>(
    find
        .ancestor(of: find.text(value), matching: find.byType(DecoratedBox))
        .first,
  );
  final decoration = box.decoration as BoxDecoration;
  expect(decoration.color, const Color(0xFFF7F8F4));
  expect(decoration.borderRadius, BorderRadius.circular(12));
  expect(
    decoration.border,
    Border.all(color: const Color(0xFFD9E3C8)),
  );
}

Finder _verse(String value) => find.byWidgetPredicate((widget) {
  if (widget is! Text) return false;
  final plain =
      widget.data ??
      widget.textSpan?.toPlainText(includePlaceholders: false) ??
      '';
  return plain == value;
});
