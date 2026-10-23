import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perles_divines/features/catalog/justified_quran_text.dart';
import 'package:perles_divines/features/catalog/text_screen.dart';
import 'package:perles_divines/features/duas/dua.dart';
import 'package:perles_divines/features/reader/content_install.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String fatiha;
  late String ikhlas;
  late String ahzaab;

  setUpAll(() async {
    final font = await rootBundle.load('assets/fonts/AmiriQuran-Regular.ttf');
    final loader = FontLoader(quranFontFamily);
    loader.addFont(Future.value(font));
    await loader.load();
    final indopak = await rootBundle.load('assets/fonts/indopak.ttf');
    final fallback = FontLoader('Indopak');
    fallback.addFont(Future.value(indopak));
    await fallback.load();
    final raw = await rootBundle.loadString('assets/content/catalog.json');
    final items = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    String arabicOf(String title) => items.firstWhere(
      (item) => item['title'] == title,
    )['arabic'] as String;
    fatiha = arabicOf('Sourate al-Fâtihah (1)');
    ikhlas = arabicOf('Sourate al-Ikhlâç (112)');
    ahzaab = arabicOf('Sourate al-Ahzâb (33)');
  });

  testWidgets('al-Fâtihah est un flux justifié, pleine largeur', (
    tester,
  ) async {
    await _pump(tester, fatiha, width: 390, fontSize: 32);
    expect(_glyphWidth('ا'), isNot(closeTo(_glyphWidth('س'), 1)));
    final flow = tester.widget<Text>(_flow);
    final plain = _plain(flow);
    expect(find.byKey(const Key('quran-basmala')), findsNothing);
    expect(plain.startsWith('بِسۡمِ'), isTrue);
    expect(plain.contains('\u2060\u00A0﴿\u0661﴾'), isTrue);
    expect(plain.contains('\u06DD'), isFalse);
    expect(flow.textAlign, TextAlign.justify);
    expect(flow.textDirection, TextDirection.rtl);
    expect(flow.textWidthBasis, TextWidthBasis.parent);
    expect(flow.style!.fontFamily, quranFontFamily);
    expect(flow.style!.height, quranLineHeight);
    expect(flow.style!.color, const Color(0xFF000000));
    _expectNoCenter(tester, _flow);

    final width = tester.getSize(_flow).width;
    expect(width, closeTo(390 - 20, 1));
    _expectJustifiedLines(tester, _flow, width, atLeast: 4);
    await _shot(tester, 'fatiha-32');
    _expectRulesUnderLines(tester, _flow, width);
  });

  testWidgets('une sourate courte et une longue restent bord à bord', (
    tester,
  ) async {
    await _pump(tester, ikhlas, width: 390, fontSize: 32);
    expect(find.byKey(const Key('quran-basmala')), findsOneWidget);
    final basmala = tester.widget<Text>(find.byKey(const Key('quran-basmala')));
    final basmalaText =
        basmala.data ?? basmala.textSpan!.toPlainText(includeSemanticsLabels: false);
    expect(basmalaText.contains('\u06DD'), isFalse);
    expect(basmalaText.contains('﴿'), isFalse);
    expect(basmala.textAlign, TextAlign.justify);
    final flow = tester.widget<Text>(_flow);
    final plain = _plain(flow);
    expect(plain.contains('\u2060\u00A0﴿\u0661﴾'), isTrue);
    expect(plain.contains('بِسۡمِ'), isFalse);
    final width = tester.getSize(_flow).width;
    _expectJustifiedLines(tester, _flow, width, atLeast: 1);
    _expectRulesUnderLines(tester, _flow, width);
    await _shot(tester, 'ikhlas-32');

    await _pump(tester, ahzaab, width: 390, fontSize: 30);
    final longWidth = tester.getSize(_flow).width;
    _expectJustifiedLines(tester, _flow, longWidth, atLeast: 8);
    expect(find.byKey(const Key('quran-basmala')), findsOneWidget);
  });

  testWidgets('les traits suivent les cinq tailles et la largeur', (
    tester,
  ) async {
    const sizes = [24.0, 28.0, 34.0, 40.0, 46.0];
    int? previousLines;
    double? previousHeight;
    for (final size in sizes) {
      await _pump(tester, fatiha, width: 390, fontSize: size);
      final width = tester.getSize(_flow).width;
      expect(tester.widget<Text>(_flow).style!.fontSize, size);
      _expectRulesUnderLines(tester, _flow, width);
      final height = tester.getSize(_flow).height;
      if (previousHeight != null) {
        expect(height, greaterThan(previousHeight));
      }
      previousHeight = height;
      previousLines = _metricCount(tester, _flow, width);
    }
    expect(previousLines, greaterThan(3));

    await _pump(tester, fatiha, width: 800, fontSize: 32);
    final wide = _metricCount(tester, _flow, tester.getSize(_flow).width);
    await _pump(tester, fatiha, width: 390, fontSize: 32);
    final narrow = _metricCount(tester, _flow, tester.getSize(_flow).width);
    expect(wide, lessThan(narrow));
    await _pump(tester, fatiha, width: 390, fontSize: 46);
    _expectRulesUnderLines(tester, _flow, tester.getSize(_flow).width);
    await _shot(tester, 'fatiha-46');
    await _pump(tester, fatiha, width: 800, fontSize: 32);
    await _shot(tester, 'fatiha-paysage');
  });

  testWidgets('l’écran de lecture ne centre pas le flux', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: TextScreen(
          item: DevotionalText(
            id: 'fatiha',
            kind: DevotionalKind.quran,
            title: 'Sourate al-Fâtihah (1)',
            arabic: fatiha,
            translation: 'Traduction.\n\nInfos sur la sourate\n\nLieu:\n\nLa Mecque',
            transliteration: 'Bismillah',
            references: const [],
            audioIds: const [],
          ),
          edition: LocalEdition('/tmp', const {'home': 'index.html'}),
          favorite: false,
          onFavorite: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    _expectNoCenter(tester, _flow);
    final width = tester.getSize(_flow).width;
    expect(width, closeTo(390 - 16 - 16 - 10 - 10, 1));
    _expectJustifiedLines(tester, _flow, width, atLeast: 4);
    expect(find.text('Infos sur la sourate'), findsOneWidget);
    expect(find.text('Translation'), findsOneWidget);
  });
}

