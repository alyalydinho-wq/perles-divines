import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'core/scope.dart';
import 'core/services.dart';
import 'core/store.dart';
import 'core/track.dart';
import 'features/downloads/download_controller.dart';
import 'features/duas/catalog.dart';
import 'features/player/audio_controller.dart';
import 'features/player/playback_notice.dart';
import 'features/reader/content_install.dart';
import 'routing.dart';
import 'ui/site.dart';
import 'ui/theme.dart';

const mediaBase = String.fromEnvironment(
  'PERLES_MEDIA_BASE',
  defaultValue: 'https://pub-809de60784fd477e972458cf82fb463a.r2.dev',
);

Future<List<Track>> loadBundledTracks() async {
  try {
    final rows = jsonDecode(
      await rootBundle.loadString('assets/content/audio-catalog.json'),
    ) as List<dynamic>;
    return [
      for (final row in rows) Track.fromJson(row as Map<String, dynamic>),
    ];
  } on FlutterError {
    return [];
  }
}

void runPerles() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PerlesApp());
}

class PerlesApp extends StatefulWidget {
  const PerlesApp({super.key});
  @override
  State<PerlesApp> createState() => _PerlesAppState();
}

class _PerlesAppState extends State<PerlesApp> {
  /// Le sommaire s’affiche dès la première image ; les services arrivent
  /// ensuite, chacun dès qu’il est prêt, et en parallèle.
  late Services _services;
  late final GoRouter router = createRouter();
  Object? _failure;
  int _attempt = 0;
  StreamSubscription<bool>? _notificationClicks;

  @override
  void initState() {
    super.initState();
    _services = Services(store: AppStore());
    unawaited(prepare());
  }

  @override
  void dispose() {
    _notificationClicks?.cancel();
    super.dispose();
  }

  void _arrive(int attempt, Services Function(Services current) update) {
    if (!mounted || attempt != _attempt) return;
    setState(() => _services = update(_services));
  }

  Future<void> prepare() async {
    final attempt = ++_attempt;
    final store = _services.store;
    try {
      await Future.wait([
        LocalDevotionalCatalog.load().then(
          (catalog) => _arrive(
            attempt,
            (s) => s.copyWith(devotionalCatalog: catalog),
          ),
        ),
        loadBundledTracks().then(
          (tracks) => _arrive(attempt, (s) => s.copyWith(tracks: tracks)),
        ),
        LocalEdition.install().then(
          (edition) => _arrive(attempt, (s) => s.copyWith(edition: edition)),
        ),
        _prepareAudio(attempt, store),
      ]);
    } catch (error) {
      if (mounted && attempt == _attempt) setState(() => _failure = error);
    }
  }

  /// Téléchargements et lecteur : rien à l’écran n’en dépend pour s’ouvrir,
  /// on les démarre après la première image.
  Future<void> _prepareAudio(int attempt, AppStore store) async {
    await WidgetsBinding.instance.endOfFrame;
    // Reprise après un échec : le lecteur du premier essai reste en place.
    if (_services.audio != null) return;
    final downloads = DownloadController(store, baseUrl: mediaBase);
    await downloads.initialize();
    _arrive(attempt, (s) => s.copyWith(downloads: downloads));
    final audio = await AudioService.init<PerlesAudioHandler>(
      builder: () => PerlesAudioHandler(store, downloads),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'fr.perlesdivines.playback.visible',
        androidNotificationChannelName: 'Lecture audio',
        androidNotificationChannelDescription:
            'Lecture, pause et progression lorsqu’un audio est en cours.',
        androidNotificationIcon: 'drawable/ic_stat_audio',
        notificationColor: siteGreenBottom,
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        androidNotificationClickStartsActivity: true,
        fastForwardInterval: Duration(seconds: 15),
        rewindInterval: Duration(seconds: 15),
      ),
    );
    await audio.initialize();
    _arrive(attempt, (s) => s.copyWith(audio: audio));
    _notificationClicks ??= AudioService.notificationClicked.listen((clicked) {
      final current = router.state.uri.path;
      final destination = routeAfterNotificationClick(
        clicked: clicked,
        currentPath: current,
      );
      if (destination != null) router.push(destination);
    });
  }

  @override
  Widget build(BuildContext context) {
    final failure = _failure;
    if (failure != null) {
      return MaterialApp(
        title: 'Perles Divines',
        debugShowCheckedModeBanner: false,
        theme: lightTheme(),
        home: SitePage(
          children: [
            const SiteLogo(),
            const SiteGap(height: 44),
            SiteBlackText(
              'La préparation a échoué. Les contenus ne sont pas déclarés prêts.\n$failure',
            ),
            SiteButton(
              label: 'Réessayer',
              green: true,
              onTap: () {
                setState(() => _failure = null);
                unawaited(prepare());
              },
            ),
          ],
        ),
      );
    }
    return ServicesScope(
      services: _services,
      child: MaterialApp.router(
        title: 'Perles Divines',
        debugShowCheckedModeBanner: false,
        theme: lightTheme(),
        routerConfig: router,
      ),
    );
  }
}
