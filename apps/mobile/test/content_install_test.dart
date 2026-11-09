import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:perles_divines/features/reader/content_install.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('perles-edition-');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<File> write(String relative) async {
    final file = File(p.join(root.path, relative));
    await file.parent.create(recursive: true);
    return file.writeAsString('x');
  }

  test('seule l’édition courante reste après une mise à jour', () async {
    final kept = await write('nouvelle/pages/a.html');
    final old = await write('ancienne/assets/b.gif');
    final staging = await write('nouvelle.staging/pages/c.html');

    await LocalEdition.removeOtherEditions(root, 'nouvelle');

    expect(await kept.exists(), isTrue);
    expect(await old.exists(), isFalse);
    expect(await staging.exists(), isFalse);
  });

  test('un dossier absent n’empêche pas le démarrage', () async {
    final missing = Directory(p.join(root.path, 'absent'));
    await LocalEdition.removeOtherEditions(missing, 'nouvelle');
    expect(await missing.exists(), isFalse);
  });
}
