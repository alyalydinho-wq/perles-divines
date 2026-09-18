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
}
