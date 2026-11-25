import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:perles_divines/features/duas/catalog.dart';
import 'package:perles_divines/features/reader/original_page.dart';

void main() {
  test('les blocs de la page se lisent tels que l’outil les écrit', () {
    final pages = OriginalPages.parse('''
{"abc": {"title": "Titre", "blocks": [
  {"p": [{"t": "Gras vert", "b": 1, "c": "#145014", "s": 16},
         {"t": " lien", "u": 1, "h": "page:def#X"}], "a": "j", "k": ["haut"]},
  {"img": "x.gif", "iw": 480, "ih": 240, "f": 1, "h": "#bas"},
  {"button": "Retour au sommaire", "green": 1, "h": "sommaire"},
  {"row": [[{"gap": 1}], [{"p": [{"t": "fin"}], "k": ["bas"]}]]},
  {"hr": 1},
  {"p": [{"t": "اللهُ"}], "d": "rtl", "ar": 1}
]}}''');
    final page = pages['ABC']!;
    expect(page.title, 'Titre');
    final first = page.blocks[0] as ParagraphBlock;
    expect(first.align, PageAlign.justify);
    expect(first.spans.first.bold, isTrue);
    expect(first.spans.first.color, const Color(0xff145014));
    expect(first.spans.first.points, 16);
    expect(first.spans.last.link, 'page:def#X');
    final image = page.blocks[1] as ImageBlock;
    expect(image.asset, 'assets/pages/x.gif');
    expect(image.fraction, 1);
    expect((page.blocks[2] as ButtonBlock).green, isTrue);
    expect(page.blocks[4], isA<RuleBlock>());
    expect((page.blocks[5] as ParagraphBlock).arabic, isTrue);
    // L’ancre posée dans une cellule désigne sa rangée.
    expect(page.indexOf('haut'), 0);
    expect(page.indexOf('bas'), 3);
    expect(page.indexOf('absente'), isNull);
  });

  test('un lien désigne le sommaire, une ancre, une page ou l’extérieur', () {
    expect(pageDestination('sommaire'), isA<OpenSommaire>());
    expect((pageDestination('#TRADUCTION') as ScrollToAnchor).anchor, 'TRADUCTION');
    final page = pageDestination('page:abc#1st_Day_') as OpenCatalogPage;
    expect((page.id, page.anchor), ('abc', '1st_Day_'));
    expect((pageDestination('page:abc') as OpenCatalogPage).anchor, isNull);
    expect(pageDestination('https://www.perlesdivines.fr/'), isA<OpenExternal>());
    expect(pageDestination('mailto:a@b.c'), isA<OpenExternal>());
    expect(pageDestination('javascript:alert(1)'), isNull);
    expect(pageDestination('page:'), isNull);
  });

  test('la copie HTML des anciennes versions est effacée', () async {
    final root = await Directory.systemTemp.createTemp('perles-support-');
    addTearDown(() => root.delete(recursive: true));
    final copy = Directory(p.join(root.path, 'content', 'initial-2026'));
    await copy.create(recursive: true);
    await File(p.join(copy.path, 'page.html')).writeAsString('<p>x</p>');
    final media = Directory(p.join(root.path, 'media'));
    await media.create();
    await removeCopiedEdition(root);
    expect(await Directory(p.join(root.path, 'content')).exists(), isFalse);
    // Les audios téléchargés restent.
    expect(await media.exists(), isTrue);
    // Rien à effacer : aucune erreur.
    await removeCopiedEdition(root);
  });

  test('chaque texte à page d’origine a sa page, et ses images existent', () {
    final catalog = LocalDevotionalCatalog.parse(
      File('assets/content/catalog.json').readAsStringSync(),
    );
    final pages = OriginalPages.parse(
      File('assets/content/pages.json').readAsStringSync(),
    );
    for (final item in catalog.items.where((item) => item.hasOriginalPage)) {
      expect(pages[item.id], isNotNull, reason: item.title);
      expect(pages[item.id]!.blocks, isNotEmpty, reason: item.title);
    }
    // Les images sont générées (hors Git) : on les vérifie quand elles sont là.
    final images = Directory('assets/pages');
    if (!images.existsSync()) return;
    void check(List<PageBlock> blocks) {
      for (final block in blocks) {
        if (block is ImageBlock) {
          expect(File(block.asset).existsSync(), isTrue, reason: block.name);
          expect(block.intrinsicWidth, greaterThan(0));
        }
        if (block is RowBlock) block.cells.forEach(check);
      }
    }

    for (final page in pages.pages.values) {
      check(page.blocks);
    }
  });

  testWidgets('un lien du texte est suivi, une ancre fait défiler', (
    tester,
  ) async {
    final followed = <PageDestination>[];
    final page = OriginalPage(
      title: 'Page',
      blocks: [
        const ParagraphBlock(
          anchors: [],
          spans: [
            PageSpan(text: 'Réciter la sourate '),
            PageSpan(text: 'Al-Fâtihah', link: 'page:7918100a', underline: true),
          ],
        ),
        const ButtonBlock(anchors: [], label: 'Aller en bas', link: '#bas'),
        for (var i = 0; i < 60; i++) const GapBlock([], 4),
        const ParagraphBlock(anchors: ['bas'], spans: [PageSpan(text: 'Tout en bas')]),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OriginalPageView(page: page, onLink: followed.add),
        ),
      ),
    );
    // La phrase est centrée et le lien en est la fin : on touche à droite
    // du milieu.
    final paragraph = find.textContaining('Al-Fâtihah', findRichText: true);
    await tester.tapAt(tester.getCenter(paragraph) + const Offset(150, 0));
    expect(followed.single, isA<OpenCatalogPage>());

    expect(find.text('Tout en bas'), findsNothing);
    await tester.tap(find.text('Aller en bas'));
    await tester.pumpAndSettle();
    expect(find.text('Tout en bas'), findsOneWidget);
    expect(followed, hasLength(1));
  });

  testWidgets('la taille « Aa » agrandit le texte, pas les images', (
    tester,
  ) async {
    const page = OriginalPage(
      title: 'Page',
      blocks: [
        ParagraphBlock(anchors: [], spans: [PageSpan(text: 'Texte')]),
        ImageBlock(
          anchors: [],
          name: 'absente.gif',
          intrinsicWidth: 92,
          intrinsicHeight: 48,
        ),
      ],
    );
    Future<(double, Size)> measure(double scale) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: OriginalPageView(page: page, scale: scale)),
        ),
      );
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byType(OriginalPageView),
          matching: find.byType(Text),
        ).first,
      );
      final size = text.textSpan!.style!.fontSize!;
      return (size, tester.getSize(find.byType(Image)));
    }

    final (normal, image) = await measure(1);
    final (large, sameImage) = await measure(22 / 18);
    expect(normal, closeTo(18.67, 0.01));
    expect(large, greaterThan(normal));
    expect(image, const Size(92, 48));
    expect(sameImage, image);
  });
}
