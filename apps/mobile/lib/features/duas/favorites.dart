import 'package:flutter/foundation.dart';

import '../../core/store.dart';

class DevotionalFavorites extends _StoredIds {
  DevotionalFavorites._(AppStore store) : super(store, 'devotionalFavorites');

  factory DevotionalFavorites(AppStore store) =>
      _texts[store] ??= DevotionalFavorites._(store);

  static final _texts = Expando<DevotionalFavorites>();
}

class AudioFavorites extends _StoredIds {
  AudioFavorites._(AppStore store) : super(store, 'audioFavorites');

  factory AudioFavorites(AppStore store) =>
      _audios[store] ??= AudioFavorites._(store);

  static final _audios = Expando<AudioFavorites>();
}

class _StoredIds extends ChangeNotifier {
  _StoredIds(this.store, this.key);

  final AppStore store;
  final String key;
  Set<String> ids = {};
  bool loaded = false;
  Future<void> _gate = Future.value();

  Future<Set<String>> read() => _serialized(_load);

  Future<Set<String>> toggle(String id) => _serialized(() async {
    if (!loaded) await _load();
    final values = Set<String>.from(ids);
    if (!values.add(id)) values.remove(id);
    ids = values;
    loaded = true;
    await store.writeState(key, values.toList()..sort());
    notifyListeners();
    return values;
  });

  Future<Set<String>> _load() async {
    final next = Set<String>.from(
      await store.readState(key) ?? const <String>[],
    );
    final changed =
        !loaded || next.length != ids.length || !ids.containsAll(next);
    ids = next;
    loaded = true;
    if (changed) notifyListeners();
    return ids;
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final run = _gate.then((_) => action());
    _gate = run.then((_) {}, onError: (Object _, StackTrace _) {});
    return run;
  }
}
