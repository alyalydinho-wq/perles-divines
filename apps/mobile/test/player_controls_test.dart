import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perles_divines/features/player/audio_card.dart';

void main() {
  test('la vitesse s’écrit à la française', () {
    expect(playbackSpeeds.map(formatSpeed).toList(), [
      '0,75×',
      '1×',
      '1,25×',
      '1,5×',
      '1,75×',
      '2×',
    ]);
  });

  testWidgets(
    'les commandes tiennent une ligne centrée du lecteur déplié, pas de la barre réduite',
    (tester) async {
      Future<void> show({required bool collapsed}) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: AudioFace(
                title: 'Doua du lundi',
                duration: const Duration(minutes: 5, seconds: 29),
                position: const Duration(seconds: 13),
                dense: true,
                collapsed: collapsed,
                onExpanded: (_) {},
                controls: PlaybackControls(speed: 1, onSpeed: (_) {}),
              ),
            ),
          ),
        ),
      );

      await show(collapsed: true);
      await tester.pumpAndSettle();
      expect(find.byType(PlaybackControls), findsNothing);

      await show(collapsed: false);
      await tester.pumpAndSettle();
      expect(find.byType(PlaybackControls), findsOneWidget);
      final speed = find.byKey(const Key('player-speed'));
      final back = find.byKey(const Key('player-rewind'));
      final ahead = find.byKey(const Key('player-forward'));
      final rows = {
        for (final button in [speed, back, ahead])
          tester.getCenter(button).dy.round(),
      };
      // Les trois commandes sur une seule ligne, sous la barre de lecture.
      expect(rows, hasLength(1));
      expect(
        rows.single,
        greaterThan(tester.getCenter(find.byType(Slider)).dy),
      );
      // Le groupe visible est centré : du bord du bouton de vitesse à la
      // flèche +15 s, autant de marge à gauche qu’à droite. La flèche est à
      // `iconBlank` du bord de son bouton (48 px).
      final width = tester.getSize(find.byType(AudioFace)).width;
      final left = tester.getTopLeft(speed).dx;
      final arrow = tester.getTopRight(ahead).dx - PlaybackControls.iconBlank;
      expect((left - (width - arrow)).abs(), lessThan(1));
      // Ni minuterie, ni précédent / suivant.
      expect(find.byKey(const Key('player-sleep')), findsNothing);
      expect(find.byIcon(Icons.bedtime_outlined), findsNothing);
      expect(find.byIcon(Icons.skip_previous), findsNothing);
      expect(find.byIcon(Icons.skip_next), findsNothing);
    },
  );

  testWidgets('±15 s et vitesse répondent', (tester) async {
    var back = 0, ahead = 0;
    double? speed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PlaybackControls(
              speed: 1.25,
              onSpeed: (value) => speed = value,
              onRewind: () => back++,
              onForward: () => ahead++,
            ),
          ),
        ),
      ),
    );

    expect(find.text('1,25×'), findsOneWidget);
    expect(find.byTooltip('Reculer de 15 s'), findsOneWidget);
    expect(find.byTooltip('Avancer de 15 s'), findsOneWidget);

    await tester.tap(find.byKey(const Key('player-rewind')));
    await tester.tap(find.byKey(const Key('player-forward')));
    await tester.tap(find.byKey(const Key('player-forward')));
    expect((back, ahead), (1, 2));

    await tester.tap(find.byKey(const Key('player-speed')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1,5×').last);
    await tester.pumpAndSettle();
    expect(speed, 1.5);
  });
}
