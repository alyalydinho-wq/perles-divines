import '../../core/store.dart';

class DevotionalFavorites {
  DevotionalFavorites(this.store);
  final AppStore store;
  static const _key = 'devotionalFavorites';

  Future<Set<String>> read() async =>
      Set<String>.from(await store.readState(_key) ?? const <String>[]);

  Future<Set<String>> toggle(String id) async {
    final values = await read();
    if (!values.add(id)) values.remove(id);
    await store.writeState(_key, values.toList()..sort());
    return values;
  }
}
