import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:perles_divines/core/store.dart';
import 'package:perles_divines/features/catalog/text_screen.dart';
import 'package:perles_divines/features/duas/dua.dart';
import 'package:perles_divines/features/reader/content_install.dart';
import 'package:perles_divines/ui/heritage.dart';
import 'package:perles_divines/ui/site.dart';

void main() {
  test('une ligne coupée est soulignée sur toute la largeur', () {
    const style = TextStyle(fontSize: 28, height: 2.06);
    final lines = layoutQuranLines(
      verses: [
        (text: List.filled(24, 'كلمة').join(' '), number: 72),
        (text: 'قصير', number: 73),
      ],
      style: style,
      scaler: TextScaler.noScaling,
      maxWidth: 180,
    );
    expect(lines.first.fill, isTrue);
    expect(lines.last.words, ['قصير\u2060']);
    expect(lines.last.fill, isFalse);
    expect(lines.last.number, 73);
  });

  test('le trait arabe couvre les glyphes au-delà de la métrique', () {
    final edges = quranRuleEdges(
      metricLeft: 180,
      metricWidth: 90,
      lineTop: 0,
      lineBottom: 40,
      boxes: [
        TextBox.fromLTRBD(180, 2, 270, 36, TextDirection.rtl),
        TextBox.fromLTRBD(12, 4, 70, 38, TextDirection.rtl),
        TextBox.fromLTRBD(0, 80, 40, 100, TextDirection.rtl),
      ],
    );
    expect(edges.left, 12);
    expect(edges.right, 270);
  });

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
    expect(find.byIcon(Icons.settings), findsNothing);

    await tester.tap(find.byTooltip('Lire'));
    await tester.pumpAndSettle();
    expect(
      find.text('Aucun audio n’est encore associé à ce texte.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'le cœur devient blanc quand le favori arrive après l’ouverture',
    (tester) async {
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
        tester
            .widgetList<Icon>(find.byIcon(Icons.favorite))
            .map((icon) => icon.color),
        [const Color(0xffffffff)],
      );
    },
  );

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
    'une sourate montre le numéro de chaque verset et mémorise la taille',
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
      expect(find.text('Quand l’événement arrivera.'), findsNothing);
      final basmala = tester.widget<Text>(find.byKey(const Key('quran-basmala')));
      expect(_quranPlain(basmala), 'بِسْمِ اللّٰهِ');
      expect(basmala.textAlign, TextAlign.center);
      expect(basmala.textDirection, TextDirection.rtl);
      final flow = _flowText(tester);
      final plain = _flowPlain(tester);
      expect(plain.startsWith(verse1), isTrue);
      expect(plain.contains('بِسْمِ'), isFalse);
      expect(plain.contains(verse1), isTrue);
      expect(plain.contains(verse2), isTrue);
      expect(plain.contains('\u2060'), isTrue);
      expect(plain.contains('﴿'), isFalse);
      expect(flow.textAlign, TextAlign.right);
      expect(flow.textDirection, TextDirection.rtl);
      expect(flow.textWidthBasis, TextWidthBasis.parent);
      expect(flow.maxLines, isNull);
      expect(flow.style!.fontFamily, 'Indopak');
      expect(flow.style!.height, 2.06);
      expect(flow.style!.decoration, isNot(TextDecoration.underline));
      expect(find.text('\u06F1'), findsOneWidget);
      expect(find.text('\u06F2'), findsOneWidget);
      final word = tester.getRect(find.byKey(const ValueKey('ayah-word-1')));
      final number = tester.getRect(find.text('\u06F1'));
      expect((word.center.dy - number.center.dy).abs(), lessThan(flow.style!.fontSize!));
      expect(number.center.dx, lessThan(word.center.dx));
      expect(find.text('Infos sur la sourate'), findsOneWidget);
      expect(find.text('La Mecque'), findsNothing);
      await tester.tap(find.text('Infos sur la sourate'));
      await tester.pumpAndSettle();
      expect(find.text('La Mecque'), findsOneWidget);

      final before = _flowText(tester).style!.fontSize;
      expect(before, 28);
      await tester.tap(find.text('Plus grand'));
      await tester.pump();
      expect(
        _flowText(tester).style!.fontSize,
        34,
      );

      await tester.tap(find.text('Translation'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.text('Quand l’événement arrivera.'))
            .style!
            .fontSize,
        22,
      );

      await tester.tap(find.text('Transliteration'));
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(_verse('Izaa waqa'), findsOneWidget);

      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      final saved = await store.readState('readingFonts');
      expect(saved['arabic'], 34);
      expect(saved['translation'], 22);
      expect(saved['transliteration'], 22);
      expect(saved['gujarati'], 22);

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
      expect(
        _flowText(tester).style!.fontSize,
        34,
      );
    },
  );

  testWidgets('un numéro à trois chiffres reste entier au début du verset', (
    tester,
  ) async {
    const item = DevotionalText(
      id: 'kursi',
      kind: DevotionalKind.quran,
      title: 'Ayat al-Kursî',
      arabic: 'بِسۡمِ اللهِ\n\nاللّٰهُ ﴿٢٥٥﴾\nلَاۤ ﴿٢٥٦﴾\nاَللّٰهُ ﴿٢٥٧﴾',
      translation: 'Par la grâce.\n\n255. Allàh point de divinité.\n\n256. Nulle contrainte.\n\n257. Allàh est le défenseur.',
      transliteration:
          'Bismillaah\n\nAllahu laaa\nLaaa ikraaha\nAllaahu waliyy',
      references: [],
      audioIds: [],
    );
    tester.view.physicalSize = const Size(390, 900);
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
    expect(find.text('\u06F2\u06F5\u06F5'), findsOneWidget);
    expect(find.text('\u06F2\u06F5\u06F6'), findsOneWidget);
    expect(find.text('\u06F2\u06F5\u06F7'), findsOneWidget);
    final arabicNumber = tester.getSize(find.text('\u06F2\u06F5\u06F5'));
    expect(arabicNumber.height, lessThan(arabicNumber.width));

    await tester.tap(find.text('Transliteration'));
    await tester.pumpAndSettle();
    final number = find.text('255');
    expect(number, findsOneWidget);
    final numberSize = tester.getSize(number);
    expect(numberSize.height, lessThan(numberSize.width));
    _expectBadgeBefore(tester, '255', 'Allahu laaa');

    await tester.tap(find.text('Translation'));
    await tester.pumpAndSettle();
    expect(find.text('256'), findsOneWidget);
    expect(find.text('257'), findsOneWidget);
    expect(find.textContaining('Nulle contrainte'), findsOneWidget);
    expect(find.textContaining('255.'), findsNothing);
    _expectBadgeBefore(tester, '257', 'le défenseur');
  });

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
    expect(_flowPlain(tester), contains(short));
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Plus grand'));
      await tester.pump();
    }
    final flow = _flowText(tester);
    final plain = _flowPlain(tester);
    expect(flow.style!.fontSize, 46);
    expect(flow.style!.fontFamily, 'Indopak');
    expect(plain, contains(short));
    expect(plain, contains(long));
    expect(
      find.ancestor(of: find.byKey(const Key('quran-flow')), matching: find.byType(FittedBox)),
      findsNothing,
    );
    expect(
      tester.getSize(find.byKey(const Key('quran-flow'))).height,
      greaterThan(46 * 2.06 * 1.4),
    );
  });

  testWidgets('un verset court reste groupé au lieu de s’étirer', (
    tester,
  ) async {
    const before = 'وَحُورٌ';
    const last = 'عِينٌ';
    const item = DevotionalText(
      id: 'quran-gap',
      kind: DevotionalKind.quran,
      title: 'Sourate',
      arabic: 'بِسْمِ اللّٰهِ\n\n$before $last ﴿٢٢﴾',
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
    final word = tester.getRect(find.byKey(const ValueKey('ayah-word-22')));
    final badge = tester.getRect(find.text('\u06F2\u06F2'));
    expect(word.left - badge.right, inInclusiveRange(0, 16));
    final rule = tester.getSize(find.byKey(const ValueKey('quran-rule-0')));
    expect(rule.width, lessThan(tester.getSize(find.byKey(const Key('quran-flow'))).width - 40));
  });

  testWidgets('les infos d’une longue sourate s’affichent au tap', (
    tester,
  ) async {
    final verses = [for (var i = 1; i <= 40; i++) 'نَصُّ الْآيَةِ $i ﴿$i﴾']
        .join('\n');
    final item = DevotionalText(
      id: 'quran-long-info',
      kind: DevotionalKind.quran,
      title: 'Sourate',
      arabic: verses,
      translation: 'Traduction du verset.\n\nInfos sur la sourate\n\nLieu de révélation:\n\nLa Mecque\n\nNombre de versets: 40 versets',
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

    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Infos sur la sourate').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Translation'));
    await tester.pumpAndSettle();
    expect(find.text('La Mecque'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Infos sur la sourate')).dy,
      lessThan(tester.getTopLeft(find.text('Traduction du verset.')).dy),
    );
    await tester.tap(find.text('Infos sur la sourate'));
    await tester.pumpAndSettle();
    expect(find.text('La Mecque'), findsOneWidget);
    expect(
      tester.getBottomLeft(find.text('40 versets')).dy,
      lessThan(tester.getTopLeft(find.text('Traduction du verset.')).dy),
    );
    _expectInfoCard(tester, 'La Mecque');
  });

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

  testWidgets('l’onglet Gujarati n’apparaît que s’il y a un texte', (
    tester,
  ) async {
    const item = DevotionalText(
      id: 'ashura',
      kind: DevotionalKind.ziyarat,
      title: 'Zyaarat-e-Âchourâ',
      arabic: 'اَلسَّلاَمُ',
      translation: 'Que la paix soit sur toi.',
      transliteration: 'assalamu',
      gujarati: 'સલામ આપ પર.\n\nખુદા લાનત કરે.',
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

    expect(find.text('Gujarati'), findsOneWidget);
    expect(find.text('સલામ આપ પર.'), findsNothing);

    await tester.tap(find.text('Gujarati'));
    await tester.pumpAndSettle();
    expect(find.text('સલામ આપ પર.'), findsOneWidget);
    expect(find.text('ખુદા લાનત કરે.'), findsOneWidget);
    expect(find.text('Que la paix soit sur toi.'), findsNothing);

    final gujarati = tester.widget<Text>(find.text('સલામ આપ પર.'));
    expect(gujarati.style!.fontFamily, 'NotoSansGujarati');
    expect(gujarati.style!.height, greaterThan(1.6));

    expect(find.text('Plus grand'), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsNothing);
  });

  testWidgets(
    'Nudba en gujarati montre tout le texte, défile et suit la taille',
    (tester) async {
      final catalog = jsonDecode(
        File('assets/content/catalog.json').readAsStringSync(),
      ) as List<dynamic>;
      final item = DevotionalText.fromJson(
        catalog.cast<Map<String, dynamic>>().firstWhere(
          (entry) => entry['title'] == 'Doua-e-Nudba',
        ),
      );
      final paragraphs = item.gujarati
          .split(RegExp(r'\n{2,}'))
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList();
      expect(paragraphs.length, 23);

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

      await tester.tap(find.text('Gujarati'));
      await tester.pumpAndSettle();

      expect(find.text(paragraphs.first), findsOneWidget);
      final before = tester
          .widget<Text>(find.text(paragraphs.first))
          .style!
          .fontSize;

      await tester.scrollUntilVisible(find.text(paragraphs.last), 400);
      expect(find.text(paragraphs.last), findsOneWidget);

      await tester.tap(find.text('Plus grand'));
      await tester.pumpAndSettle();
      final grown = tester
          .widget<Text>(find.text(paragraphs.last))
          .style!
          .fontSize;
      expect(grown, greaterThan(before!));
    },
  );

  testWidgets(
    'la barre de taille est au-dessus des onglets, sans roue dentée',
    (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await _pumpReading(tester, _sample());
        expect(find.byIcon(Icons.settings), findsNothing);
        expect(find.byTooltip('Taille du texte'), findsNothing);
        expect(find.byTooltip('Agrandir l’arabe'), findsNothing);
        expect(find.text('A−'), findsOneWidget);
        expect(find.text('Plus petit'), findsOneWidget);
        expect(find.text('A+'), findsOneWidget);
        expect(find.text('Plus grand'), findsOneWidget);
        expect(find.text('Normal'), findsOneWidget);
        expect(find.bySemanticsLabel('Taille du texte'), findsOneWidget);
        expect(find.bySemanticsLabel('Plus petit'), findsOneWidget);
        expect(find.bySemanticsLabel('Plus grand'), findsOneWidget);
        expect(find.bySemanticsLabel('Sommaire'), findsOneWidget);
        expect(find.bySemanticsLabel('Page précédente'), findsNothing);
        expect(find.byIcon(Icons.chevron_left), findsNothing);
        expect(find.bySemanticsLabel('Haut de la page'), findsOneWidget);

        final bar = tester.getRect(find.byKey(const Key('text-size-bar')));
        final tabs = tester.getRect(find.byType(SiteTextTabs));
        final reading = tester.getRect(find.byType(Scrollable));
        final header = tester.getRect(find.byType(SiteReaderHeader));
        expect(bar.height, tabs.height);
        expect(bar.height, siteReaderBarHeight);
        expect(reading.top, closeTo(header.bottom, 0.5));
        expect(reading.bottom, lessThanOrEqualTo(bar.top + 0.5));
        expect(bar.bottom, lessThanOrEqualTo(tabs.top + 0.5));

        final smaller = tester.widget<Text>(find.text('Plus petit'));
        final level = tester.widget<Text>(find.text('Normal'));
        expect(smaller.style!.fontSize, 14);
        expect(smaller.style!.color, Colors.white);
        expect(smaller.style!.fontWeight, FontWeight.w700);
        expect(level.style!.fontSize, 13);
        expect(level.style!.fontWeight, FontWeight.w700);
        expect(
          tester.widget<Material>(_buttonMaterial('smaller-text')).color,
          siteGreenSolid,
        );
        final smallerBox = tester.getRect(
          find.byKey(const Key('smaller-text')),
        );
        final largerBox = tester.getRect(find.byKey(const Key('larger-text')));
        final levelBox = tester.getRect(find.text('Normal'));
        expect(smallerBox.height, closeTo(bar.height, 0.5));
        expect(smallerBox.center.dy, closeTo(largerBox.center.dy, 0.5));
        expect(levelBox.center.dy, closeTo(smallerBox.center.dy, 0.5));
        expect(smallerBox.center.dx, lessThan(levelBox.center.dx));
        expect(levelBox.center.dx, lessThan(largerBox.center.dx));

        final back = tester.getCenter(find.byTooltip('Retour'));
        final home = tester.getCenter(find.byTooltip('Sommaire'));
        final up = tester.getCenter(find.byTooltip('Haut de la page'));
        final play = tester.getCenter(find.byTooltip('Lire'));
        final share = tester.getCenter(find.byTooltip('Partager'));
        final title = tester.getRect(
          find.descendant(
            of: find.byType(SiteReaderHeader),
            matching: find.text('Texte'),
          ),
        );
        expect(header.contains(home), isTrue);
        expect(header.contains(up), isTrue);
        expect(back.dx, lessThan(home.dx));
        expect(home.dx, lessThan(title.left));
        expect(title.right, lessThan(up.dx));
        expect(up.dx, lessThan(play.dx));
        expect(play.dx, lessThan(share.dx));
        expect(home.dy, closeTo(back.dy, 1));
        expect(up.dy, closeTo(back.dy, 1));
        expect(play.dy, closeTo(back.dy, 1));
      } finally {
        handle.dispose();
      }
    },
  );

  testWidgets('Plus grand et Plus petit changent les quatre tailles ensemble', (
    tester,
  ) async {
    const arabic = 'بِسْمِ اللّٰهِ';
    const translation = 'Au nom d’Allàh.';
    const transliteration = 'Bismillah';
    const gujarati = 'સલામ';
    final store = AppStore(NativeDatabase.memory());
    addTearDown(store.close);
    await _pumpReading(
      tester,
      _sample(
        arabic: arabic,
        translation: translation,
        transliteration: transliteration,
        gujarati: gujarati,
      ),
      store: store,
    );
    expect(tester.widget<Text>(find.text(arabic)).style!.fontSize, 28);

    await tester.tap(find.text('Plus grand'));
    await tester.pump();
    expect(find.text('Grand'), findsOneWidget);
    expect(tester.widget<Text>(find.text(arabic)).style!.fontSize, 34);

    await tester.tap(find.text('Translation'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text(translation)).style!.fontSize, 22);

    await tester.tap(find.text('Transliteration'));
    await tester.pumpAndSettle();
    expect(_fontSize(tester, transliteration), 22);

    await tester.tap(find.text('Gujarati'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text(gujarati)).style!.fontSize, 22);

    await tester.tap(find.text('Plus petit'));
    await tester.pump();
    expect(find.text('Normal'), findsOneWidget);
    expect(tester.widget<Text>(find.text(gujarati)).style!.fontSize, 18);

    await tester.tap(find.text('Arabic'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plus petit'));
    await tester.pump();
    expect(find.text('Petit'), findsNothing);
    expect(find.text('Taille minimale'), findsOneWidget);
    expect(tester.widget<Text>(find.text(arabic)).style!.fontSize, 24);
    expect(
      tester.widget<InkWell>(find.byKey(const Key('smaller-text'))).onTap,
      isNull,
    );
    expect(
      tester.widget<Material>(_buttonMaterial('smaller-text')).color,
      const Color(0xFFD0D0D0),
    );
    expect(
      tester.widget<InkWell>(find.byKey(const Key('larger-text'))).onTap,
      isNotNull,
    );

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    final saved = await store.readState('readingFonts');
    expect(saved['arabic'], 24);
    expect(saved['translation'], 16);
    expect(saved['transliteration'], 16);
    expect(saved['gujarati'], 16);
  });

  testWidgets('aux extrémités le bouton est grisé et le libellé le dit', (
    tester,
  ) async {
    await _pumpReading(tester, _sample());
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Plus grand'));
      await tester.pump();
    }
    expect(find.text('Énorme'), findsNothing);
    expect(find.text('Taille maximale'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Plus grand')).style!.color,
      isNot(Colors.white),
    );
    expect(
      tester.widget<InkWell>(find.byKey(const Key('larger-text'))).onTap,
      isNull,
    );
    expect(
      tester.widget<Material>(_buttonMaterial('larger-text')).color,
      const Color(0xFFD0D0D0),
    );
    expect(
      tester.widget<InkWell>(find.byKey(const Key('smaller-text'))).onTap,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('larger-text')));
    await tester.pump();
    expect(
      tester.widget<Text>(find.text('بِسْمِ اللّٰهِ')).style!.fontSize,
      46,
    );

    await tester.tap(find.text('Plus petit'));
    await tester.pump();
    expect(find.text('Très grand'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('بِسْمِ اللّٰهِ')).style!.fontSize,
      40,
    );
  });

  testWidgets('la taille choisie est retrouvée après reconstruction', (
    tester,
  ) async {
    const arabic = 'بِسْمِ اللّٰهِ';
    final store = AppStore(NativeDatabase.memory());
    addTearDown(store.close);
    final item = _sample(arabic: arabic);
    await _pumpReading(tester, item, store: store);
    await tester.tap(find.text('Plus grand'));
    await tester.pump();
    expect(tester.widget<Text>(find.text(arabic)).style!.fontSize, 34);

    await tester.pumpWidget(const SizedBox.shrink());
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
    expect(find.text('Grand'), findsOneWidget);
    expect(tester.widget<Text>(find.text(arabic)).style!.fontSize, 34);
    final saved = await store.readState('readingFonts');
    expect(saved['arabic'], 34);
    expect(saved['translation'], 22);
    expect(saved['transliteration'], 22);
    expect(saved['gujarati'], 22);
  });

  testWidgets('un appui pendant le chargement n’est pas écrasé', (
    tester,
  ) async {
    const arabic = 'بِسْمِ اللّٰهِ';
    final store = _GateStore(NativeDatabase.memory());
    addTearDown(store.close);
    await tester.pumpWidget(
      MaterialApp(
        home: TextScreen(
          item: _sample(arabic: arabic),
          edition: LocalEdition('/tmp', const {'home': 'index.html'}),
          favorite: false,
          onFavorite: () async {},
          store: store,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Plus grand'));
    await tester.pump();
    expect(tester.widget<Text>(find.text(arabic)).style!.fontSize, 34);
    store.release({
      'arabic': 24,
      'translation': 16,
      'transliteration': 16,
      'gujarati': 16,
    });
    await tester.pump();
    expect(tester.widget<Text>(find.text(arabic)).style!.fontSize, 34);
    expect(find.text('Grand'), findsOneWidget);
  });

  testWidgets('d’anciens réglages donnent le niveau le plus proche', (
    tester,
  ) async {
    const arabic = 'بِسْمِ اللّٰهِ';
    const translation = 'Au nom d’Allàh.';
    final store = AppStore(NativeDatabase.memory());
    addTearDown(store.close);
    await tester.runAsync(
      () => store.writeState('readingFonts', {
        'arabic': 28,
        'translation': 18,
        'transliteration': 18,
        'gujarati': 18,
      }),
    );
    final item = _sample(arabic: arabic, translation: translation);
    await _pumpReading(tester, item, store: store, settleStore: true);
    expect(find.text('Normal'), findsOneWidget);
    expect(tester.widget<Text>(find.text(arabic)).style!.fontSize, 28);
    var saved = await store.readState('readingFonts');
    expect(saved['arabic'], 28);
    expect(saved['translation'], 18);

    await tester.runAsync(
      () => store.writeState('readingFonts', {
        'arabic': 20,
        'translation': 14,
        'transliteration': 14,
        'gujarati': 14,
      }),
    );
    await _pumpReading(
      tester,
      item,
      store: store,
      settleStore: true,
      key: const ValueKey('old-small'),
    );
    expect(find.text('Taille minimale'), findsOneWidget);
    expect(tester.widget<Text>(find.text(arabic)).style!.fontSize, 20);
    await tester.tap(find.text('Translation'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text(translation)).style!.fontSize, 14);
    saved = await store.readState('readingFonts');
    expect(saved['arabic'], 20);
    expect(saved['translation'], 14);
    expect(saved['transliteration'], 14);
    expect(saved['gujarati'], 14);
  });

  testWidgets('sommaire, retour et haut de page fonctionnent', (tester) async {
    final item = _sample(
      arabic: List.filled(
        24,
        'نَصٌّ لِلْقِرَاءَةِ يَمْلَأُ الصَّفْحَةَ',
      ).join('\n\n'),
    );
    final router = GoRouter(
      initialLocation: '/texte',
      routes: [
        GoRoute(
          path: '/sommaire',
          builder: (context, state) =>
              const Scaffold(body: Text('Écran sommaire')),
        ),
        GoRoute(
          path: '/texte',
          builder: (context, state) => TextScreen(
            item: item,
            edition: LocalEdition('/tmp', const {'home': 'index.html'}),
            favorite: false,
            onFavorite: () async {},
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sommaire'));
    await tester.pumpAndSettle();
    expect(find.text('Écran sommaire'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => TextScreen(
                      item: _sample(),
                      edition: LocalEdition('/tmp', const {
                        'home': 'index.html',
                      }),
                      favorite: false,
                      onFavorite: () async {},
                    ),
                  ),
                );
              },
              child: const Text('Ouvrir la lecture'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir la lecture'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    expect(find.text('Ouvrir la lecture'), findsOneWidget);
    expect(find.byType(TextScreen), findsNothing);

    tester.view.physicalSize = const Size(390, 640);
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
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    expect(position.maxScrollExtent, greaterThan(80));
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(80));
    await tester.tap(find.byTooltip('Haut de la page'));
    await tester.pumpAndSettle();
    expect(position.pixels, 0);
  });

  testWidgets('la barre ne déborde pas sur 320 px ni à 200 %', (tester) async {
    final item = _sample(gujarati: 'સલામ', title: 'Naad-e-Ali');
    await _pumpReading(tester, item, size: const Size(320, 700), textScale: 1);
    expect(tester.takeException(), isNull);
    expect(find.text('Gujarati'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Plus grand'));
      await tester.pump();
    }
    expect(find.text('Taille maximale'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _pumpReading(
      tester,
      item,
      size: const Size(320, 700),
      textScale: 2,
      key: const ValueKey('large-text'),
    );
    expect(find.text('Plus petit'), findsOneWidget);
    expect(find.text('Plus grand'), findsOneWidget);
    expect(find.text('Normal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'la proportion de défilement reste stable quand la taille change',
    (tester) async {
      final item = _sample(
        arabic: List.filled(
          30,
          'نَصٌّ لِلْقِرَاءَةِ يَمْلَأُ الصَّفْحَةَ',
        ).join('\n\n'),
      );
      await _pumpReading(tester, item, size: const Size(390, 640));
      final beforePosition = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      expect(beforePosition.maxScrollExtent, greaterThan(200));
      beforePosition.jumpTo(beforePosition.maxScrollExtent * 0.45);
      await tester.pumpAndSettle();
      final before = beforePosition.pixels / beforePosition.maxScrollExtent;

      await tester.tap(find.text('Plus grand'));
      await tester.pumpAndSettle();
      final afterPosition = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      final after = afterPosition.pixels / afterPosition.maxScrollExtent;
      expect((after - before).abs(), lessThan(0.03));

      await tester.tap(find.text('Plus petit'));
      await tester.pumpAndSettle();
      final restored = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      expect(
        (restored.pixels / restored.maxScrollExtent - before).abs(),
        lessThan(0.03),
      );
    },
  );
}

Text _flowText(WidgetTester tester) {
  return tester.widget<Text>(
    find
        .descendant(
          of: find.byKey(const Key('quran-flow')),
          matching: find.byType(Text),
        )
        .first,
  );
}

String _flowPlain(WidgetTester tester) {
  final texts = tester.widgetList<Text>(
    find.descendant(
      of: find.byKey(const Key('quran-flow')),
      matching: find.byType(Text),
    ),
  );
  return texts
      .map((text) => text.data ?? '')
      .where((value) => value.isNotEmpty)
      .join(' ');
}

String _quranPlain(Text flow) {
  if (flow.textSpan == null) return flow.data ?? '';
  final buffer = StringBuffer();
  void walk(InlineSpan span) {
    if (span is TextSpan) {
      buffer.write(span.text ?? '');
      span.children?.forEach(walk);
    } else if (span is WidgetSpan && span.child is Row) {
      for (final child in (span.child as Row).children) {
        if (child is Text) buffer.write(child.data ?? '');
      }
    }
  }

  walk(flow.textSpan!);
  return buffer.toString();
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
  expect(decoration.border, Border.all(color: const Color(0xFFD9E3C8)));
}

DevotionalText _sample({
  String arabic = 'بِسْمِ اللّٰهِ',
  String translation = 'Au nom d’Allàh.',
  String transliteration = 'Bismillah',
  String gujarati = '',
  String title = 'Texte',
}) {
  return DevotionalText(
    id: 'texte',
    kind: DevotionalKind.dua,
    title: title,
    arabic: arabic,
    translation: translation,
    transliteration: transliteration,
    gujarati: gujarati,
    references: const [],
    audioIds: const [],
  );
}

Future<void> _pumpReading(
  WidgetTester tester,
  DevotionalText item, {
  AppStore? store,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool settleStore = false,
  Key? key,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        );
      },
      home: TextScreen(
        key: key,
        item: item,
        edition: LocalEdition('/tmp', const {'home': 'index.html'}),
        favorite: false,
        onFavorite: () async {},
        store: store,
      ),
    ),
  );
  if (settleStore) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
  }
  await tester.pumpAndSettle();
}

Finder _buttonMaterial(String key) => find
    .ancestor(of: find.byKey(Key(key)), matching: find.byType(Material))
    .first;

double? _fontSize(WidgetTester tester, String value) {
  final text = tester.widget<Text>(find.text(value));
  return text.style?.fontSize ?? text.textSpan?.style?.fontSize;
}

class _GateStore extends AppStore {
  _GateStore(super.executor);

  final _gate = Completer<Object?>();

  void release(Object? value) {
    if (!_gate.isCompleted) _gate.complete(value);
  }

  @override
  Future<dynamic> readState(String key) => _gate.future;
}

void _expectBadgeBefore(WidgetTester tester, String number, String snippet) {
  final paragraph = tester
      .renderObjectList<RenderParagraph>(find.byType(RichText))
      .singleWhere((item) => item.text.toPlainText().contains(snippet));
  final plain = paragraph.text.toPlainText();
  final at = plain.indexOf(snippet);
  expect(at, greaterThanOrEqualTo(0));
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: at, extentOffset: at + snippet.length),
  );
  expect(boxes, isNotEmpty);
  final words = paragraph.localToGlobal(Offset(boxes.first.left, boxes.first.top));
  final badge = tester.getRect(find.text(number));
  expect(badge.right, lessThan(words.dx));
  expect((badge.center.dy - words.dy).abs(), lessThan(badge.height));
}

Finder _verse(String value) => find.byWidgetPredicate((widget) {
  if (widget is! Text) return false;
  final plain =
      widget.data ??
      widget.textSpan?.toPlainText(includePlaceholders: false) ??
      '';
  return plain == value;
});
