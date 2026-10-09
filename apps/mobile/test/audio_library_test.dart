import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perles_divines/core/track.dart';
import 'package:perles_divines/features/catalog/audio_library_screen.dart';
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
    expect(shelfOf(_track('Douà du lundi')), AudioShelf.aamal);
    expect(shelfOf(_track('Sehri ni Douà')), AudioShelf.aamal);
    expect(shelfOf(_track('Mounajat é Shabaniya')), AudioShelf.aamal);
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
    expect(counts[AudioShelf.doua], 17);
    expect(counts[AudioShelf.zyaraate], 26);
    expect(counts[AudioShelf.aamal], 42);
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
    expect(find.text('Favoris'), findsOneWidget);
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
