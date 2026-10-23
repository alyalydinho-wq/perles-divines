import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perles_divines/features/catalog/jawshan.dart';
import 'package:perles_divines/features/catalog/text_screen.dart';
import 'package:perles_divines/features/duas/dua.dart';
import 'package:perles_divines/features/reader/content_install.dart';

void main() {
  test('le hadith se sépare de la liste Doua', () {
    const introduction = 'Hadith de test.\n\nDoua - 2\n\nDoua - 100';
    expect(jawshanHadith(introduction), 'Hadith de test.');
  });

  test('la traduction se découpe de 1 à 100 sans rien perdre', () {
    final translation =
        'Préambule. ${[for (var i = 1; i <= 100; i++) '$i - partie $i.'].join(' ')}';
    final parsed = parseJawshanTranslation(translation);
    expect(parsed, isNotNull);
    expect(parsed!.preamble, 'Préambule.');
    expect(parsed.parts, hasLength(100));
    expect(parsed.parts.first, '1 - partie 1.');
    expect(parsed.parts.last, '100 - partie 100.');
    expect(parseJawshanTranslation('1 - seulement.'), isNull);
  });

  testWidgets('les trois onglets séparent les 100 parties', (tester) async {
    final titles = await loadJawshanTitles();
    expect(titles, hasLength(100));
    await tester.pumpWidget(_app(titles));
    await tester.pumpAndSettle();

    expect(find.text('Hadith de test.'), findsOneWidget);
    expect(find.byKey(const Key('jawshan-toc-1')), findsOneWidget);
    expect(find.text('Pour surmonter les difficultés'), findsOneWidget);
    expect(find.text('سطر 1'), findsOneWidget);
    expect(_fontSize(tester, 'Pour surmonter les difficultés'), 18);
    expect(_fontSize(tester, 'سطر 1'), 28);
    await tester.tap(find.byKey(const Key('larger-text')));
    await tester.pump();
    expect(_fontSize(tester, 'Pour surmonter les difficultés'), 22);
    expect(_fontSize(tester, 'سطر 1'), 34);
    await tester.tap(find.byKey(const Key('smaller-text')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('smaller-text')));
    await tester.pump();
    expect(_fontSize(tester, 'Pour surmonter les difficultés'), 16);
    expect(_fontSize(tester, 'سطر 1'), 24);

    await tester.tap(find.text('Translation'));
    await tester.pumpAndSettle();
    expect(find.text('Préambule de test.'), findsOneWidget);
    await _jump(tester, 360);
    expect(find.text('1 - partie 1.'), findsOneWidget);
    await _showPart(tester, 100);
    expect(find.text('100 - partie 100.'), findsOneWidget);
    expect(find.text('Pour guérir la douleur de la cuisse'), findsOneWidget);

    await tester.tap(find.text('Transliteration'));
    await tester.pumpAndSettle();
    await _showPart(tester, 1);
    expect(find.text('ligne 1'), findsOneWidget);
    await _showPart(tester, 1);
    final start = _offset(tester);
    await _showPart(tester, 50);
    final middle = _offset(tester);
    expect(middle, greaterThan(start + 40));
    expect(tester.getTopLeft(find.text('Pour améliorer la vue')).dy, lessThan(180));
    await _showPart(tester, 100);
    expect(_offset(tester), greaterThan(middle));
    expect(
      tester.getTopLeft(find.text('Pour guérir la douleur de la cuisse')).dy,
      lessThan(180),
    );
    expect(find.text('ligne 100'), findsOneWidget);

    await tester.tap(find.text('Arabic'));
    await tester.pump();
    await _showPart(tester, 1);
    expect(find.text('سطر 1'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Pour surmonter les difficultés')).dy, lessThan(180));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('un autre doua ne reçoit pas le sommaire Jawshan', (
    tester,
  ) async {
    const item = DevotionalText(
      id: 'autre',
      kind: DevotionalKind.dua,
      title: 'Autre',
      arabic: 'سطر',
      translation: 'Texte.',
      transliteration: 'ligne',
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
    expect(find.text('Doua - 1'), findsNothing);
    expect(find.byKey(const Key('jawshan-toc-1')), findsNothing);
  });
}

double _offset(WidgetTester tester) => tester
    .widget<SingleChildScrollView>(find.byKey(const Key('jawshan-reading')))
    .controller!
    .offset;

Future<void> _jump(WidgetTester tester, double offset) async {
  tester
      .widget<SingleChildScrollView>(find.byKey(const Key('jawshan-reading')))
      .controller!
      .jumpTo(offset);
  await tester.pump();
}

Future<void> _showPart(WidgetTester tester, int number) async {
  await _jump(tester, 0);
  tester
      .widget<InkWell>(
        find.byKey(Key('jawshan-toc-$number'), skipOffstage: false),
      )
      .onTap!();
  await tester.pump();
  await tester.pump();
}

double? _fontSize(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.fontSize;

Widget _app(List<JawshanTitle> titles) {
  final item = DevotionalText(
    id: jawshanKabirId,
    kind: DevotionalKind.dua,
    title: 'Doua-e-Jawshan-e-Kabir',
    arabic: [for (var i = 1; i <= 100; i++) 'سطر $i'].join('\n\n'),
    translation:
        'Préambule de test. ${[for (var i = 1; i <= 100; i++) '$i - partie $i.'].join(' ')}',
    transliteration: [for (var i = 1; i <= 100; i++) 'ligne $i'].join('\n\n'),
    introduction: 'Hadith de test.\n\nDoua - 2\n\nDoua - 100',
    references: [],
    audioIds: [],
  );
  return MaterialApp(
    home: TextScreen(
      item: item,
      edition: LocalEdition('/tmp', const {'home': 'index.html'}),
      favorite: false,
      onFavorite: () async {},
      jawshanTitles: titles,
    ),
  );
}
