import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/scope.dart';
import '../../ui/site.dart';
import 'audio_card.dart';
import 'playback_notice.dart';
import 'player_sheet.dart';

class SiteMiniPlayer extends StatelessWidget {
  const SiteMiniPlayer({super.key});

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
                final visible = inAppPlayerVisible(
                  hasTrack: true,
                  hasMediaItem: true,
                  playing: playback.data?.playing == true,
                  resumable: playbackResumable(
                    processing.data ?? ProcessingState.idle,
                  ),
                );
                if (!visible) return _systemInset(context);
                return AudioSessionCard(
                  key: const Key('site-player'),
                  track: track,
                  audio: audio,
                  downloads: audio.downloads,
                  store: audio.store,
                  dense: true,
                  keyed: false,
                  onTitle: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: siteCanvas,
                    builder: (context) => PlayerSheet(audio: audio),
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
