import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perles_divines/core/store.dart';
import 'package:perles_divines/features/downloads/download_controller.dart';

void main() {
  test(
    'Une interruption de transaction conserve les données personnelles',
    () async {
      final store = AppStore(NativeDatabase.memory());
      await store.writeState('favorites', ['piste-1']);
      await expectLater(
        store.transaction(() async {
          await store.writeState('favorites', []);
          throw StateError('coupure simulée');
        }),
        throwsStateError,
      );
      expect(await store.readState('favorites'), ['piste-1']);
      await store.close();
    },
  );
  test(
    'Favoris et position survivent à la fermeture réelle de SQLite',
    () async {
      final directory = await Directory.systemTemp.createTemp('perles-test-');
      final file = File('${directory.path}/local.sqlite');
      final first = AppStore(NativeDatabase(file));
      await first.writeState('position:piste-1', {
        'ms': 12345,
        'completed': false,
      });
      await first.writeState('favorites', ['piste-1']);
      await first.close();
      final second = AppStore(NativeDatabase(file));
      expect((await second.readState('position:piste-1'))['ms'], 12345);
      expect(await second.readState('favorites'), ['piste-1']);
      await second.close();
      await directory.delete(recursive: true);
    },
  );
  test('Un média incomplet ou corrompu est refusé avant export', () async {
    final directory = await Directory.systemTemp.createTemp(
      'perles-integrity-',
    );
    final file = File('${directory.path}/test.mp3');
    final bytes = List.generate(10000, (i) => i % 256);
    final hash = sha256.convert(bytes).toString();
    await file.writeAsBytes(bytes);
    expect(await verifyMedia(file.path, bytes.length, hash), true);
    expect(await verifyMedia(file.path, bytes.length + 1, hash), false);
    expect(await verifyMedia(file.path, bytes.length, '0' * 64), false);
    await file.writeAsBytes(bytes.sublist(0, 9000));
    expect(await verifyMedia(file.path, bytes.length, hash), false);
    await directory.delete(recursive: true);
  });
}
