import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:perles_divines/features/about/about_screen.dart';
import 'package:perles_divines/features/catalog/favorites_screen.dart';
import 'package:perles_divines/features/catalog/section_screen.dart';
import 'package:perles_divines/features/catalog/sections.dart';
import 'package:perles_divines/features/duas/catalog.dart';
import 'package:perles_divines/features/duas/dua.dart';
import 'package:perles_divines/features/home/home_screen.dart';
import 'package:perles_divines/features/player/site_mini_player.dart';
import 'package:perles_divines/features/sommaire/sommaire_screen.dart';
import 'package:perles_divines/ui/site.dart';

const _kumayl = DevotionalText(
  id: 'kumayl',
  kind: DevotionalKind.dua,
  title: 'Doua-e-Kumayl',
  arabic: '',
  translation: 'Invocation de Kumayl',
  transliteration: '',
  references: [],
  audioIds: ['audio-kumayl'],
);

const _monthly = DevotionalText(
  id: 'rajab',
  kind: DevotionalKind.aamal,
  title: 'Aamal du mois de Rajab',
  arabic: '',
  translation: '',
  transliteration: '',
  references: [],
  audioIds: [],
);

const _specific = DevotionalText(
  id: 'reussite',
  kind: DevotionalKind.aamal,
  title: 'Aamal pour la réussite (par Ayatollah Nakhudaki)',
  arabic: '',
  translation: '',
  transliteration: '',
  references: [],
  audioIds: [],
);

const _catalog = LocalDevotionalCatalog([_kumayl, _monthly, _specific]);

