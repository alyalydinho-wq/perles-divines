import 'package:flutter_test/flutter_test.dart';
import 'package:perles_divines/core/track.dart';

void main() {
  test('Une lecture terminée ou une position invalide repart à zéro', () {
    expect(restoredPosition(1234, 20000), const Duration(milliseconds: 1234));
    expect(restoredPosition(20000, 20000), Duration.zero);
    expect(restoredPosition(100, 20000, completed: true), Duration.zero);
    expect(restoredPosition(-1, 20000), Duration.zero);
  });
  test('Une piste arrêtée juste avant la durée du catalogue repart à zéro', () {
    // Naad-e-Ali (Kabeer) : le lecteur s’était arrêté à 401 589 ms pour
    // 401 612 ms au catalogue, et la reprise s’arrêtait aussitôt.
    expect(restoredPosition(401589, 401612), Duration.zero);
    expect(restoredPosition(399700, 401612), Duration.zero);
    expect(
      restoredPosition(399000, 401612),
      const Duration(milliseconds: 399000),
    );
  });
  test('Le cache local reprend l’extension publiée', () {
    const track = Track(
      id: 'a',
      title: 'Ahad',
      version: 1,
      durationMs: 1000,
      sizeBytes: 10,
      sha256: 'abc',
      file: 'audio/doua-e-ahad.m4a',
    );
    expect(cachedMediaName(track), 'a-v1-abc.m4a');
  });
  test('Nom exportable sans traversée de répertoire ni recompression', () {
    expect(exportName('../Nom: édition?'), '.._Nom_ édition_.mp3');
    expect(exportName(''), 'audio.mp3');
    expect(exportName('a' * 200).length, 124);
  });
}
