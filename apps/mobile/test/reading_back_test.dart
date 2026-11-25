import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:perles_divines/core/scope.dart';
import 'package:perles_divines/core/services.dart';
import 'package:perles_divines/core/store.dart';
import 'package:perles_divines/features/catalog/favorites_screen.dart';
import 'package:perles_divines/features/catalog/section_screen.dart';
import 'package:perles_divines/features/catalog/sections.dart';
import 'package:perles_divines/features/duas/catalog.dart';
import 'package:perles_divines/features/duas/dua.dart';
import 'package:perles_divines/features/duas/favorites.dart';
import 'package:perles_divines/features/reader/original_page.dart';
import 'package:perles_divines/features/reader/original_page_screen.dart';
import 'package:perles_divines/features/sommaire/sommaire_screen.dart';
import 'package:perles_divines/ui/site.dart';

const _safar = '50ebee15-3228-5bd9-944b-a1d847c06e5a';
const _safarDua = 'c97581bf-b0ab-5a0b-8c74-0c4813dce712';
const _arbaeen = '2991d127-9b1a-525f-bcc2-5b07b5626bcc';
const _rajab = 'a5becaaa-d8e4-50f3-b7c5-cdd00e31b232';
const _rajabDua = '7dc1b848-72f1-5d99-a96c-d09843597b5e';
const _ramadhan = 'a21cb585-f002-5c39-baff-38928673c3ac';
const _ramadhanNamaz = '02d64c56-4c53-553b-ae94-b12852a5473f';
const _ramadhanDays = '640d4c0d-0000-4000-8000-000000000003';
const _shab = '13f8d881-0000-4000-8000-000000000010';
const _fatihah = '7918100a-56f9-5035-b4b0-46e1e2c53b32';

DevotionalText _text({
  required String id,
  required DevotionalKind kind,
  required String title,
  String arabic = '',
  String translation = '',
  bool page = false,
}) {
  return DevotionalText(
    id: id,
    kind: kind,
    title: title,
    arabic: arabic,
    translation: translation,
    transliteration: '',
    references: const [],
    audioIds: const [],
    pagePath: page ? 'pages/$id.html' : '',
  );
}

/// Page d’origine réduite : son titre puis un bouton par lien.
OriginalPage _page(
  String title, {
  List<(String, String)> links = const [],
  List<PageBlock> extra = const [],
}) => OriginalPage(
  title: title,
  blocks: [
    ParagraphBlock(
      anchors: const [],
      spans: [PageSpan(text: title, bold: true)],
    ),
    for (final (label, link) in links)
      ButtonBlock(anchors: const [], label: label, link: link),
    ...extra,
  ],
);

final _pages = OriginalPages({
  _safar: _page(
    'Aamal du mois de Safar',
    links: [
      ('Doua du mois de Safar', 'page:$_safarDua'),
      ('Zyaarat-e-Arbae\'en', 'page:$_arbaeen'),
      ('Retour au sommaire', 'sommaire'),
    ],
  ),
  _rajab: _page(
    'Aamal du mois de Rajab',
    links: [('Doua du mois de Rajab', 'page:$_rajabDua')],
  ),
  _ramadhan: _page(
    'Aamal du mois de Ramadhan',
    links: [('Namaz du 1 au 30 Ramadhan', 'page:$_ramadhanNamaz')],
  ),
  _ramadhanNamaz: _page(
    'Namaz du 1 au 30 Ramadhan',
    links: [
      ('1er jour', 'page:$_ramadhanDays#jour-1'),
      ('Plus bas', '#bas'),
    ],
    extra: [
      for (var i = 0; i < 40; i++) const GapBlock([], 4),
      const ParagraphBlock(
        anchors: ['bas'],
        spans: [PageSpan(text: 'Fin de la page')],
      ),
    ],
  ),
  // Page d’origine qui n’est pas un texte du catalogue.
  _ramadhanDays: _page(
    'Les jours du Ramadhan',
    extra: [
      for (var i = 0; i < 40; i++) const GapBlock([], 4),
      const ParagraphBlock(
        anchors: ['jour-1'],
        spans: [PageSpan(text: 'Premier jour du Ramadhan')],
      ),
    ],
  ),
  _shab: _page(
    'Namaz-e-Shab',
    links: [('Sourate al-Fâtihah (1)', 'page:$_fatihah')],
  ),
});

