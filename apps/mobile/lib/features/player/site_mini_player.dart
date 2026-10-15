import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/scope.dart';
import '../../ui/site.dart';
import 'audio_card.dart';
import 'playback_notice.dart';
import 'player_sheet.dart';

class SiteMiniPlayer extends StatefulWidget {
  const SiteMiniPlayer({super.key});

  @override
  State<SiteMiniPlayer> createState() => _SiteMiniPlayerState();
}

class _SiteMiniPlayerState extends State<SiteMiniPlayer> {
  /// Réduite pendant la navigation, pour ne pas couvrir l’écran.
  bool _expanded = false;

  /// Piste retirée de l’écran après la fin d’écoute.
  String? _dismissedId;
  GoRouter? _router;
  String? _location;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    if (router == _router) return;
    _router?.routerDelegate.removeListener(_onRoute);
    _router = router;
    _router?.routerDelegate.addListener(_onRoute);
    _location = _router?.routerDelegate.currentConfiguration.uri.toString();
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRoute);
    super.dispose();
  }

  void _onRoute() {
    final location = _router?.routerDelegate.currentConfiguration.uri
        .toString();
    final changed = _location != null && location != _location;
    _location = location;
    if (changed && _expanded && mounted) {
      setState(() => _expanded = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final audio = ServicesScope.maybeOf(context)?.audio;
    if (audio == null) return _systemInset(context);
    return StreamBuilder<MediaItem?>(
      stream: audio.mediaItem,
      builder: (context, item) {
        return StreamBuilder<PlaybackState>(
          stream: audio.playbackState,
          builder: (context, playback) {
            final track = audio.current;
            if (track == null || item.data == null) {
              return _systemInset(context);
            }
            return StreamBuilder<ProcessingState>(
              stream: audio.player.processingStateStream,
              initialData: audio.player.processingState,
              builder: (context, processing) {
                final playing = playback.data?.playing == true;
                final visible = inAppPlayerVisible(
                  hasTrack: true,
                  hasMediaItem: true,
                  playing: playing,
                  resumable: playbackResumable(
                    processing.data ?? ProcessingState.idle,
                  ),
                );
                final itemId = item.data?.id;
                final dismissed = retainedMiniPlayerDismissal(
                  dismissedId: _dismissedId,
                  itemId: itemId,
                  playing: playing,
                );
                if (dismissed != _dismissedId) _dismissedId = dismissed;
                if (!visible) return _systemInset(context);
                return AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.bottomCenter,
                  child: dismissed != null
                      ? _systemInset(context)
                      : AudioSessionCard(
                          key: const Key('site-player'),
                          track: track,
                          audio: audio,
                          downloads: audio.downloads,
                          store: audio.store,
                          dense: true,
                          collapsed: !_expanded,
                          keyed: false,
                          onExpanded: (expanded) {
                            if (_expanded == expanded || !mounted) return;
                            setState(() => _expanded = expanded);
                          },
                          onDismiss: itemId == null
                              ? null
                              : () {
                                  if (!mounted) return;
                                  setState(() {
                                    _dismissedId = itemId;
                                    _expanded = false;
                                  });
                                },
                          onTitle: () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: siteCanvas,
                            builder: (context) => PlayerSheet(audio: audio),
                          ),
                        ),
                );
              },
            );
          },
        );
      },
    );
  }
}

Widget _systemInset(BuildContext context) =>
    SizedBox(height: MediaQuery.paddingOf(context).bottom);
