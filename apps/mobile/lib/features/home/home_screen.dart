import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../core/store.dart';
import '../../core/track.dart';
import '../catalog/text_screen.dart';
import '../duas/dua.dart';
import '../duas/favorites.dart';
import '../player/audio_controller.dart';
import '../reader/reader_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.services,
    required this.onThemeMode,
    required this.themeMode,
  });
  final Services services;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeMode;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  String query = '';
  String audioQuery = '';
  bool favoriteOnly = false;
  DevotionalKind? kindFilter;
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
    final dark = await s.store.readState('darkMode');
    if (!mounted) return;
    setState(() {
      wifiOnly = wifi != false;
      favorites = Set<String>.from(saved ?? []);
      devotionalFavorites = savedDevotional;
    });
    widget.onThemeMode(dark == true ? ThemeMode.dark : ThemeMode.light);
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

  Future<void> openText(DevotionalText item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => TextScreen(
          item: item,
          edition: s.edition,
          favorite: devotionalFavorites.contains(item.id),
          onFavorite: () async {
            final values = await DevotionalFavorites(s.store).toggle(item.id);
            if (mounted) setState(() => devotionalFavorites = values);
          },
        ),
      ),
    );
  }

  void showCategory(DevotionalKind? kind) {
    setState(() {
      tab = 1;
      kindFilter = kind;
      favoriteOnly = false;
    });
  }

  @override
  void dispose() {
    errors?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        if (bool.fromEnvironment('PERLES_FIXTURES'))
          Material(
            color: const Color(0xfffff2cc),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'VERSION D’ESSAI — Audios synthétiques, aucun catalogue réel.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
          ),
        Expanded(
          child: IndexedStack(
            index: tab,
            children: [
              home(),
              texts(),
              catalog(),
              downloadsView(),
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
        NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Accueil'),
        NavigationDestination(icon: Icon(Icons.auto_stories_outlined), label: 'Textes'),
        NavigationDestination(icon: Icon(Icons.headphones_outlined), label: 'Audios'),
        NavigationDestination(icon: Icon(Icons.library_music_outlined), label: 'Bibliothèque'),
        NavigationDestination(icon: Icon(Icons.tune), label: 'Réglages'),
      ],
    ),
  );

  Widget home() {
    final catalog = s.devotionalCatalog;
    final favs = catalog.items
        .where((item) => devotionalFavorites.contains(item.id))
        .toList();
    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          title: const Text('Perles Divines'),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          sliver: SliverList.list(
            children: [
              Text(
                'Duʿā, ziyārāt et textes du recueil, lisibles hors connexion.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Rechercher un texte',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (value) => setState(() {
                  query = value;
                  tab = 1;
                  kindFilter = null;
                  favoriteOnly = false;
                }),
              ),
              const SizedBox(height: 20),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  for (final kind in DevotionalKind.values)
                    _CategoryCard(
                      title: kindLabel(kind),
                      count: catalog.ofKind(kind).length,
                      icon: switch (kind) {
                        DevotionalKind.dua => Icons.auto_stories_outlined,
                        DevotionalKind.ziyarat => Icons.mosque,
                        DevotionalKind.quran => Icons.menu_book_outlined,
                        DevotionalKind.namaz => Icons.explore_outlined,
                        DevotionalKind.aamal => Icons.calendar_month_outlined,
                      },
                      onTap: () => showCategory(kind),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.favorite_outline),
                  title: const Text('Favoris'),
                  subtitle: Text(
                    favs.isEmpty
                        ? 'Aucun texte enregistré sur cet appareil'
                        : '${favs.length} texte(s) sur cet appareil',
                  ),
                  onTap: () => setState(() {
                    tab = 1;
                    kindFilter = null;
                    favoriteOnly = true;
                    query = '';
                  }),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.public),
                  title: const Text('Pages originales'),
                  subtitle: const Text(
                    'Sommaire importé du site, avec l’arabe en images',
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => Scaffold(
                        appBar: AppBar(title: const Text('Pages originales')),
                        body: ReaderScreen(edition: s.edition),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget texts() {
    final items = favoriteOnly
        ? s.devotionalCatalog.search(query).where((item) =>
            devotionalFavorites.contains(item.id)).toList()
        : s.devotionalCatalog.search(query, kind: kindFilter);
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: Text(
            kindFilter == null ? 'Textes' : kindLabel(kindFilter!),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: favoriteOnly
                        ? 'Favoris enregistrés'
                        : 'Rechercher dans les textes',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => query = value),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: const Text('Tous'),
                          selected: kindFilter == null && !favoriteOnly,
                          onSelected: (_) => setState(() {
                            kindFilter = null;
                            favoriteOnly = false;
                          }),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: const Text('Favoris'),
                          selected: favoriteOnly,
                          onSelected: (_) => setState(() {
                            favoriteOnly = true;
                            kindFilter = null;
                          }),
                        ),
                      ),
                      for (final kind in DevotionalKind.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(kindLabel(kind)),
                            selected: kindFilter == kind,
                            onSelected: (_) => setState(() {
                              kindFilter = kind;
                              favoriteOnly = false;
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (items.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Aucun texte ne correspond à cette recherche.'),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            sliver: SliverList.separated(
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                    title: Text(item.title),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        [
                          kindLabel(item.kind),
                          if (item.preview.isNotEmpty) item.preview,
                        ].join(' · '),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    trailing: IconButton(
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
                        if (mounted) {
                          setState(() => devotionalFavorites = values);
                        }
                      },
                    ),
                    onTap: () => openText(item),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget catalog() {
    final tracks = s.tracks
        .where((t) => t.title.toLowerCase().contains(audioQuery.toLowerCase()))
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: [
        Text('Audios', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Rechercher un audio',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (q) => setState(() => audioQuery = q),
        ),
        if (s.tracks.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Les pistes audio seront associées après inventaire des MP3. Les textes restent lisibles hors connexion.',
            ),
          ),
        if (s.tracks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Wrap(
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
          ),
        for (final t in tracks)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
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
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget downloadsView() => StreamBuilder<List<Transfer>>(
    stream: s.store.watchTransfers(),
    builder: (context, snapshot) {
      final transfers = snapshot.data ?? [];
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        children: [
          Text(
            'Bibliothèque',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          if (transfers.isEmpty) const Text('Aucun téléchargement demandé.'),
          for (final row in transfers)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
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
          Text('Favoris audio', style: Theme.of(context).textTheme.titleLarge),
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
    padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
    children: [
      SwitchListTile(
        title: const Text('Thème sombre'),
        subtitle: const Text('Lecture plus douce le soir.'),
        value: widget.themeMode == ThemeMode.dark,
        onChanged: (v) async {
          await s.store.writeState('darkMode', v);
          widget.onThemeMode(v ? ThemeMode.dark : ThemeMode.light);
        },
      ),
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
          'Les titres, traductions et translittérations viennent des pages importées. L’arabe calligraphié reste affiché depuis la page originale, sans texte inventé.',
        ),
      ),
      const ListTile(
        title: Text('Données personnelles'),
        subtitle: Text(
          'Favoris et positions restent sur ce téléphone. Aucun compte public ni mesure d’écoute.',
        ),
      ),
      const ListTile(
        title: Text('Version 0.1.0'),
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

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final int count;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28),
            const Spacer(),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            Text('$count texte${count > 1 ? 's' : ''}'),
          ],
        ),
      ),
    ),
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
