import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perles_divines/features/downloads/download_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('perles_divines/test-storage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('un canal natif absent donne un espace inconnu, sans erreur', () async {
    expect(await DownloadController.readFreeBytes(channel), isNull);
  });

  test('le canal natif donne l’espace libre', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => 1234);
    expect(await DownloadController.readFreeBytes(channel), 1234);
  });
}
