import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:perles_divines/core/store.dart';
import 'package:perles_divines/features/catalog/favorites_screen.dart';
import 'package:perles_divines/features/catalog/section_screen.dart';
import 'package:perles_divines/features/catalog/sections.dart';
import 'package:perles_divines/features/catalog/text_screen.dart';
import 'package:perles_divines/features/duas/catalog.dart';
import 'package:perles_divines/features/duas/dua.dart';
import 'package:perles_divines/features/duas/favorites.dart';
import 'package:perles_divines/features/reader/content_install.dart';
import 'package:perles_divines/features/reader/page_history.dart';
import 'package:perles_divines/features/reader/reader_screen.dart';
import 'package:perles_divines/features/sommaire/sommaire_screen.dart';
import 'package:perles_divines/ui/site.dart';

String _url(String id) => 'file:///C:/edition/pages/$id.html';

const _safar = '50ebee15-3228-5bd9-944b-a1d847c06e5a';
const _safarDua = 'c97581bf-b0ab-5a0b-8c74-0c4813dce712';
const _arbaeen = '2991d127-9b1a-525f-bcc2-5b07b5626bcc';
const _rajab = 'a5becaaa-d8e4-50f3-b7c5-cdd00e31b232';
const _rajabDua = '7dc1b848-72f1-5d99-a96c-d09843597b5e';
const _ramadhan = 'a21cb585-f002-5c39-baff-38928673c3ac';
const _ramadhanNamaz = '02d64c56-4c53-553b-ae94-b12852a5473f';
const _sommaireHtml = '1af50233-0b26-5c4b-993e-c96c078fdb46';
const _logo = '386bba3e-88c0-5136-bd4e-8215613a7064';
const _fatihah = '7918100a-56f9-5035-b4b0-46e1e2c53b32';

DevotionalText _text({
  required String id,
  required DevotionalKind kind,
  required String title,
  String arabic = '',
  String translation = '',
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
  );
}

/// Même contrat que ReaderScreen : une page finie entre dans la pile,
/// le retour natif ou le rechargement retire exactement la dernière.
String? _backOne(LocalPageHistory history) {
  final target = history.beginBack();
  if (target == null) return null;
  history.noteFinished(target);
  return history.current;
}