Widget _app() {
  final router = GoRouter(
    routes: [
      ShellRoute(
        builder: (context, state, child) => Column(
          children: [
            Expanded(child: child),
            const SiteMiniPlayer(),
          ],
        ),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          GoRoute(
            path: '/sommaire',
            builder: (context, state) =>
                const SommaireScreen(catalog: _catalog),
          ),
          GoRoute(
            path: '/section/:id',
            builder: (context, state) {
              final section = CatalogSection.byId(
                state.pathParameters['id'] ?? '',
              )!;
              return SectionScreen(section: section, catalog: _catalog);
            },
          ),
          GoRoute(
            path: '/text/:id',
            builder: (context, state) =>
                const Scaffold(body: Text('texte ouvert')),
          ),
          GoRoute(
            path: '/audios',
            builder: (context, state) => const Scaffold(body: Text('audios')),
          ),
          GoRoute(
            path: '/favoris',
            builder: (context, state) => const FavoritesScreen(),
          ),
          GoRoute(
            path: '/about',
            builder: (context, state) => const AboutScreen(),
          ),
        ],
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  test('la charte reprend les hexadécimaux du CSS mobile', () {
    expect(siteCanvas, const Color(0xffffffff));
    expect(siteGreen, const Color(0xff145014));
    expect(siteLink, const Color(0xff124e12));
    expect(siteBlack, const Color(0xff000000));
    expect(siteButtonText, const Color(0xffe8f0de));
    expect(siteButtonBorder, const Color(0xff606060));
    expect(siteGreenSolid, const Color(0xff64991e));
    expect(siteGreenTop, const Color(0xff7db72f));
    expect(siteGreenBottom, const Color(0xff4e7d0e));
    expect(siteWhiteButtonText, const Color(0xff606060));
    expect(siteWhiteButtonBorder, const Color(0xff149214));
    expect(siteGlow, const Color(0xffffffd0));
  });

  test('les aamal mensuels et spécifiques restent séparés', () {
    expect(CatalogSection.aamalMensuel.matches(_monthly), isTrue);
    expect(CatalogSection.aamalSpecifique.matches(_monthly), isFalse);
    expect(CatalogSection.aamalSpecifique.matches(_specific), isTrue);
    expect(CatalogSection.aamalMensuel.matches(_specific), isFalse);
    expect(CatalogSection.douas.matches(_kumayl), isTrue);
  });

  testWidgets('l’accueil reprend les textes du site mobile', (tester) async {
    await tester.pumpWidget(_app());
    await _settle(tester);
    expect(find.textContaining('receuil'), findsOneWidget);
    expect(find.text('Sommaire'), findsOneWidget);
    expect(find.textContaining('disponibles hors connexion'), findsOneWidget);
    expect(find.textContaining('application web'), findsNothing);
    expect(find.textContaining('connexion Internet'), findsNothing);
    expect(find.textContaining('InchAllah'), findsOneWidget);
    expect(find.text('www.perlesdivines.fr'), findsOneWidget);
    expect(find.text('contact@perlesdivines.fr'), findsOneWidget);
    expect(find.byKey(const Key('site-player')), findsNothing);
    expect(find.text('Aucun audio en cours'), findsNothing);
  });

  testWidgets('sans lecture, seul l’inset système est réservé en bas', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(padding: EdgeInsets.only(bottom: 48)),
          child: Align(alignment: Alignment.topCenter, child: SiteMiniPlayer()),
        ),
      ),
    );
    expect(tester.getSize(find.byType(SiteMiniPlayer)).height, 48);
    expect(find.byKey(const Key('site-player')), findsNothing);
  });

  testWidgets('le sommaire liste les rubriques et la recherche', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await _settle(tester);
    await tester.tap(find.byKey(const Key('sommaire-button')));
    await _settle(tester);
    expect(find.text('Doua'), findsOneWidget);
    expect(find.text('Zyaraate'), findsOneWidget);
    expect(find.text('Aamal Specifique'), findsOneWidget);
    expect(find.text('Audios'), findsOneWidget);
    expect(find.text('Favoris'), findsOneWidget);
    expect(find.text('A Propos ...'), findsOneWidget);
    expect(find.text('Version $appVersion'), findsOneWidget);
    final betweenSections =
        tester.getTopLeft(find.text('Aamal Mensuel')).dy -
        tester.getBottomLeft(find.text('Aamal Specifique')).dy;
    final beforeAudios =
        tester.getTopLeft(find.text('Audios')).dy -
        tester.getBottomLeft(find.text('Aamal Mensuel')).dy;
    expect(beforeAudios, closeTo(betweenSections, 0.5));
    final beforeFavoris =
        tester.getTopLeft(find.text('Favoris')).dy -
        tester.getBottomLeft(find.text('Audios')).dy;
    expect(beforeFavoris, closeTo(betweenSections, 0.5));
    expect(find.textContaining('Tafsir'), findsNothing);
    expect(find.textContaining('Diaporama'), findsNothing);
    expect(find.byKey(const Key('site-search')), findsOneWidget);
    expect(find.byKey(const Key('section-home')), findsNothing);
    expect(find.byKey(const Key('site-player')), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const Key('site-search'))).dy,
      lessThan(tester.getTopLeft(find.byType(SiteBismillah)).dy),
    );

    await tester.enterText(find.byKey(const Key('site-search')), 'Kumayl');
    await _settle(tester);
    expect(find.text('Doua-e-Kumayl'), findsOneWidget);
    expect(find.text('Namaz'), findsNothing);
  });

  testWidgets('une rubrique affiche ses prières', (tester) async {
    await tester.pumpWidget(_app());
    await _settle(tester);
    await tester.tap(find.byKey(const Key('sommaire-button')));
    await _settle(tester);
    await tester.tap(find.text('Doua'));
    await _settle(tester);
    expect(find.text('Doua-e-Kumayl'), findsOneWidget);
    expect(find.text('Retour au sommaire'), findsOneWidget);
    expect(find.byKey(const Key('section-home')), findsOneWidget);
  });

  testWidgets('la maison d’une rubrique ramène au sommaire', (tester) async {
    await tester.pumpWidget(_app());
    await _settle(tester);
    await tester.tap(find.byKey(const Key('sommaire-button')));
    await _settle(tester);

    for (final section in ['Qur\'an', 'Namaz', 'Doua', 'Zyaraate']) {
      await tester.tap(find.text(section));
      await _settle(tester);
      expect(find.byKey(const Key('section-home')), findsOneWidget);
      await tester.tap(find.byKey(const Key('section-home')));
      await _settle(tester);
      expect(find.text('A Propos ...'), findsOneWidget);
      expect(find.byKey(const Key('section-home')), findsNothing);
    }
  });
}
