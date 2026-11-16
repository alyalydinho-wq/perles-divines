import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perles_divines/features/catalog/text_screen.dart';
import 'package:perles_divines/features/duas/dua.dart';
import 'package:perles_divines/features/reader/content_install.dart';
import 'package:perles_divines/ui/motion.dart';

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
    // Lent mais jusqu’à la moitié de la largeur.
    expect(swipeDirection(dx: -200, dyMax: 10, velocity: 0, width: 360), -1);
    // Court mais lancé.
    expect(swipeDirection(dx: -60, dyMax: 10, velocity: -1500, width: 360), -1);
    expect(swipeDirection(dx: 200, dyMax: 0, velocity: 0, width: 360), 1);
    // Trop court, même très rapide.
    expect(swipeDirection(dx: -30, dyMax: 0, velocity: -3000, width: 360), 0);
    // Pas à mi-chemin et sans élan.
    expect(swipeDirection(dx: -120, dyMax: 0, velocity: 0, width: 360), 0);
    // Autant vertical qu’horizontal.
    expect(swipeDirection(dx: -200, dyMax: 180, velocity: 0, width: 360), 0);
    // Le doigt repart en arrière avant de lâcher.
    expect(swipeDirection(dx: -200, dyMax: 0, velocity: 800, width: 360), 0);
  });

  testWidgets('glisser vers la gauche ouvre la lecture suivante, vers la droite '
      'la précédente', (tester) async {
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
