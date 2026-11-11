import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:perles_divines/core/navigation.dart';
import 'package:perles_divines/core/track.dart';
import 'package:perles_divines/features/about/about_screen.dart';
import 'package:perles_divines/features/catalog/favorites_screen.dart';
import 'package:perles_divines/features/catalog/section_screen.dart';
import 'package:perles_divines/features/catalog/sections.dart';
import 'package:perles_divines/features/duas/catalog.dart';
import 'package:perles_divines/features/duas/dua.dart';
import 'package:perles_divines/features/player/site_mini_player.dart';
import 'package:perles_divines/features/sommaire/sommaire_screen.dart';
import 'package:perles_divines/routing.dart';
import 'package:perles_divines/ui/site.dart';
import 'package:perles_divines/ui/theme.dart';

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
    initialLocation: startLocation,
    routes: [
      GoRoute(path: '/', redirect: (context, state) => startLocation),
      ShellRoute(
        builder: (context, state, child) => Column(
          children: [
            Expanded(child: child),
            const SiteMiniPlayer(),
          ],
        ),
        routes: [
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
    expect(siteButtonBorder, const Color(0xff606060));
    expect(siteWhiteButtonText, const Color(0xff606060));
    expect(siteWhiteButtonBorder, const Color(0xff149214));
  });

  test('le texte blanc sur le vert atteint 4,5:1 de contraste', () {
    double ratio(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      final hi = x > y ? x : y, lo = x > y ? y : x;
      return (hi + 0.05) / (lo + 0.05);
    }

    for (final green in [siteGreenTop, siteGreenBottom, siteGreenSolid]) {
      expect(ratio(siteButtonText, green), greaterThanOrEqualTo(4.5));
    }
    // Le vert sert aussi de couleur de titre sur fond blanc.
    expect(ratio(siteGreenSolid, siteCanvas), greaterThanOrEqualTo(4.5));
  });

  test('les aamal mensuels et spécifiques restent séparés', () {
    expect(CatalogSection.aamalMensuel.matches(_monthly), isTrue);
    expect(CatalogSection.aamalSpecifique.matches(_monthly), isFalse);
    expect(CatalogSection.aamalSpecifique.matches(_specific), isTrue);
    expect(CatalogSection.aamalMensuel.matches(_specific), isFalse);
    expect(CatalogSection.douas.matches(_kumayl), isTrue);
  });

  testWidgets('l’app s’ouvre directement sur le sommaire', (tester) async {
    await tester.pumpWidget(_app());
    await _settle(tester);
    expect(find.text('Doua'), findsOneWidget);
    expect(find.byKey(const Key('site-search')), findsOneWidget);
    expect(find.byKey(const Key('sommaire-button')), findsNothing);
    expect(find.byKey(const Key('site-player')), findsNothing);
    expect(find.text('Aucun audio en cours'), findsNothing);
  });

  testWidgets('l’ancienne adresse d’accueil mène au sommaire', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', redirect: (context, state) => startLocation),
        GoRoute(
          path: '/sommaire',
          builder: (context, state) => const SommaireScreen(catalog: _catalog),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await _settle(tester);
    expect(find.text('Doua'), findsOneWidget);
  });

  testWidgets('À propos garde la présentation, le site et le contact', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));
    await _settle(tester);
    expect(find.textContaining('est un recueil'), findsOneWidget);
    expect(find.textContaining('InchAllah'), findsOneWidget);
    expect(find.text('www.perlesdivines.fr'), findsOneWidget);
    expect(find.text('contact@perlesdivines.fr'), findsOneWidget);
    expect(find.text('Version $appVersion'), findsOneWidget);
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
    expect(find.text('Doua'), findsOneWidget);
    expect(find.text('Zyaarate'), findsOneWidget);
    expect(find.text('Aamal Spécifique'), findsOneWidget);
    expect(find.text('Audios'), findsOneWidget);
    expect(find.text('Favoris'), findsOneWidget);
    expect(find.text('À propos'), findsOneWidget);
    expect(find.text('Version $appVersion'), findsNothing);
    final betweenSections =
        tester.getTopLeft(find.text('Aamal Mensuel')).dy -
        tester.getBottomLeft(find.text('Aamal Spécifique')).dy;
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

    await tester.showKeyboard(find.byKey(const Key('site-search')));
    await tester.enterText(find.byKey(const Key('site-search')), 'K');
    await _settle(tester);
    expect(find.text('K'), findsOneWidget);
    expect(find.text('Doua'), findsOneWidget);
    expect(find.text('Namaz'), findsOneWidget);
    expect(tester.binding.focusManager.primaryFocus?.hasPrimaryFocus, isTrue);

    await tester.enterText(find.byKey(const Key('site-search')), 'Ku');
    await _settle(tester);
    expect(find.text('Doua-e-Kumayl'), findsOneWidget);
    expect(find.text('Namaz'), findsNothing);

    await tester.enterText(find.byKey(const Key('site-search')), 'Kumayl');
    await _settle(tester);
    expect(find.text('Doua-e-Kumayl'), findsOneWidget);
    expect(find.text('Namaz'), findsNothing);
  });

  testWidgets(
    'la recherche trouve un audio et ne s’étire pas sur un grand écran',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const track = Track(
        id: 'ramzane-10',
        title: 'Douà 10 Mahé Ramzane',
        version: 1,
        durationMs: 1000,
        sizeBytes: 10,
        sha256: 'abc',
        file: 'audio/ramzane.m4a',
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: SommaireScreen(catalog: _catalog, tracks: [track]),
        ),
      );
      await _settle(tester);
      await tester.enterText(find.byKey(const Key('site-search')), 'Ramzane');
      await _settle(tester);

      expect(find.text('Douà 10 Mahé Ramzane'), findsOneWidget);
      expect(find.text('Audio'), findsOneWidget);
      expect(find.text('Doua'), findsNothing);
      expect(
        find.text('Aucun texte ni audio ne correspond à cette recherche.'),
        findsNothing,
      );
      final result = tester.getSize(
        find.byKey(const Key('search-audio-ramzane-10')),
      );
      expect(result.width, lessThan(450));
      expect(result.width, lessThan(tester.view.physicalSize.width / 2));
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(360, 740);
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(const Key('search-audio-ramzane-10'))).width,
        lessThanOrEqualTo(360),
      );
    },
  );

  testWidgets('une rubrique affiche ses prières', (tester) async {
    await tester.pumpWidget(_app());
    await _settle(tester);
    await tester.tap(find.text('Doua'));
    await _settle(tester);
    expect(find.text('Doua-e-Kumayl'), findsOneWidget);
    expect(find.text('Retour au sommaire'), findsOneWidget);
    expect(find.byKey(const Key('section-home')), findsOneWidget);
  });

  testWidgets('un favori montre une étoile pleine, sinon une étoile vide', (
    tester,
  ) async {
    Future<void> show(bool favorite) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SiteReaderHeader(
              title: 'Namaz',
              favorite: favorite,
              onBack: () {},
              onFavorite: () {},
            ),
          ),
        ),
      );
    }

    await show(true);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    expect(find.byIcon(Icons.star_border_rounded), findsNothing);
    expect(find.byIcon(Icons.favorite), findsNothing);

    await show(false);
    expect(find.byIcon(Icons.star_border_rounded), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNothing);
  });

  testWidgets('les pages intérieures gardent un logo réduit', (tester) async {
    await tester.pumpWidget(_app());
    await _settle(tester);
    final full = tester.getSize(find.byType(SiteLogo)).height;
    await tester.tap(find.text('Doua'));
    await _settle(tester);
    final compact = tester.getSize(find.byType(SiteLogo)).height;
    expect(compact, lessThan(full * 0.75));
  });

  testWidgets('la maison d’une rubrique ramène au sommaire', (tester) async {
    await tester.pumpWidget(_app());
    await _settle(tester);

    for (final section in ['Qur\'an', 'Namaz', 'Doua', 'Zyaarate']) {
      await tester.tap(find.text(section));
      await _settle(tester);
      expect(find.byKey(const Key('section-home')), findsOneWidget);
      await tester.tap(find.byKey(const Key('section-home')));
      await _settle(tester);
      expect(find.text('À propos'), findsOneWidget);
      expect(find.byKey(const Key('section-home')), findsNothing);
    }
  });

  testWidgets('l’app reste claire quand le téléphone est en mode sombre', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme(),
        home: const SitePage(children: [SiteBlackText('Bismillah')]),
      ),
    );
    final page = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(page.backgroundColor, siteCanvas);
    final text = tester.renderObject<RenderParagraph>(find.text('Bismillah'));
    expect(text.text.style?.color, siteBlack);
  });

  testWidgets(
    'logo, recherche et boutons défilent ensemble, sans rouvrir le clavier',
    (tester) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app());
      await _settle(tester);
      final search = find.byKey(const Key('site-search'));
      final searchTop = tester.getTopLeft(search).dy;
      final logoTop = tester.getTopLeft(find.byType(SiteLogo)).dy;
      final namazTop = tester.getTopLeft(find.text('Namaz')).dy;

      await tester.drag(find.text('Namaz'), const Offset(0, -150));
      await tester.pumpAndSettle();
      // Tout monte du même pas : la recherche part avec les boutons.
      final moved = namazTop - tester.getTopLeft(find.text('Namaz')).dy;
      expect(moved, greaterThan(50));
      expect(searchTop - tester.getTopLeft(search).dy, closeTo(moved, 0.5));
      expect(
        logoTop - tester.getTopLeft(find.byType(SiteLogo)).dy,
        closeTo(moved, 0.5),
      );

      await tester.drag(find.text('Namaz'), const Offset(0, 400));
      await tester.pumpAndSettle();
      await tester.tap(search);
      await tester.pump();
      bool focused() => tester
          .widget<EditableText>(find.byType(EditableText))
          .focusNode
          .hasFocus;
      expect(focused(), isTrue);
      await tester.tap(find.text('Doua'));
      await _settle(tester);
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      // De retour au sommaire, la recherche n’a plus la main : pas de clavier.
      expect(find.byKey(const Key('favoris-section')), findsOneWidget);
      expect(focused(), isFalse);
    },
  );

  testWidgets('« Sommaire » efface la recherche, le bouton retour la garde', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await _settle(tester);
    String typed() => tester
        .widget<TextField>(find.byKey(const Key('site-search')))
        .controller!
        .text;

    // Le retour ramène aux résultats laissés.
    await tester.enterText(find.byKey(const Key('site-search')), 'kumayl');
    await tester.pump();
    await tester.tap(find.byKey(const Key('search-text-kumayl')));
    await tester.pumpAndSettle();
    expect(find.text('texte ouvert'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(typed(), 'kumayl');
    expect(find.byKey(const Key('search-text-kumayl')), findsOneWidget);

    // « Sommaire » ouvre un sommaire vierge.
    await tester.tap(find.byKey(const Key('search-text-kumayl')));
    await tester.pumpAndSettle();
    goToSommaire(tester.element(find.text('texte ouvert')));
    await tester.pumpAndSettle();
    expect(typed(), isEmpty);
    expect(find.byKey(const Key('search-text-kumayl')), findsNothing);
    expect(find.text('Doua'), findsOneWidget);
  });
}
