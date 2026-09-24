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
    expect(spelled.search('dua'), [dua, kumayl]);
    expect(spelled.search('doua'), [dua, kumayl]);
    expect(spelled.search('ashura'), [ashura]);
    expect(spelled.search('achoura'), [ashura]);
    expect(spelled.search('azomal'), [ashura]);
    expect(spelled.search('دعاء'), [dua, ashura]);
    expect(spelled.search('kumail'), [kumayl]);
  });

  test('le filtre de catégorie isole ziyārāt et duʿā', () {
    expect(catalog.search('', kind: DevotionalKind.ziyarat), [ziyarat]);
    expect(catalog.search('ziy', kind: DevotionalKind.dua), isEmpty);
  });
}