List<DevotionalText> _items() => [
  _text(
    id: _safar,
    kind: DevotionalKind.aamal,
    title: 'Aamal du mois de Safar',
    page: true,
  ),
  _text(
    id: _rajab,
    kind: DevotionalKind.aamal,
    title: 'Aamal du mois de Rajab',
    page: true,
  ),
  _text(
    id: _ramadhan,
    kind: DevotionalKind.aamal,
    title: 'Aamal du mois de Ramadhan',
    page: true,
  ),
  _text(
    id: _ramadhanNamaz,
    kind: DevotionalKind.namaz,
    title: 'Namaz du 1 au 30 Ramadhan',
    page: true,
  ),
  for (var i = 0; i < 8; i++)
    _text(
      id: 'mois-$i',
      kind: DevotionalKind.aamal,
      title: 'Aamal du mois de Moharram $i',
    ),
  _text(
    id: _safarDua,
    kind: DevotionalKind.dua,
    title: 'Doua du mois de Safar',
    arabic: 'يَا',
    translation: 'Invocation de Safar',
  ),
  _text(
    id: _arbaeen,
    kind: DevotionalKind.ziyarat,
    title: 'Zyaarat-e-Arbae\'en',
    arabic: 'اَلسَّلَامُ',
  ),
  _text(
    id: _rajabDua,
    kind: DevotionalKind.dua,
    title: 'Doua du mois de Rajab',
    arabic: 'اَللّٰهُمَّ',
  ),
  _text(
    id: _fatihah,
    kind: DevotionalKind.quran,
    title: 'Sourate al-Fâtihah (1)',
    arabic: 'بِسْمِ',
    translation: 'Au nom d’Allàh.',
  ),
  _text(
    id: 'ikhlas',
    kind: DevotionalKind.quran,
    title: 'Sourate al-Ikhlâç (112)',
    arabic: 'قُلْ',
    translation: 'Dis : Il est Allàh.',
  ),
  _text(
    id: _shab,
    kind: DevotionalKind.namaz,
    title: 'Namaz-e-Shab',
    page: true,
  ),
  _text(
    id: 'ghofaylah',
    kind: DevotionalKind.namaz,
    title: 'Namaz-e-Ghofaylah',
  ),
];

