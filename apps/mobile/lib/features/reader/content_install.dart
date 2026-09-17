import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LocalEdition {
  LocalEdition(this.directory, this.manifest);
  final String directory;
  final Map<String, dynamic> manifest;
  String get home => p.join(directory, manifest['home']);
  static Future<LocalEdition> install() async {
    final manifest = jsonDecode(
      await rootBundle.loadString('assets/site/bundle.json'),
    ) as Map<String, dynamic>;
    final support = await getApplicationSupportDirectory();
    final target = Directory(
      p.join(support.path, 'content', manifest['version']),
    );
    if (await File(p.join(target.path, '.complete')).exists()) {
      return LocalEdition(target.path, manifest);
    }
    final staging = Directory('${target.path}.staging');
    await staging.create(recursive: true);
    for (final entry in manifest['files']) {
      final relative = entry['path'] as String;
      if (p.isAbsolute(relative) || relative.split('/').contains('..')) {
        throw const FormatException('Chemin de contenu refusé');
      }
      final bytes = await rootBundle.load('assets/site/$relative');
      final data = bytes.buffer.asUint8List(
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      );
      if (data.length != entry['sizeBytes'] ||
          sha256.convert(data).toString() != entry['sha256']) {
        throw const FormatException('Contenu incomplet ou corrompu');
      }
      final file = File(p.join(staging.path, relative));
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data, flush: true);
    }
    await File(p.join(staging.path, '.complete'))
        .writeAsString(manifest['version'], flush: true);
    await staging.rename(target.path);
    return LocalEdition(target.path, manifest);
  }
}
