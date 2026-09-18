import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/store.dart';
import 'core/track.dart';
import 'features/downloads/download_controller.dart';
import 'features/duas/catalog.dart';
import 'features/duas/dua.dart';
import 'features/duas/favorites.dart';
import 'features/player/audio_controller.dart';
import 'features/reader/content_install.dart';
import 'features/reader/reader_screen.dart';

const fixturesEnabled = bool.fromEnvironment('PERLES_FIXTURES');
const mediaBase = String.fromEnvironment(
  'PERLES_MEDIA_BASE',
  defaultValue: 'http://127.0.0.1:4174',
);
void runPerles() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: PerlesApp()));
}

class PerlesApp extends StatelessWidget {
  const PerlesApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Perles Divines',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff145014)),
      useMaterial3: true,
    ),
    home: const BootstrapScreen(),
  );
}

class BootstrapScreen extends StatefulWidget {
  const BootstrapScreen({super.key});
  @override
  State<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<BootstrapScreen> {
  late Future<Services> preparation;
  @override
  void initState() {
    super.initState();
    preparation = prepare();
  }

  Future<Services> prepare() async {
    final edition = await LocalEdition.install();
    final devotionalCatalog = await LocalDevotionalCatalog.load();
    final store = AppStore();
    final downloads = DownloadController(store, baseUrl: mediaBase);
    await downloads.initialize();
    final audio = await AudioService.init<PerlesAudioHandler>(
      builder: () => PerlesAudioHandler(store, downloads),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'fr.perlesdivines.playback',
        androidNotificationChannelName: 'Lecture audio',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
    await audio.initialize();
    final tracks = fixturesEnabled
        ? (jsonDecode(
            await rootBundle.loadString('assets/fixtures/catalog.json'),
          ) as List).map((j) => Track.fromJson(j)).toList()
        : <Track>[];
    return Services(edition, devotionalCatalog, store, downloads, audio, tracks);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: preparation,
    builder: (context, snapshot) {
      if (snapshot.hasData) return HomeScreen(services: snapshot.data!);
      return Scaffold(
        appBar: AppBar(title: const Text('Perles Divines')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!snapshot.hasError) const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(
                  snapshot.hasError
                      ? 'La préparation a échoué. Les contenus ne sont pas déclarés prêts.\n${snapshot.error}'
                      : 'Préparation et vérification des textes pour la lecture hors connexion…',
                ),
                if (snapshot.hasError)
                  FilledButton(
                    onPressed: () => setState(() => preparation = prepare()),
                    child: const Text('Réessayer'),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class Services {
  Services(
    this.edition,
    this.devotionalCatalog,
    this.store,
    this.downloads,
    this.audio,
    this.tracks,
  );
  final LocalEdition edition;
  final LocalDevotionalCatalog devotionalCatalog;
  final AppStore store;
  final DownloadController downloads;
  final PerlesAudioHandler audio;
  final List<Track> tracks;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.services});
  final Services services;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  String query = '';
  String devotionalQuery = '';
  bool wifiOnly = true;
  Set<String> favorites = {};
  Set<String> devotionalFavorites = {};
  StreamSubscription<String>? errors;
  Services get s => widget.services;
  @override
  void initState() {
    super.initState();
    settings();
    errors = s.audio.error.stream.listen(message);
  }

  Future<void> settings() async {
    final wifi = await s.store.readState('wifiOnly');
    final saved = await s.store.readState('favorites');
    final savedDevotional = await DevotionalFavorites(s.store).read();
    if (mounted) {
      setState(() {
        wifiOnly = wifi != false;
        favorites = Set<String>.from(saved ?? []);
        devotionalFavorites = savedDevotional;
      });
    }
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> action(Future<void> Function() work) async {
    try {
      await work();
    } catch (e) {
      message(e.toString());
    }
  }

  Future<void> favorite(Track t) async {
    setState(() {
      if (!favorites.add(t.id)) favorites.remove(t.id);
    });
    await s.store.writeState('favorites', favorites.toList());
  }

  Future<void> download(List<Track> tracks) async {
    final missing = <Track>[];
    for (final t in tracks) {
      if (await s.downloads.localFile(t) == null) missing.add(t);
    }
    if (!mounted) return;
    final bytes = missing.fold<int>(0, (n, t) => n + t.sizeBytes);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Préparer les audios'),
        content: Text(
          '${missing.length} fichier(s), ${(bytes / 1048576).toStringAsFixed(1)} Mio.\n${wifiOnly ? 'Wi-Fi uniquement.' : 'Données mobiles autorisées.'}\nUne marge de stockage est vérifiée avant chaque transfert.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Télécharger'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await action(
        () => s.downloads.enqueue(missing, individual: tracks.length == 1),
      );
    }
  }

  @override
  void dispose() {
    errors?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Perles Divines')),
    body: Column(
      children: [
        if (fixturesEnabled)
          const Material(
            color: Color(0xfffff2cc),
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'VERSION D’ESSAI — Audios synthétiques, aucun catalogue réel.',
              ),
            ),
          ),
        Expanded(
          child: IndexedStack(
            index: tab,
            children: [
              ReaderScreen(edition: s.edition),
              devotionalCatalog(),
              catalog(),
              downloads(),
              settingsView(),
            ],
          ),
        ),
        miniPlayer(),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (i) => setState(() => tab = i),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.menu_book), label: 'Sommaire'),
        NavigationDestination(icon: Icon(Icons.auto_stories), label: 'Textes'),
        NavigationDestination(icon: Icon(Icons.headphones), label: 'Audios'),
        NavigationDestination(
          icon: Icon(Icons.library_music),
          label: 'Bibliothèque',
        ),
        NavigationDestination(icon: Icon(Icons.settings), label: 'Réglages'),
      ],
    ),
  );
  Widget devotionalCatalog() {
    final items = s.devotionalCatalog.search(devotionalQuery);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: 'Rechercher dans les duʿā et ziyārāt',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) => setState(() => devotionalQuery = value),
        ),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Le catalogue local sera rempli avec les textes relus dans le dépôt avant la prochaine compilation.',
            ),
          ),
        for (final item in items) devotionalCard(item),
      ],
    );
  }

  Widget devotionalCard(DevotionalText item) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          SelectableText(item.arabic, textDirection: TextDirection.rtl),
          if (item.transliteration.isNotEmpty)
            SelectableText(item.transliteration),
          if (item.translation.isNotEmpty) SelectableText(item.translation),
          for (final reference in item.references) Text(reference),
          IconButton(
            tooltip: 'Favori',
            icon: Icon(
              devotionalFavorites.contains(item.id)
                  ? Icons.favorite
                  : Icons.favorite_border,
            ),
            onPressed: () async {
              final values = await DevotionalFavorites(
                s.store,
              ).toggle(item.id);
              if (mounted) setState(() => devotionalFavorites = values);
            },
          ),
        ],
      ),
    ),
  );
  Widget catalog() {
    final tracks = s.tracks
        .where((t) => t.title.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: 'Rechercher un audio',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (q) => setState(() => query = q),
        ),
        if (s.tracks.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Le catalogue audio n’a pas encore été publié. Les textes sont disponibles hors connexion.',
            ),
          ),
        if (s.tracks.isNotEmpty)
          Wrap(
            spacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => action(() => s.audio.playTracks(s.tracks)),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Lire la collection'),
              ),
              OutlinedButton.icon(
                onPressed: () => download(s.tracks),
                icon: const Icon(Icons.download),
                label: const Text('Tout télécharger'),
              ),
            ],
          ),
        for (final t in tracks)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.title, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    '${(t.durationMs / 60000).toStringAsFixed(1)} min · ${(t.sizeBytes / 1048576).toStringAsFixed(2)} Mio',
                  ),
                  Wrap(
                    children: [
                      IconButton(
                        tooltip: 'Lire',
                        onPressed: () => action(
                          () => s.audio.playTracks(
                            tracks,
                            index: tracks.indexOf(t),
                          ),
                        ),
                        icon: const Icon(Icons.play_arrow),
                      ),
                      IconButton(
                        tooltip: 'Télécharger',
                        onPressed: () => download([t]),
                        icon: const Icon(Icons.download),
                      ),
                      IconButton(
                        tooltip: 'Favori',
                        onPressed: () => favorite(t),
                        icon: Icon(
                          favorites.contains(t.id)
                              ? Icons.favorite
                              : Icons.favorite_border,
                        ),
                      ),
                      if (t.file != 'tone-3.mp3' && fixturesEnabled)
                        TextButton(
                          onPressed: () => action(
                            () => s.audio.playTracks([t], bundled: true),
                          ),
                          child: const Text('Essai audio local'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget downloads() => StreamBuilder<List<Transfer>>(
    stream: s.store.watchTransfers(),
    builder: (context, snapshot) {
      final transfers = snapshot.data ?? [];
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Téléchargements',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (transfers.isEmpty) const Text('Aucun téléchargement demandé.'),
          for (final row in transfers)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Track.fromJson(jsonDecode(row.trackJson)).title),
                    Text(
                      {
                            'queued': 'En attente',
                            'waitingForNetwork':
                                'En attente du système ou du réseau',
                            'downloading': 'Téléchargement',
                            'verifying': 'Vérification',
                            'downloaded': 'Disponible hors connexion',
                            'paused': 'En pause',
                            'cancelled': 'Annulé',
                            'failed': 'Échec',
                          }[row.state] ??
                          row.state,
                    ),
                    LinearProgressIndicator(value: row.progress.clamp(0, 1)),
                    if (row.error != null) Text(row.error!),
                    Wrap(
                      children: [
                        if ([
                          'queued',
                          'downloading',
                          'waitingForNetwork',
                        ].contains(row.state))
                          TextButton(
                            onPressed: () =>
                                action(() => s.downloads.pause(row.id)),
                            child: const Text('Suspendre'),
                          ),
                        if (row.state == 'paused')
                          TextButton(
                            onPressed: () =>
                                action(() => s.downloads.resume(row.id)),
                            child: const Text('Reprendre'),
                          ),
                        if (['failed', 'cancelled'].contains(row.state))
                          TextButton(
                            onPressed: () => download([
                              Track.fromJson(jsonDecode(row.trackJson)),
                            ]),
                            child: const Text('Relancer'),
                          ),
                        if (row.state == 'downloaded')
                          TextButton(
                            onPressed: () => action(
                              () => s.downloads.export(
                                Track.fromJson(jsonDecode(row.trackJson)),
                              ),
                            ),
                            child: const Text('Exporter le MP3'),
                          ),
                        if (!['downloaded', 'cancelled'].contains(row.state))
                          TextButton(
                            onPressed: () =>
                                action(() => s.downloads.cancel(row.id)),
                            child: const Text('Annuler'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          Text('Favoris', style: Theme.of(context).textTheme.headlineSmall),
          for (final track in s.tracks.where((t) => favorites.contains(t.id)))
            ListTile(
              title: Text(track.title),
              onTap: () => action(() => s.audio.playTracks([track])),
            ),
        ],
      );
    },
  );
  Widget settingsView() => ListView(
    children: [
      SwitchListTile(
        title: const Text('Télécharger uniquement en Wi-Fi'),
        subtitle: const Text('S’applique aux nouveaux transferts.'),
        value: wifiOnly,
        onChanged: (v) async {
          await s.store.writeState('wifiOnly', v);
          setState(() => wifiOnly = v);
        },
      ),
      const ListTile(
        title: Text('Textes préparés'),
        subtitle: Text(
          'Les duʿā, ziyārāt et métadonnées audio sont préparés dans le dépôt puis embarqués avec l’application.',
        ),
      ),
      const ListTile(
        title: Text('Données personnelles'),
        subtitle: Text(
          'Favoris et positions restent sur ce téléphone. Aucun compte public ni mesure d’écoute.',
        ),
      ),
      const ListTile(
        title: Text('Version 0.1.0 — preuve technique'),
        subtitle: Text(
          'Les essais Android et iPhone doivent être consignés séparément.',
        ),
      ),
    ],
  );
  Widget miniPlayer() => StreamBuilder<MediaItem?>(
    stream: s.audio.mediaItem,
    builder: (context, item) {
      if (item.data == null) return const SizedBox.shrink();
      return Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: ListTile(
          title: Text(
            item.data!.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) => PlayerSheet(audio: s.audio),
          ),
          trailing: StreamBuilder<PlaybackState>(
            stream: s.audio.playbackState,
            builder: (context, state) => IconButton(
              tooltip: state.data?.playing == true ? 'Pause' : 'Lire',
              icon: Icon(
                state.data?.playing == true ? Icons.pause : Icons.play_arrow,
              ),
              onPressed: () => action(
                state.data?.playing == true ? s.audio.pause : s.audio.play,
              ),
            ),
          ),
        ),
      );
    },
  );
}

class PlayerSheet extends StatelessWidget {
  const PlayerSheet({super.key, required this.audio});
  final PerlesAudioHandler audio;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StreamBuilder<MediaItem?>(
              stream: audio.mediaItem,
              builder: (context, s) => Text(
                s.data?.title ?? 'Lecteur',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            StreamBuilder<Duration>(
              stream: audio.player.positionStream,
              builder: (context, s) {
                final max =
                    (audio.player.duration?.inMilliseconds ??
                            audio.current?.durationMs ??
                            1)
                        .toDouble();
                final pos = (s.data?.inMilliseconds ?? 0)
                    .toDouble()
                    .clamp(0, max)
                    .toDouble();
                return Column(
                  children: [
                    Slider(
                      value: pos,
                      max: max > 0 ? max : 1,
                      onChanged: (v) =>
                          audio.seek(Duration(milliseconds: v.round())),
                    ),
                    Text(
                      '${Duration(milliseconds: pos.round()).toString().split('.').first} / ${Duration(milliseconds: max.round()).toString().split('.').first}',
                    ),
                  ],
                );
              },
            ),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Précédent',
                  onPressed: audio.skipToPrevious,
                  icon: const Icon(Icons.skip_previous),
                ),
                TextButton(onPressed: audio.rewind, child: const Text('−15 s')),
                StreamBuilder<PlaybackState>(
                  stream: audio.playbackState,
                  builder: (context, s) => IconButton(
                    tooltip: s.data?.playing == true ? 'Pause' : 'Lire',
                    onPressed: s.data?.playing == true
                        ? audio.pause
                        : audio.play,
                    icon: Icon(
                      s.data?.playing == true
                          ? Icons.pause_circle
                          : Icons.play_circle,
                    ),
                    iconSize: 56,
                  ),
                ),
                TextButton(
                  onPressed: audio.fastForward,
                  child: const Text('+15 s'),
                ),
                IconButton(
                  tooltip: 'Suivant',
                  onPressed: audio.skipToNext,
                  icon: const Icon(Icons.skip_next),
                ),
              ],
            ),
            StreamBuilder<double>(
              stream: audio.player.speedStream,
              initialData: audio.player.speed,
              builder: (context, s) => DropdownButton<double>(
                value: s.data,
                items: [.75, 1.0, 1.25, 1.5, 1.75, 2.0]
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text('Vitesse $v×'),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) audio.setSpeed(v);
                },
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final minutes in [15, 30, 45, 60])
                  ActionChip(
                    label: Text('$minutes min'),
                    onPressed: () => audio.setSleep(Duration(minutes: minutes)),
                  ),
                ActionChip(
                  label: const Text('Fin de piste'),
                  onPressed: () => audio.setSleep(null, endOfTrack: true),
                ),
                ActionChip(
                  label: const Text('Sans minuterie'),
                  onPressed: () => audio.setSleep(null),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('File de lecture'),
            StreamBuilder<List<MediaItem>>(
              stream: audio.queue,
              builder: (context, s) => Column(
                children: [
                  for (final (i, t) in (s.data ?? []).indexed)
                    ListTile(
                      title: Text(t.title),
                      onTap: () => audio.skipToQueueItem(i),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
