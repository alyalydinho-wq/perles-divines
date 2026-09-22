import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/scope.dart';
import 'core/services.dart';
import 'core/store.dart';
import 'core/track.dart';
import 'features/downloads/download_controller.dart';
import 'features/duas/catalog.dart';
import 'features/player/audio_controller.dart';
import 'features/reader/content_install.dart';
import 'routing.dart';
import 'ui/site.dart';
import 'ui/theme.dart';

const fixturesEnabled = bool.fromEnvironment('PERLES_FIXTURES');
const mediaBase = String.fromEnvironment(
  'PERLES_MEDIA_BASE',
  defaultValue: 'http://127.0.0.1:4174',
);

Future<List<Track>> loadBundledTracks() async {
  try {
    final rows = jsonDecode(
      await rootBundle.loadString('assets/content/audio-catalog.json'),
    ) as List<dynamic>;
    return [for (final row in rows) Track.fromJson(row as Map<String, dynamic>)];
  } on FlutterError {
    return [];
  }
}

void runPerles() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: PerlesApp()));
}

class PerlesApp extends StatefulWidget {
  const PerlesApp({super.key});
  @override
  State<PerlesApp> createState() => _PerlesAppState();
}

class _PerlesAppState extends State<PerlesApp> {
  late Future<Services> preparation;
  GoRouter? router;

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
        : await loadBundledTracks();
    return Services(
      edition,
      devotionalCatalog,
      store,
      downloads,
      audio,
      tracks,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Services>(
    future: preparation,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        router ??= createRouter();
        return ServicesScope(
          services: snapshot.data!,
          child: MaterialApp.router(
            title: 'Perles Divines',
            debugShowCheckedModeBanner: false,
            theme: lightTheme(),
            routerConfig: router!,
          ),
        );
      }
      return MaterialApp(
        title: 'Perles Divines',
        debugShowCheckedModeBanner: false,
        theme: lightTheme(),
        home: SitePage(
          children: [
            const SiteLogo(),
            const SiteGap(height: 44),
            if (!snapshot.hasError)
              const CircularProgressIndicator(color: siteGreenSolid),
            const SiteGap(),
            SiteBlackText(
              snapshot.hasError
                  ? 'La préparation a échoué. Les contenus ne sont pas déclarés prêts.\n${snapshot.error}'
                  : 'Préparation et vérification des textes pour la lecture hors connexion…',
            ),
            if (snapshot.hasError)
              SiteButton(
                label: 'Réessayer',
                green: true,
                onTap: () => setState(() => preparation = prepare()),
              ),
          ],
        ),
      );
    },
  );
}
