import 'package:flutter_test/flutter_test.dart';
import 'package:perles_divines/features/duas/catalog.dart';
import 'package:perles_divines/features/duas/dua.dart';
import 'package:perles_divines/features/ziyarat/catalog.dart';

void main() {
  const dua = DevotionalText(
    id: 'dua-1',
    kind: DevotionalKind.dua,
    title: 'Invocation du matin',
    arabic: 'دعاء',
    translation: 'Texte traduit',
    transliteration: 'Du’a',
    references: ['Référence vérifiée'],
    audioIds: ['audio-1'],
  );
  const ziyarat = DevotionalText(
    id: 'ziyarat-1',
    kind: DevotionalKind.ziyarat,
    title: 'Ziyārat',
    arabic: 'زيارة',
    translation: '',
    transliteration: 'Ziyarat',
    references: [],
    audioIds: [],
  );
  const catalog = LocalDevotionalCatalog([dua, ziyarat]);

  test('le catalogue sépare les duʿā et ziyārāt', () {
    expect(catalog.duas, [dua]);
    expect(catalog.ziyarat, [ziyarat]);
  });

  test('la recherche couvre arabe, traduction et références', () {
    expect(catalog.search('دعاء'), [dua]);
    expect(catalog.search('texte traduit'), [dua]);
    expect(catalog.search('référence'), [dua]);
    expect(catalog.search('reference verifiee'), [dua]);
  });

  test('la recherche tolère les graphies courantes', () {
    const ashura = DevotionalText(
      id: 'ashura',
      kind: DevotionalKind.ziyarat,
      title: 'Zyaarat-e-Âchourâ',
      arabic: 'دُعَاء',
      translation: '',
      transliteration: "Eelaahi A'Zomal",
      references: [],
      audioIds: [],
    );
    const kumayl = DevotionalText(
      id: 'kumayl',
      kind: DevotionalKind.dua,
      title: 'Doua-e-Kumayl',
      arabic: '',
      translation: '',
      transliteration: '',
      references: [],
      audioIds: [],
    );
    const spelled = LocalDevotionalCatalog([dua, ashura, kumayl]);
    expect(spelled.search('dua'), [kumayl]);
    expect(spelled.search('doua'), [kumayl]);
    expect(spelled.search('ashura'), [ashura]);
    expect(spelled.search('achoura'), [ashura]);
    expect(spelled.search('azomal'), [ashura]);
    expect(spelled.search('دعاء'), [dua, ashura]);
    expect(spelled.search('kumail'), [kumayl]);
  });

  test('une saisie courte ne balaie pas le corps du texte', () {
    final buried = DevotionalText(
      id: 'buried',
      kind: DevotionalKind.dua,
      title: 'Titre',
      arabic: '',
      translation: 'alphabet ${'paragraphe ' * 2000}',
      transliteration: '',
      references: [],
      audioIds: [],
    );
    final wide = LocalDevotionalCatalog([buried]);
    expect(wide.search('a'), isEmpty);
    expect(wide.search('ti'), [buried]);
    final watch = Stopwatch()..start();
    expect(wide.search('alphabet'), [buried]);
    expect(wide.search('zzzz'), isEmpty);
    watch.stop();
    expect(watch.elapsedMilliseconds, lessThan(400));
  });

  test('chaque recherche vise le titre demandé, pas un mot voisin', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final catalog = await LocalDevotionalCatalog.load();
    List<String> titles(String query) =>
        catalog.search(query).map((item) => item.title).toList();

    expect(titles('yassin'), ['Sourate Yâ-Sîn (36)']);
    expect(titles('ya sin'), ['Sourate Yâ-Sîn (36)']);
    expect(titles('yaseen'), ['Sourate Yâ-Sîn (36)']);
    expect(titles('yassine'), ['Sourate Yâ-Sîn (36)']);
    expect(titles('fatiha'), ['Sourate al-Fâtihah (1)']);
    expect(titles('alfatiha'), ['Sourate al-Fâtihah (1)']);
    expect(titles('ikhlas'), ['Sourate al-Ikhlâç (112)']);
    expect(titles('qadr'), ['Sourate al-Qadr (97)']);
    expect(titles('annas'), ['Sourate an-Nâs (114)']);
    expect(titles('kumail'), ['Doua-e-Kumayl']);
    expect(titles('achoura'), contains('Zyaarat-e-Âchourâ'));
    expect(titles('achoura'), isNot(contains('Sourate Yâ-Sîn (36)')));

    final hassan = titles('hassan');
    expect(hassan, isNot(contains('Sourate Yâ-Sîn (36)')));
    expect(
      hassan.every((title) => title.toLowerCase().contains('hassan')),
      isTrue,
    );
  });

  test('le filtre de catégorie isole ziyārāt et duʿā', () {
    expect(catalog.search('', kind: DevotionalKind.ziyarat), [ziyarat]);
    expect(catalog.search('ziy', kind: DevotionalKind.dua), isEmpty);
  });
}