Finder get _flow => find.byKey(const Key('quran-flow'));

Future<void> _pump(
  WidgetTester tester,
  String arabic, {
  required double width,
  required double fontSize,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFFFFFFFF),
        body: ListView(
          children: [
            RepaintBoundary(
              key: const Key('mushaf-shot'),
              child: ColoredBox(
                color: const Color(0xFFFFFFFF),
                child: JustifiedQuranText(
                  text: arabic,
                  style: TextStyle(fontSize: fontSize, color: const Color(0xFF000000)),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _plain(Text text) =>
    text.textSpan!.toPlainText(includeSemanticsLabels: false);

double _glyphWidth(String glyph) {
  final painter = TextPainter(
    text: TextSpan(
      text: glyph,
      style: const TextStyle(fontFamily: quranFontFamily, fontSize: 32),
    ),
    textDirection: TextDirection.rtl,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

int _metricCount(WidgetTester tester, Finder finder, double width) {
  final paint = tester.widget<CustomPaint>(
    find.ancestor(of: finder, matching: find.byType(CustomPaint)).first,
  );
  return (paint.painter! as QuranLineRulesPainter).lineMetrics(width).length;
}

void _expectJustifiedLines(
  WidgetTester tester,
  Finder finder,
  double width, {
  required int atLeast,
}) {
  final paint = tester.widget<CustomPaint>(
    find.ancestor(of: finder, matching: find.byType(CustomPaint)).first,
  );
  final metrics = (paint.painter! as QuranLineRulesPainter).lineMetrics(width);
  expect(metrics.length, greaterThan(atLeast));
  final full = math.min(atLeast, metrics.length - 1);
  for (var i = 0; i < full; i++) {
    final line = metrics[i];
    expect(
      line.left,
      lessThan(24),
      reason: 'ligne $i left=${line.left} width=${line.width} cadre=$width',
    );
    expect(
      line.left + line.width,
      greaterThan(width - 24),
      reason: 'ligne $i right=${line.left + line.width} cadre=$width',
    );
  }
  final last = metrics.last;
  expect(
    last.left + last.width,
    greaterThan(width - 8),
    reason: 'dernière ligne collée à droite',
  );
}

void _expectRulesUnderLines(WidgetTester tester, Finder finder, double width) {
  final paint = tester.widget<CustomPaint>(
    find.ancestor(of: finder, matching: find.byType(CustomPaint)).first,
  );
  final painter = paint.painter! as QuranLineRulesPainter;
  final metrics = painter.lineMetrics(width);
  final ys = painter.ruleYs(width);
  final paragraph = _paragraph(tester, finder);
  expect(ys.length, metrics.length);
  expect(painter.laidOutHeight(width), closeTo(paragraph.size.height, 1.5));
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: paragraph.text.toPlainText().length),
  );
  final groups = List.generate(metrics.length, (_) => <TextBox>[]);
  for (final box in boxes) {
    final mid = (box.top + box.bottom) / 2;
    var line = 0;
    var best = double.infinity;
    for (var i = 0; i < metrics.length; i++) {
      final distance = (mid - metrics[i].baseline).abs();
      if (distance < best) {
        best = distance;
        line = i;
      }
    }
    groups[line].add(box);
  }
  for (var i = 0; i < metrics.length; i++) {
    expect(groups[i], isNotEmpty, reason: 'ligne $i sans glyphes');
    final glyphBottom = groups[i].map((box) => box.bottom).reduce(math.max);
    final nextTop = i + 1 < metrics.length
        ? groups[i + 1].map((box) => box.top).reduce(math.min)
        : paragraph.size.height;
    expect(
      ys[i],
      greaterThan(glyphBottom - 0.5),
      reason: 'trait $i sous l’encre (encre=$glyphBottom règle=${ys[i]} suivant=$nextTop)',
    );
    expect(ys[i], lessThan(nextTop), reason: 'trait $i avant la ligne suivante');
  }
}

void _expectNoCenter(WidgetTester tester, Finder finder) {
  expect(find.ancestor(of: finder, matching: find.byType(Center)), findsNothing);
  final columns = tester.widgetList<Column>(
    find.ancestor(of: finder, matching: find.byType(Column)),
  );
  for (final column in columns) {
    expect(column.crossAxisAlignment, isNot(CrossAxisAlignment.center));
  }
  final aligns = tester.widgetList<Align>(
    find.ancestor(of: finder, matching: find.byType(Align)),
  );
  for (final align in aligns) {
    expect(align.alignment, isNot(Alignment.center));
  }
  expect(tester.widget<Text>(finder).textAlign, isNot(TextAlign.center));
}

RenderParagraph _paragraph(WidgetTester tester, Finder finder) {
  RenderParagraph? found;
  void walk(Element node) {
    if (node.renderObject is RenderParagraph) {
      found = node.renderObject! as RenderParagraph;
    }
    node.visitChildElements(walk);
  }

  walk(tester.element(finder));
  return found!;
}

Future<void> _shot(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('mushaf-shot')),
  );
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 2));
  if (image == null) return;
  final data = await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.png),
  );
  if (data == null) return;
  final file = File('build/mushaf/$name.png');
  await tester.runAsync(() async {
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
  });
}