void main() {
  test('Aamal : mois puis doua ou ziyarat, un retour retire une page', () {
    final steps = <(String, String)>[
      (_safar, _safarDua),
      (_safar, _arbaeen),
      (_rajab, _rajabDua),
      (
        '20ad67f1-817f-58b6-9b17-33bd0cd07923',
        '13f8d881-0000-4000-8000-000000000001',
      ),
      (
        '94875b15-8146-553c-ba51-7fb3be31cb97',
        '489f9452-0000-4000-8000-000000000002',
      ),
      (_ramadhan, _ramadhanNamaz),
      (
        'f97e71a5-4991-54c1-867b-051547500ae4',
        '2f0346f6-e430-588c-9491-bb7933f4a494',
      ),
    ];
    for (final (month, child) in steps) {
      final history = LocalPageHistory()
        ..noteFinished(_url(month))
        ..noteFinished(_url(child));
      expect(history.canGoBack, isTrue, reason: month);
      expect(_backOne(history), _url(month));
      expect(history.canGoBack, isFalse, reason: month);
      expect(history.beginBack(), isNull, reason: month);
    }
  });

  test('le WebView vide ne devient pas une page, l’ancre non plus', () {
    final history = LocalPageHistory()..noteFinished(_url(_safar));
    expect(history.noteFinished('about:blank'), HistoryArrival.ignored);
    expect(history.urls, hasLength(1));

    history.noteFinished(_url(_safarDua));
    history.noteFinished('${_url(_safarDua)}#TRANSLITTERATION');
    expect(history.urls, hasLength(2));

    history.beginBack();
    expect(history.noteFinished('about:blank'), HistoryArrival.reloadPrevious);
    expect(
      LocalPageHistory.identity(history.previous!),
      LocalPageHistory.identity(_url(_safar)),
    );
    history.noteFinished(_url(_safar));
    expect(history.canGoBack, isFalse);
    expect(LocalPageHistory.fileOf(_url(_safar)), isNotNull);
  });

  test('une sourate mise à jour ouvre une route, pas une page du WebView', () {
    const surah = DevotionalText(
      id: _fatihah,
      kind: DevotionalKind.quran,
      title: 'Sourate al-Fâtihah (1)',
      arabic: 'بِسْمِ',
      translation: '',
      transliteration: '',
      references: [],
      audioIds: [],
    );
    expect(surah.opensUpdatedReading, isTrue);
    expect(
      decideReaderNavigation(
        Uri.parse(_url(_fatihah)),
        editionDirectory: r'C:\edition',
        opensUpdatedText: (id) => id == _fatihah,
      ),
      ReaderNavigation.openUpdatedText,
    );
    expect(
      decideReaderNavigation(
        Uri.parse(_url(_logo)),
        editionDirectory: r'C:\edition',
      ),
      ReaderNavigation.openAppSommaire,
    );
    final history = LocalPageHistory()..noteFinished(_url(_ramadhanNamaz));
    expect(history.canGoBack, isFalse);
  });

  test('isLegacySommaireUrl reconnaît sommaire et accueil, pas les autres pages', () {
    const legacy = [
      'file:///C:/edition/pages/1af50233-0b26-5c4b-993e-c96c078fdb46.html',
      'file:///C:/edition/pages/1af50233-0b26-5c4b-993e-c96c078fdb46.html#haut',
      'file:///C:/edition/pages/1af50233-0b26-5c4b-993e-c96c078fdb46.html?x=1',
      'file:///data/user/0/app/pages/386bba3e-88c0-5136-bd4e-8215613a7064.html',
      'file:///C:/edition/sommaire.html',
      'file:///C:/edition/index.html#accueil',
      'sommaire.html',
      'pages/386bba3e-88c0-5136-bd4e-8215613a7064.html',
      'https://www.perlesdivines.fr/sommaire.html',
      'https://www.perlesdivines.fr/sommaire.html#liste',
      'https://perlesdivines.fr/index.html?ref=1',
      'http://www.perlesdivines.fr/',
      'https://perlesdivines.fr',
      'https://www.perlesdivines.fr/fr/',
      'https://WWW.perlesdivines.fr/fr/index.html',
      'https://www.perlesdivines.fr/fr/sommaire.html',
    ];
    for (final url in legacy) {
      expect(isLegacySommaireUrl(Uri.parse(url)), isTrue, reason: url);
    }
    const kept = [
      'file:///C:/edition/pages/50ebee15-3228-5bd9-944b-a1d847c06e5a.html',
      'file:///C:/edition/pages/c97581bf-b0ab-5a0b-8c74-0c4813dce712.html#TRADUCTION',
      'https://www.perlesdivines.fr/fr/aamal_safar.html',
      'https://www.perlesdivines.fr/aamal_safar.html',
      'https://example.com/sommaire.html',
      'https://example.com/',
      'mailto:contact@perlesdivines.fr',
    ];
    for (final url in kept) {
      expect(isLegacySommaireUrl(Uri.parse(url)), isFalse, reason: url);
    }
  });

  test(
    'la décision de navigation distingue sommaire, page et lien externe',
    () {
      const edition = r'C:\edition';
      ReaderNavigation go(String url) => decideReaderNavigation(
        Uri.parse(url),
        editionDirectory: edition,
        opensUpdatedText: (id) => id == _fatihah,
      );

      expect(go(_url(_sommaireHtml)), ReaderNavigation.openAppSommaire);
      expect(
        go('https://www.perlesdivines.fr/index.html#haut'),
        ReaderNavigation.openAppSommaire,
      );
      expect(go(_url(_safarDua)), ReaderNavigation.showPage);
      expect(go(_url(_fatihah)), ReaderNavigation.openUpdatedText);
      expect(
        go('https://www.perlesdivines.fr/fr/doua.html'),
        ReaderNavigation.external,
      );
      expect(go('mailto:a@b.c'), ReaderNavigation.external);
      expect(
        go('file:///C:/ailleurs/pages/$_safarDua.html'),
        ReaderNavigation.blocked,
      );

      final history = LocalPageHistory()
        ..noteFinished(_url(_safar))
        ..noteFinished(_url(_safarDua));
      history.clear();
      expect(history.canGoBack, isFalse);
      expect(history.beginBack(), isNull);
    },
  );

  test('une page ouverte depuis la recherche n’a pas l’historique du mois', () {
    final history = LocalPageHistory()..noteFinished(_url(_safarDua));
    expect(history.canGoBack, isFalse);
    expect(history.beginBack(), isNull);
  });

  testWidgets('Aamal Mensuel → Safar → Doua, la flèche descend d’un niveau', (
    tester,
  ) async {
    await _pumpCatalog(tester);
    await _openSafar(tester);
    await _tapText(tester, 'Doua du mois de Safar');
    expect(_heading(tester), 'Doua du mois de Safar');

    await tester.tap(find.byTooltip('Retour').hitTestable());
    await _settle(tester);
    expect(find.byKey(const Key('reading-body')), findsOneWidget);
    expect(_heading(tester), 'Aamal du mois de Safar');
    expect(_bodyText('Zyaarat-e-Arbae\'en'), findsOneWidget);

    await tester.tap(find.byTooltip('Retour').hitTestable());
    await _settle(tester);
    expect(find.byKey(const Key('reading-body')), findsNothing);
    expect(find.text('Aamal du mois de Moharram 0'), findsOneWidget);
  });

  testWidgets(
    'Zyaarat-e-Arbae\'en puis Rajab : le retour système descend d’un niveau',
    (tester) async {
      await _pumpCatalog(tester);
      await _openSafar(tester);
      await _tapText(tester, 'Zyaarat-e-Arbae\'en');
      expect(_heading(tester), 'Zyaarat-e-Arbae\'en');

      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(_heading(tester), 'Aamal du mois de Safar');
      expect(_bodyText('Doua du mois de Safar'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.text('Aamal du mois de Rajab'), findsOneWidget);
      await _tapText(tester, 'Aamal du mois de Rajab');
      await _tapText(tester, 'Doua du mois de Rajab');
      expect(_heading(tester), 'Doua du mois de Rajab');
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(_heading(tester), 'Aamal du mois de Rajab');
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.text('Aamal Mensuel'), findsWidgets);
      expect(find.byKey(const Key('reading-body')), findsNothing);
    },
  );

  testWidgets(
    'Ramadhan → namaz, puis le geste iOS, sans quitter l’application',
    (tester) async {
      await _pumpCatalog(tester, platform: TargetPlatform.iOS);
      await _tapText(tester, 'Aamal Mensuel');
      await _tapText(tester, 'Aamal du mois de Ramadhan');
      await _tapText(tester, 'Namaz du 1 au 30 Ramadhan');
      expect(find.byKey(const Key('reading-back-edge')), findsOneWidget);

      await tester.fling(
        find.byKey(const Key('reading-back-edge')),
        const Offset(160, 0),
        800,
      );
      await _settle(tester);
      expect(_heading(tester), 'Aamal du mois de Ramadhan');

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

  testWidgets('Retour au sommaire HTML ouvre le sommaire de l’application', (
    tester,
  ) async {
    await _pumpCatalog(tester);
    await _openSafar(tester);
    await _tapText(tester, 'Doua du mois de Safar');
    await tester.tap(find.byTooltip('Retour').hitTestable());
    await _settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('reading-body')),
        matching: find.text('Retour au sommaire'),
      ),
    );
    await _settle(tester);
    expect(find.byKey(const Key('reading-body')), findsNothing);
    expect(find.text('Aamal Mensuel'), findsOneWidget);
    expect(find.text('Doua'), findsOneWidget);
    final stayed = await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(stayed, isFalse);
    expect(find.text('Aamal Mensuel'), findsOneWidget);
    expect(find.text('Aamal du mois de Safar'), findsNothing);

    await _openSafar(tester);
    await tester.tap(find.byTooltip('Sommaire').hitTestable());
    await _settle(tester);
    expect(find.text('Zyaraate'), findsOneWidget);
    expect(find.byKey(const Key('reading-body')), findsNothing);
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
    expect(find.byKey(const Key('reading-body')), findsOneWidget);
    expect(_bodyText('Namaz-e-Shab'), findsOneWidget);
    await tester.tap(find.byTooltip('Retour').hitTestable());
    await _settle(tester);
    expect(find.text('Namaz-e-Ghofaylah'), findsOneWidget);
  });
}