void main() {
  test('un lien de page mène à la lecture, à la page seule ou nulle part', () {
    final services = Services(
      store: AppStore(NativeDatabase.memory()),
      devotionalCatalog: LocalDevotionalCatalog(_items()),
      originalPages: _pages,
    );
    addTearDown(services.store.close);
    // Texte dont la page est l’onglet Arabe, avec son repère.
    expect(locatePage(services, _ramadhanNamaz, 'x y'), '/text/$_ramadhanNamaz?anchor=x+y');
    // Sourate mise à jour : sa lecture native.
    expect(locatePage(services, _fatihah, null), '/text/$_fatihah');
    // Page d’origine hors catalogue.
    expect(locatePage(services, _ramadhanDays, 'jour-1'), '/page/$_ramadhanDays?anchor=jour-1');
    // Doua sans page d’origine : sa lecture, sans repère.
    expect(locatePage(services, _safarDua, 'TRADUCTION'), '/text/$_safarDua');
    expect(locatePage(services, '00000000-0000-4000-8000-000000000000', null), isNull);
  });

  testWidgets('Aamal Mensuel → Safar → Doua, la flèche descend d’un niveau', (
    tester,
  ) async {
    await _pumpCatalog(tester);
    await _openSafar(tester);
    await _tapText(tester, 'Doua du mois de Safar');
    expect(_title('Doua du mois de Safar'), findsOneWidget);

    await tester.tap(find.byTooltip('Retour').hitTestable());
    await _settle(tester);
    expect(_title('Aamal du mois de Safar'), findsOneWidget);
    expect(find.text('Zyaarat-e-Arbae\'en'), findsOneWidget);

    await tester.tap(find.byTooltip('Retour').hitTestable());
    await _settle(tester);
    expect(find.byType(OriginalPageView), findsNothing);
    expect(find.text('Aamal du mois de Moharram 0'), findsOneWidget);
  });

  testWidgets(
    'Zyaarat-e-Arbae\'en puis Rajab : le retour système descend d’un niveau',
    (tester) async {
      await _pumpCatalog(tester);
      await _openSafar(tester);
      await _tapText(tester, 'Zyaarat-e-Arbae\'en');
      expect(_title('Zyaarat-e-Arbae\'en'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(_title('Aamal du mois de Safar'), findsOneWidget);
      expect(find.text('Doua du mois de Safar'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.text('Aamal du mois de Rajab'), findsOneWidget);
      await _tapText(tester, 'Aamal du mois de Rajab');
      await _tapText(tester, 'Doua du mois de Rajab');
      expect(_title('Doua du mois de Rajab'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(_title('Aamal du mois de Rajab'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.text('Aamal Mensuel'), findsWidgets);
      expect(find.byType(OriginalPageView), findsNothing);
    },
  );

  testWidgets(
    'Ramadhan → namaz sur iOS : chaque page est un écran, le retour les défait',
    (tester) async {
      await _pumpCatalog(tester, platform: TargetPlatform.iOS);
      await _tapText(tester, 'Aamal Mensuel');
      await _tapText(tester, 'Aamal du mois de Ramadhan');
      await _tapText(tester, 'Namaz du 1 au 30 Ramadhan');
      expect(_title('Namaz du 1 au 30 Ramadhan'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(_title('Aamal du mois de Ramadhan'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.text('Aamal du mois de Ramadhan'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.text('Doua'), findsOneWidget);
      final stayed = await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(stayed, isFalse);
      expect(find.text('Aamal Mensuel'), findsOneWidget);
    },
  );

  testWidgets('une ancre de la page fait défiler jusqu’au repère', (
    tester,
  ) async {
    await _pumpCatalog(tester);
    await _tapText(tester, 'Aamal Mensuel');
    await _tapText(tester, 'Aamal du mois de Ramadhan');
    await _tapText(tester, 'Namaz du 1 au 30 Ramadhan');
    expect(find.text('Fin de la page'), findsNothing);
    await tester.tap(find.text('Plus bas'));
    await tester.pumpAndSettle();
    expect(find.text('Fin de la page'), findsOneWidget);
  });

  testWidgets('un lien vers une autre page ouvre son écran, à son repère', (
    tester,
  ) async {
    await _pumpCatalog(tester);
    await _tapText(tester, 'Aamal Mensuel');
    await _tapText(tester, 'Aamal du mois de Ramadhan');
    await _tapText(tester, 'Namaz du 1 au 30 Ramadhan');
    await tester.tap(find.text('1er jour'));
    await tester.pumpAndSettle();
    expect(find.byType(OriginalPageScreen), findsOneWidget);
    expect(_title('Les jours du Ramadhan'), findsOneWidget);
    expect(find.text('Premier jour du Ramadhan'), findsOneWidget);
    await tester.tap(find.byTooltip('Retour').hitTestable());
    await _settle(tester);
    expect(_title('Namaz du 1 au 30 Ramadhan'), findsOneWidget);
  });

  testWidgets('Retour au sommaire de la page ouvre le sommaire de l’application', (
    tester,
  ) async {
    await _pumpCatalog(tester);
    await _openSafar(tester);
    await tester.tap(find.text('Retour au sommaire'));
    await _settle(tester);
    expect(find.byType(OriginalPageView), findsNothing);
    expect(find.text('Aamal Mensuel'), findsOneWidget);
    expect(find.text('Doua'), findsOneWidget);
    final stayed = await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(stayed, isFalse);
    expect(find.text('Aamal Mensuel'), findsOneWidget);
    expect(find.text('Aamal du mois de Safar'), findsNothing);

    await _openSafar(tester);
    // Le menu ⋮ s’ouvre et se ferme avec une animation d’environ 300 ms.
    await tester.tap(find.byKey(const Key('reader-menu')).hitTestable());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Sommaire').hitTestable());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Zyaarate'), findsOneWidget);
    expect(find.byType(OriginalPageView), findsNothing);
    expect(find.byTooltip('Lire'), findsNothing);
  });

  testWidgets('la liste du mois garde son défilement au retour', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpCatalog(tester);
    await _tapText(tester, 'Aamal Mensuel');
    final scrollable = find.descendant(
      of: find.byType(SectionScreen),
      matching: find.byType(Scrollable),
    );
    final position = tester
        .stateList<ScrollableState>(scrollable)
        .map((state) => state.position)
        .reduce(
          (best, next) =>
              next.maxScrollExtent > best.maxScrollExtent ? next : best,
        );
    expect(position.maxScrollExtent, greaterThan(40));
    position.jumpTo(40);
    await tester.pump();
    final safar = find.text('Aamal du mois de Safar');
    await tester.ensureVisible(safar.first);
    await tester.pump();
    final remembered = position.pixels;
    await tester.tap(safar.hitTestable());
    await _settle(tester);
    await tester.tap(find.byTooltip('Retour').hitTestable());
    await _settle(tester);
    expect(position.pixels, remembered);
  });

  testWidgets(
    'Qur\'an, recherche et favoris : le retour revient à l’écran d’origine',
    (tester) async {
      final store = AppStore(NativeDatabase.memory());
      await DevotionalFavorites(store).toggle(_safarDua);
      final router = await _pumpCatalog(tester, store: store);

      await tester.tap(find.text('Qur\'an'));
      await _settle(tester);
      await tester.tap(find.text('Sourate al-Fâtihah (1)'));
      await _settle(tester);
      expect(find.byTooltip('Retour'), findsOneWidget);
      await tester.tap(find.byTooltip('Retour').hitTestable());
      await _settle(tester);
      expect(find.text('Sourate al-Ikhlâç (112)'), findsOneWidget);
      await tester.tap(find.text('Retour au sommaire'));
      await _settle(tester);

      await tester.enterText(find.byKey(const Key('site-search')), 'Safar');
      await _settle(tester);
      await tester.tap(find.text('Doua du mois de Safar'));
      await _settle(tester);
      expect(find.text('يَا'), findsOneWidget);
      await tester.tap(find.byTooltip('Retour').hitTestable());
      await _settle(tester);
      expect(find.text('Safar'), findsWidgets);
      expect(find.text('Doua du mois de Safar'), findsOneWidget);

      router.go('/favoris');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Favoris'), findsWidgets);
      await tester.tap(find.text('Doua du mois de Safar'));
      await _settle(tester);
      await tester.tap(find.byTooltip('Retour').hitTestable());
      await _settle(tester);
      expect(find.text('Favoris'), findsWidgets);
      expect(find.text('Doua du mois de Safar'), findsOneWidget);
    },
  );

  testWidgets('Namaz → sourate pousse une route, le retour revient au namaz', (
    tester,
  ) async {
    await _pumpCatalog(tester);
    await tester.tap(find.text('Namaz'));
    await _settle(tester);
    await tester.tap(find.text('Namaz-e-Shab'));
    await _settle(tester);
    await tester.tap(find.text('Sourate al-Fâtihah (1)'));
    await _settle(tester);
    expect(find.text('بِسْمِ'), findsOneWidget);
    await tester.tap(find.byTooltip('Retour').hitTestable());
    await _settle(tester);
    expect(find.byType(OriginalPageView), findsOneWidget);
    expect(_title('Namaz-e-Shab'), findsOneWidget);
    await tester.tap(find.byTooltip('Retour').hitTestable());
    await _settle(tester);
    expect(find.text('Namaz-e-Ghofaylah'), findsOneWidget);
  });
}

/// Le titre affiché dans l’en-tête vert de l’écran visible.
Finder _title(String text) => find.descendant(
  of: find.byType(SiteReaderHeader),
  matching: find.text(text),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  // La transition de page finit avant la vérification suivante.
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder.first);
  await tester.pump();
  await tester.tap(finder.hitTestable().first);
  await _settle(tester);
}

Future<GoRouter> _pumpCatalog(
  WidgetTester tester, {
  AppStore? store,
  TargetPlatform? platform,
}) async {
  final memory = store ?? AppStore(NativeDatabase.memory());
  addTearDown(memory.close);
  final catalog = LocalDevotionalCatalog(_items());
  final router = _catalogRouter(catalog, memory);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ServicesScope(
      services: Services(
        store: memory,
        devotionalCatalog: catalog,
        originalPages: _pages,
      ),
      child: MaterialApp.router(
        theme: platform == null ? null : ThemeData(platform: platform),
        routerConfig: router,
      ),
    ),
  );
  return router;
}

Future<void> _openSafar(WidgetTester tester) async {
  await _tapText(tester, 'Aamal Mensuel');
  await _tapText(tester, 'Aamal du mois de Safar');
  expect(find.byType(OriginalPageView), findsOneWidget);
}

GoRouter _catalogRouter(LocalDevotionalCatalog catalog, AppStore store) {
  return GoRouter(
    initialLocation: '/sommaire',
    routes: [
      GoRoute(
        path: '/sommaire',
        builder: (context, state) => SommaireScreen(catalog: catalog),
      ),
      GoRoute(
        path: '/section/:id',
        builder: (context, state) {
          final section = CatalogSection.byId(
            state.pathParameters['id'] ?? '',
          )!;
          return SectionScreen(section: section, catalog: catalog);
        },
      ),
      GoRoute(
        path: '/text/:id',
        builder: (context, state) => CatalogTextPage(
          id: state.pathParameters['id'] ?? '',
          anchor: state.uri.queryParameters['anchor'],
        ),
      ),
      GoRoute(
        path: '/page/:id',
        builder: (context, state) => OriginalPageScreen(
          id: state.pathParameters['id'] ?? '',
          anchor: state.uri.queryParameters['anchor'],
        ),
      ),
      GoRoute(
        path: '/favoris',
        builder: (context, state) =>
            FavoritesScreen(catalog: catalog, store: store),
      ),
    ],
  );
}
