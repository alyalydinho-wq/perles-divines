import '../duas/catalog.dart';
import '../duas/dua.dart';

extension ZiyaratCatalog on LocalDevotionalCatalog {
  List<DevotionalText> get ziyarat =>
      items.where((item) => item.kind == DevotionalKind.ziyarat).toList();
}
