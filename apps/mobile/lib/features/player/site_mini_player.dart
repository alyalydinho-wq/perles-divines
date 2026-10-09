import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../ui/site.dart';
import 'audio_card.dart';
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
            if (track == null || !_sessionOpen(item.data, playback.data)) {
              return _systemInset(context);
            }
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
  }
}

Widget _systemInset(BuildContext context) =>
    SizedBox(height: MediaQuery.paddingOf(context).bottom);

bool _sessionOpen(MediaItem? item, PlaybackState? state) {
  if (item == null || state == null) return false;
  if (state.playing) return true;
  return state.processingState == AudioProcessingState.ready ||
      state.processingState == AudioProcessingState.buffering ||
      state.processingState == AudioProcessingState.loading;
}