Finder _bodyText(String text) => find.descendant(
  of: find.byKey(const Key('reading-body')),
  matching: find.text(text),
);

String _heading(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('page-heading'))).data!;

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder.first);
  await tester.pump();
  await tester.tap(finder.hitTestable());
  await _settle(tester);
}

Future<GoRouter> _pumpCatalog(
  WidgetTester tester, {
  AppStore? store,
  TargetPlatform? platform,
}) async {
  final memory = store ?? AppStore(NativeDatabase.memory());
  addTearDown(memory.close);
  final router = _catalogRouter(memory);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: platform == null ? null : ThemeData(platform: platform),
      routerConfig: router,
    ),
  );
  return router;
}

Future<void> _openSafar(WidgetTester tester) async {
  await _tapText(tester, 'Aamal Mensuel');
  await _tapText(tester, 'Aamal du mois de Safar');
  expect(find.byKey(const Key('reading-body')), findsOneWidget);
}

class _Node {
  const _Node(
    this.id,
    this.title, {
    this.links = const [],
    this.button,
    this.opensRoute = false,
  });

  final String id;
  final String title;
  final String? button;
  final List<_Node> links;
  final bool opensRoute;

  String get buttonLabel => button ?? title;
}

final _safarPage = _Node(
  _safar,
  'Aamal du mois de Safar',
  links: [
    const _Node(_safarDua, 'Doua du mois de Safar'),
    const _Node(_arbaeen, 'Zyaarat-e-Arbae\'en'),
    const _Node(
      _sommaireHtml,
      'Sommaire du site',
      button: 'Retour au sommaire',
    ),
  ],
);

