import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perles_divines/features/catalog/text_screen.dart';
import 'package:perles_divines/features/duas/dua.dart';
import 'package:perles_divines/features/reader/content_install.dart';
import 'package:perles_divines/ui/motion.dart';
import 'package:perles_divines/ui/site.dart';

const _arabic = 'بِسْمِ اللّٰهِ';
const _french = 'Au nom d’Allàh, le Tout Miséricordieux.';
const _latin = 'BISMILLAHIR RAHMANIR RAHEEM';

const _item = DevotionalText(
  id: 'ziyarat-1',
  kind: DevotionalKind.ziyarat,
  title: 'Ziyarat e Aale Yasin',
  arabic: _arabic,
  translation: _french,
  transliteration: _latin,
  references: [],
  audioIds: [],
);

Widget _app() => MaterialApp(
  home: TextScreen(
    item: _item,
    edition: LocalEdition('/tmp', const {'home': 'index.html'}),
    favorite: false,
    onFavorite: () async {},
  ),
);

void main() {
  test('un glissement ne compte que s’il est net et voulu', () {
    int swipe(double dx, double dy, double velocity) =>
        swipeDirection(dx: dx, dy: dy, velocity: velocity, width: 360);
    // Lent, sur plus d’un tiers de la largeur.
    expect(swipe(-130, 10, 0), -1);
    expect(swipe(130, 0, 0), 1);
    // Court mais lancé, même modérément, comme un pouce.
    expect(swipe(-60, 10, -1500), -1);
    expect(swipe(-70, 30, -350), -1);
    expect(swipe(70, -20, 400), 1);
    // Un pouce décrit un arc : un peu de vertical ne gêne pas.
    expect(swipe(-120, 60, -800), -1);
    // Trop court, même très rapide.
    expect(swipe(-30, 0, -3000), 0);
    // Lent et pas assez loin.
    expect(swipe(-100, 0, 0), 0);
    expect(swipe(-100, 0, -150), 0);
    // Autant vertical qu’horizontal.
    expect(swipe(-200, 180, -800), 0);
    // Le doigt repart en arrière avant de lâcher.
    expect(swipe(-200, 0, 800), 0);
  });

  testWidgets('le geste ne reconstruit pas les lectures à chaque image', (
    tester,
  ) async {
    var builds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PaneSwipe(
          index: 1,
          count: 3,
          onSwipe: (_) {},
          builder: (context, index, role) {
            builds++;
            return ColoredBox(
              color: Colors.white,
              child: Center(child: Text('Lecture $index')),
            );
          },
        ),
      ),
    );
    // Les deux voisines se préparent en coulisse.
    await tester.pump(const Duration(seconds: 1));
    final before = builds;

    final gesture = await tester.startGesture(const Offset(400, 300));
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(-8, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    // La voisine apparaît : une seule reconstruction des trois lectures, et
    // non trois par image.
    expect(builds - before, lessThanOrEqualTo(3));
    final pane = tester.getTopLeft(find.text('Lecture 2')).dx;
    expect(pane, lessThan(800 + 400));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  test('l’élan se lit malgré des points rares et irréguliers', () {
    Duration ms(int value) => Duration(milliseconds: value);
    // Points relevés sur l’émulateur : des trous de 30 à 50 ms, où
    // l’estimateur de Flutter rendait zéro.
    final flick = FlickMeter()
      ..add(ms(0), 300)
      ..add(ms(12), 290)
      ..add(ms(42), 260)
      ..add(ms(54), 245)
      ..add(ms(100), 190)
      ..add(ms(110), 180)
      ..add(ms(110), 180);
    expect(flick.velocity, lessThan(-1000));

    // Vers la droite, le même geste donne le même élan, de l’autre signe.
    final back = FlickMeter()
      ..add(ms(0), 180)
      ..add(ms(48), 240)
      ..add(ms(96), 300)
      ..add(ms(96), 300);
    expect(back.velocity, greaterThan(1000));
  });

  test('un doigt arrêté avant de se lever n’a plus d’élan', () {
    Duration ms(int value) => Duration(milliseconds: value);
    final flick = FlickMeter()
      ..add(ms(0), 300)
      ..add(ms(40), 200)
      ..add(ms(80), 120)
      ..add(ms(600), 120);
    expect(flick.velocity, 0);
    expect(FlickMeter().velocity, 0);
  });

  test('des points manquants avant le lever ne coupent pas l’élan', () {
    Duration ms(int value) => Duration(milliseconds: value);
    // Plus rien pendant 150 ms, mais le doigt a continué : il était lancé.
    final flick = FlickMeter()
      ..add(ms(0), 300)
      ..add(ms(20), 280)
      ..add(ms(170), 120);
    expect(flick.velocity, lessThan(-1000));
  });

  testWidgets(
    'glisser vers la gauche ouvre la lecture suivante, vers la droite '
    'la précédente',
    (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text(_arabic), findsOneWidget);

      await tester.fling(find.text(_arabic), const Offset(-250, 0), 1200);
      await tester.pumpAndSettle();
      expect(find.text(_french), findsOneWidget);
      expect(find.text(_arabic), findsNothing);

      await tester.fling(find.text(_french), const Offset(-250, 0), 1200);
      await tester.pumpAndSettle();
      expect(find.text(_latin), findsOneWidget);

      await tester.fling(find.text(_latin), const Offset(250, 0), 1200);
      await tester.pumpAndSettle();
      expect(find.text(_french), findsOneWidget);
    },
  );

  testWidgets('la voisine suit le doigt et s’ouvre dès qu’on lâche', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    // Laisse le temps de préparer les voisines en coulisse.
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(_french), findsNothing);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text(_arabic)),
    );
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(-50, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    // Pendant le geste, la traduction entre déjà par la droite.
    expect(find.text(_french), findsOneWidget);
    final width = tester.getSize(find.byType(MaterialApp)).width;
    expect(tester.getTopLeft(find.text(_french)).dx, lessThan(width));

    await gesture.up();
    await tester.pump();
    // Un seul cadre après le lâcher : l’onglet a déjà changé.
    final tabs = tester.widget<SiteTextTabs>(find.byType(SiteTextTabs));
    expect(tabs.selected, TextPane.translation.index);

    await tester.pumpAndSettle();
    expect(find.text(_french), findsOneWidget);
    expect(find.text(_arabic), findsNothing);
  });

  testWidgets('un geste court, en biais ou sans voisine laisse la lecture', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.drag(find.text(_arabic), const Offset(-30, 0));
    await tester.pumpAndSettle();
    expect(find.text(_arabic), findsOneWidget);

    await tester.drag(find.text(_arabic), const Offset(-120, 200));
    await tester.pumpAndSettle();
    expect(find.text(_arabic), findsOneWidget);

    // Pas de lecture avant l’arabe : le geste résiste puis revient.
    await tester.fling(find.text(_arabic), const Offset(250, 0), 1200);
    await tester.pumpAndSettle();
    expect(find.text(_arabic), findsOneWidget);
    expect(find.text(_french), findsNothing);
  });

  testWidgets('le menu de sélection ne propose que la copie', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Traduction'));
    await tester.pumpAndSettle();

    await tester.longPress(find.text(_french));
    await tester.pumpAndSettle();
    expect(find.text('Copier'), findsOneWidget);
    expect(find.text('Tout sélectionner'), findsOneWidget);
    expect(find.text('Copy'), findsNothing);
    expect(find.text('Select all'), findsNothing);
    expect(find.text('Share'), findsNothing);
  });
}
