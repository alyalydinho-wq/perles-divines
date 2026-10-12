import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perles_divines/core/track.dart';
import 'package:perles_divines/features/catalog/audio_library_screen.dart';
import 'package:perles_divines/features/player/audio_card.dart';
import 'package:perles_divines/features/catalog/audio_shelves.dart';
import 'package:perles_divines/features/catalog/favorite_groups.dart';
import 'package:perles_divines/features/duas/dua.dart';

Track _track(String title) => Track(
  id: title,
  title: title,
  version: 1,
  durationMs: 1000,
  sizeBytes: 10,
  sha256: 'abc',
  file: 'audio/test.m4a',
);

void main() {
  test('chaque audio va dans Doua, Zyaraate, Aamal ou Hadith', () {
    expect(shelfOf(_track('Doua-e-Ahad')), AudioShelf.doua);
    expect(shelfOf(_track('Douà é Tawassoul')), AudioShelf.doua);
    expect(shelfOf(_track('Ziarat Imam Hassan as')), AudioShelf.zyaraate);
    expect(shelfOf(_track('Zyaarat-e-Amin-Allàh')), AudioShelf.zyaraate);
    expect(
      shelfOf(_track('Ziarat é Imamé Zaman atfs du vendredi')),
      AudioShelf.zyaraate,
    );
    expect(shelfOf(_track('Douà 2 Mahé Ramzane')), AudioShelf.aamal);
    expect(shelfOf(_track('Douà du 30 Mahé Ramzane')), AudioShelf.aamal);
    expect(shelfOf(_track('Douà du lundi')), AudioShelf.doua);
    expect(shelfOf(_track('Douà du vendredi')), AudioShelf.doua);
    expect(shelfOf(_track('Douà du premier jour de l’an')), AudioShelf.doua);
    expect(shelfOf(_track('Douà du dernier jour de l’an')), AudioShelf.doua);
    expect(
      shelfOf(_track('Douà du dernier vendredi de Mahé Ramzane')),
      AudioShelf.doua,
    );
    expect(shelfOf(_track('Sehri ni Douà')), AudioShelf.doua);
    expect(shelfOf(_track('Mounajat é Shabaniya')), AudioShelf.doua);
    expect(shelfOf(_track('Salàwat é Mahé Shabàne')), AudioShelf.doua);
    expect(shelfOf(_track('Hadiçe é Kissà')), AudioShelf.hadith);
  });

  test('les jours de Ramadan restent dans l’ordre numérique', () {
    final tracks = [
      _track('Douà 10 Mahé Ramzane'),
      _track('Douà 2 Mahé Ramzane'),
      _track('Douà du 30 Mahé Ramzane'),
    ];
    expect(tracksOf(AudioShelf.aamal, tracks).map((track) => track.title), [
      'Douà 2 Mahé Ramzane',
      'Douà 10 Mahé Ramzane',
      'Douà du 30 Mahé Ramzane',
    ]);
  });

  test('le catalogue publié classe les 86 audios sans en oublier', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final rows = jsonDecode(
      await rootBundle.loadString('assets/content/audio-catalog.json'),
    ) as List<dynamic>;
    final tracks = [
      for (final row in rows) Track.fromJson(row as Map<String, dynamic>),
    ];
    final counts = {
      for (final shelf in AudioShelf.values)
        shelf: tracksOf(shelf, tracks).length,
    };
    expect(tracks.length, 86);
    expect(counts[AudioShelf.doua], 30);
    expect(counts[AudioShelf.zyaraate], 26);
    expect(counts[AudioShelf.aamal], 29);
    expect(counts[AudioShelf.hadith], 1);
    expect(counts[AudioShelf.autres], 0);
    expect(counts.values.reduce((a, b) => a + b), 86);
  });

  testWidgets('les audios s’ouvrent par rubrique', (tester) async {
    const track = Track(
      id: 'ahad',
      title: 'Doua-e-Ahad',
      version: 1,
      durationMs: 430000,
      sizeBytes: 1000,
      sha256: 'abc',
      file: 'audio/doua-e-ahad.m4a',
    );
    await tester.pumpWidget(
      const MaterialApp(home: AudioLibraryScreen(tracks: [track])),
    );
    await tester.pump();
    expect(find.text('Doua (1)'), findsOneWidget);
    expect(find.text('Favoris'), findsNothing);
    expect(find.text('Zyaraate (0)'), findsNothing);
    expect(find.text('Écouter'), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: AudioShelfScreen(shelf: AudioShelf.doua, tracks: [track]),
      ),
    );
    await tester.pump();
    expect(find.text('Doua-e-Ahad'), findsOneWidget);
    expect(find.text('7:10'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.byIcon(Icons.download_rounded), findsOneWidget);
    expect(find.byIcon(Icons.star_border_rounded), findsOneWidget);
    expect(find.text('Écouter'), findsNothing);
    expect(find.text('Télécharger'), findsNothing);
    expect(find.byKey(const Key('play-ahad')), findsOneWidget);
    expect(find.byKey(const Key('download-ahad')), findsOneWidget);
    expect(find.byKey(const Key('favorite-ahad')), findsOneWidget);
  });

  testWidgets('un audio téléchargé se reconnaît sur le bouton', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AudioFace(
            title: 'Doua-e-Ahad',
            duration: Duration(minutes: 7, seconds: 10),
            downloadState: 'downloaded',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.download_done_rounded), findsOneWidget);
    expect(find.byIcon(Icons.download_rounded), findsNothing);
    expect(find.text('7:10 · Téléchargé'), findsOneWidget);
    expect(find.byTooltip('Téléchargé'), findsOneWidget);
  });

  testWidgets(
    'la barre réduite ne garde que le titre et lecture, et se déplie vers le haut',
    (tester) async {
      bool? expanded;
      var played = 0;
      double? sought;
      Future<void> show({required bool collapsed}) {
        return tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: AudioFace(
                  title: 'Douâ 22 Mahé Ramzane',
                  duration: const Duration(minutes: 1),
                  position: const Duration(seconds: 26),
                  playing: true,
                  favorite: true,
                  downloadState: 'downloaded',
                  dense: true,
                  collapsed: collapsed,
                  onPlay: () => played++,
                  onSeek: (value) => sought = value,
                  onExpanded: (value) => expanded = value,
                ),
              ),
            ),
          ),
        );
      }

      await show(collapsed: true);
      await tester.pump();
      final collapsedHeight = tester.getSize(find.byType(AudioFace)).height;
      expect(find.text('Douâ 22 Mahé Ramzane'), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(
        tester.getCenter(find.byIcon(Icons.pause_rounded)).dx,
        lessThan(tester.getCenter(find.text('Douâ 22 Mahé Ramzane')).dx),
      );
      expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.textContaining('Téléchargé'), findsNothing);
      expect(find.byIcon(Icons.download_done_rounded), findsNothing);

      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();
      expect(played, 1);
      expect(expanded, isNull);

      await tester.tap(find.text('Douâ 22 Mahé Ramzane'));
      await tester.pump();
      expect(expanded, isTrue);

      expanded = null;
      await tester.fling(
        find.text('Douâ 22 Mahé Ramzane'),
        const Offset(0, -120),
        1200,
      );
      await tester.pump();
      expect(expanded, isTrue);

      expanded = null;
      await tester.tap(find.byKey(const Key('player-peek')));
      await tester.pump();
      expect(expanded, isTrue);

      await show(collapsed: false);
      await tester.pump();
      expect(
        tester.getSize(find.byType(AudioFace)).height,
        greaterThan(collapsedHeight),
      );
      expect(find.byType(Slider), findsOneWidget);
      expect(find.textContaining('Téléchargé'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);

      expanded = null;
      await tester.drag(find.byType(Slider), const Offset(80, 0));
      await tester.pump();
      expect(sought, isNotNull);
      expect(expanded, isNull);

      await tester.fling(
        find.byKey(const Key('player-peek')),
        const Offset(0, 120),
        1200,
      );
      await tester.pump();
      expect(expanded, isFalse);
    },
  );

  testWidgets('le téléchargement et la suppression demandent confirmation', (
    tester,
  ) async {
    bool? answer;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              answer = await confirmAudioTransfer(
                context,
                title: 'Doua-e-Ahad',
                remove: false,
              );
            },
            child: const Text('ouvrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    expect(
      find.text('Télécharger « Doua-e-Ahad » sur ce téléphone ?'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Annuler'));
    await tester.pumpAndSettle();
    expect(answer, isFalse);

    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Télécharger'));
    await tester.pumpAndSettle();
    expect(answer, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              answer = await confirmAudioTransfer(
                context,
                title: 'Doua-e-Ahad',
                remove: true,
              );
            },
            child: const Text('ouvrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    expect(
      find.text('Supprimer « Doua-e-Ahad » de ce téléphone ?'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
    await tester.pumpAndSettle();
    expect(answer, isTrue);
  });

  testWidgets('la barre du lecteur se dessine sans écran Material parent', (
    tester,
  ) async {
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xffffffff),
        onGenerateRoute: (settings) => PageRouteBuilder<void>(
          settings: settings,
          pageBuilder: (context, animation, secondary) => const Align(
            alignment: Alignment.bottomCenter,
            child: AudioFace(
              title: 'Ziaraté Imamé Zaman',
              duration: Duration(minutes: 4, seconds: 16),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('Ziaraté Imamé Zaman'), findsOneWidget);
    expect(find.textContaining('No Material widget found'), findsNothing);
  });

  test('les favoris de l’application sont classés par rubrique', () {
    const kumayl = DevotionalText(
      id: 'kumayl',
      kind: DevotionalKind.dua,
      title: 'Doua-e-Kumayl',
      arabic: '',
      translation: '',
      transliteration: '',
      references: [],
      audioIds: [],
    );
    const monthly = DevotionalText(
      id: 'rajab',
      kind: DevotionalKind.aamal,
      title: 'Aamal du mois de Rajab',
      arabic: '',
      translation: '',
      transliteration: '',
      references: [],
      audioIds: [],
    );
    final groups = favoriteGroups(
      catalog: [kumayl, monthly],
      tracks: [_track('Douà 2 Mahé Ramzane'), _track('Doua-e-Ahad')],
      textIds: {'kumayl', 'rajab'},
      audioIds: {'Douà 2 Mahé Ramzane', 'Doua-e-Ahad'},
    );
    expect(groups.map((group) => group.label), [
      'Doua',
      'Aamal Mensuel',
      'Aamal',
    ]);
    expect(groups.first.texts.single.id, 'kumayl');
    expect(groups.first.audios.single.title, 'Doua-e-Ahad');
    expect(groups[1].texts.single.id, 'rajab');
    expect(groups[1].audios, isEmpty);
    expect(groups.last.audios.single.title, 'Douà 2 Mahé Ramzane');
  });
}