final _rajabPage = _Node(
  _rajab,
  'Aamal du mois de Rajab',
  links: [const _Node(_rajabDua, 'Doua du mois de Rajab')],
);

final _ramadhanPage = _Node(
  _ramadhan,
  'Aamal du mois de Ramadhan',
  links: [const _Node(_ramadhanNamaz, 'Namaz du 1 au 30 Ramadhan')],
);

final _shabPage = _Node(
  '13f8d881-0000-4000-8000-000000000010',
  'Namaz-e-Shab',
  links: [const _Node(_fatihah, 'Sourate al-Fâtihah (1)', opensRoute: true)],
);

_Node? _webRoot(String id) {
  for (final node in [_safarPage, _rajabPage, _ramadhanPage, _shabPage]) {
    if (node.id == id) return node;
  }
  return null;
}

List<DevotionalText> _items() => [
  _text(
    id: _safar,
    kind: DevotionalKind.aamal,
    title: 'Aamal du mois de Safar',
  ),
  _text(
    id: _rajab,
    kind: DevotionalKind.aamal,
    title: 'Aamal du mois de Rajab',
  ),
  _text(
    id: _ramadhan,
    kind: DevotionalKind.aamal,
    title: 'Aamal du mois de Ramadhan',
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
  _text(id: _shabPage.id, kind: DevotionalKind.namaz, title: 'Namaz-e-Shab'),
  _text(
    id: 'ghofaylah',
    kind: DevotionalKind.namaz,
    title: 'Namaz-e-Ghofaylah',
  ),
];

GoRouter _catalogRouter(AppStore store) {
  final catalog = LocalDevotionalCatalog(_items());
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
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          final web = _webRoot(id);
          if (web != null) return _WebReading(root: web);
          final item = catalog.items.firstWhere((entry) => entry.id == id);
          return TextScreen(
            item: item,
            edition: LocalEdition('/tmp', const {'home': 'index.html'}),
            favorite: false,
            onFavorite: () async {},
          );
        },
      ),
      GoRoute(
        path: '/favoris',
        builder: (context, state) =>
            FavoritesScreen(catalog: catalog, store: store),
      ),
    ],
  );
}

class _WebReading extends StatefulWidget {
  const _WebReading({required this.root});
  final _Node root;

  @override
  State<_WebReading> createState() => _WebReadingState();
}

class _WebReadingState extends State<_WebReading> {
  final history = LocalPageHistory();
  late _Node current;
  late final Map<String, _Node> _byUrl;

  @override
  void initState() {
    super.initState();
    _byUrl = {};
    void walk(_Node node) {
      _byUrl[_url(node.id)] = node;
      for (final link in node.links) {
        walk(link);
      }
    }

    walk(widget.root);
    current = widget.root;
    history.noteFinished(_url(current.id));
  }

  void _open(_Node node) {
    final decision = decideReaderNavigation(
      Uri.parse(_url(node.id)),
      editionDirectory: r'C:\edition',
      opensUpdatedText: (id) => node.opensRoute && id == node.id,
    );
    if (decision == ReaderNavigation.openAppSommaire) {
      history.clear();
      GoRouter.of(context).go('/sommaire');
      return;
    }
    if (decision == ReaderNavigation.openUpdatedText) {
      GoRouter.of(context).push('/text/${node.id}');
      return;
    }
    setState(() {
      history.noteFinished(_url(node.id));
      current = node;
    });
  }

  void _pageBack() {
    final target = history.beginBack();
    if (target == null) return;
    final node = _byUrl[target];
    setState(() {
      history.noteFinished(target);
      if (node != null) current = node;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PageBackScope(
      hasPageHistory: history.canGoBack,
      onPageBack: _pageBack,
      child: Scaffold(
        body: Column(
          children: [
            SiteReaderHeader(
              title: widget.root.title,
              onBack: () => Navigator.of(context).maybePop(),
              onHome: () => GoRouter.of(context).go('/sommaire'),
              onScrollToTop: () {},
              onPlay: () {},
              onShare: () {},
            ),
            Expanded(
              child: IosReadingBackEdge(
                enabled: history.canGoBack,
                child: ListView(
                  key: const Key('reading-body'),
                  children: [
                    Text(current.title, key: const Key('page-heading')),
                    for (final link in current.links)
                      TextButton(
                        onPressed: () => _open(link),
                        child: Text(link.buttonLabel),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
