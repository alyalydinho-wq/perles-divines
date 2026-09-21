import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/services.dart';
import 'core/store.dart';
import 'core/track.dart';
import 'features/downloads/download_controller.dart';
import 'features/duas/catalog.dart';
import 'features/home/home_screen.dart';
import 'features/player/audio_controller.dart';
import 'features/reader/content_install.dart';
import 'ui/theme.dart';

const fixturesEnabled = bool.fromEnvironment('PERLES_FIXTURES');
const mediaBase = String.fromEnvironment(
  'PERLES_MEDIA_BASE',
  defaultValue: 'http://127.0.0.1:4174',
);

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
  ThemeMode themeMode = ThemeMode.light;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Perles Divines',
    debugShowCheckedModeBanner: false,
    theme: lightTheme(),
    darkTheme: darkTheme(),
    themeMode: themeMode,
    home: BootstrapScreen(
      themeMode: themeMode,
      onThemeMode: (mode) => setState(() => themeMode = mode),
    ),
  );
}

class BootstrapScreen extends StatefulWidget {
  const BootstrapScreen({
    super.key,
    required this.themeMode,
    required this.onThemeMode,
  });
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeMode;
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
  Widget build(BuildContext context) => FutureBuilder(
    future: preparation,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return HomeScreen(
          services: snapshot.data!,
          themeMode: widget.themeMode,
          onThemeMode: widget.onThemeMode,
        );
      }
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
