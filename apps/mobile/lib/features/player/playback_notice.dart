import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/track.dart';

const playbackAppName = 'Perles Divines';
const playerLocation = '/lecteur';

/// Lecture de fond : la catégorie `playback` laisse l’audio continuer
/// quand l’application n’est plus au premier plan, et l’usage Android
/// `media` l’associe au volume média et à la session système.
const backgroundPlaybackSession = AudioSessionConfiguration(
  avAudioSessionCategory: AVAudioSessionCategory.playback,
  avAudioSessionMode: AVAudioSessionMode.spokenAudio,
  androidAudioAttributes: AndroidAudioAttributes(
    contentType: AndroidAudioContentType.speech,
    usage: AndroidAudioUsage.media,
  ),
  androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
  androidWillPauseWhenDucked: true,
);

const playbackPlay = MediaControl(
  androidIcon: 'drawable/audio_service_play_arrow',
  label: 'Lire',
  action: MediaAction.play,
);
const playbackPause = MediaControl(
  androidIcon: 'drawable/audio_service_pause',
  label: 'Pause',
  action: MediaAction.pause,
);
const playbackPrevious = MediaControl(
  androidIcon: 'drawable/audio_service_skip_previous',
  label: 'Précédent',
  action: MediaAction.skipToPrevious,
);
const playbackNext = MediaControl(
  androidIcon: 'drawable/audio_service_skip_next',
  label: 'Suivant',
  action: MediaAction.skipToNext,
);

MediaItem playbackNotice(Track track) => MediaItem(
  id: track.id,
  title: track.title,
  album: track.author,
  artist: playbackAppName,
  displayTitle: track.title,
  displaySubtitle: playbackAppName,
  duration: Duration(milliseconds: track.durationMs),
);

List<MediaControl> playbackControls({required bool playing}) => [
  playbackPrevious,
  playing ? playbackPause : playbackPlay,
  playbackNext,
];

AudioProcessingState noticeProcessingState(ProcessingState state) =>
    switch (state) {
      ProcessingState.idle => AudioProcessingState.idle,
      ProcessingState.loading => AudioProcessingState.loading,
      ProcessingState.buffering => AudioProcessingState.buffering,
      ProcessingState.ready => AudioProcessingState.ready,
      ProcessingState.completed => AudioProcessingState.completed,
    };

/// `retain` garde la notification pendant une transition (piste suivante,
/// interruption brève). Sinon, une pause ou une fin de lecture publie
/// l’état idle : Android retire le service de premier plan et iOS efface
/// le Now Playing.
PlaybackState systemPlaybackState({
  required bool playing,
  required bool retain,
  required AudioProcessingState processingState,
  required Duration position,
  required Duration bufferedPosition,
  required double speed,
  int? queueIndex,
}) {
  if (!playing && !retain) {
    return PlaybackState(
      processingState: AudioProcessingState.idle,
      playing: false,
      controls: const [],
      updatePosition: position,
      bufferedPosition: bufferedPosition,
      speed: speed,
      queueIndex: queueIndex,
    );
  }
  return PlaybackState(
    controls: playbackControls(playing: playing),
    systemActions: const {
      MediaAction.seek,
      MediaAction.seekForward,
      MediaAction.seekBackward,
      MediaAction.play,
      MediaAction.pause,
    },
    androidCompactActionIndices: const [0, 1, 2],
    processingState: processingState,
    playing: playing,
    updatePosition: position,
    bufferedPosition: bufferedPosition,
    speed: speed,
    queueIndex: queueIndex,
  );
}

bool playbackResumable(ProcessingState state) =>
    state == ProcessingState.ready ||
    state == ProcessingState.buffering ||
    state == ProcessingState.loading;

bool inAppPlayerVisible({
  required bool hasTrack,
  required bool hasMediaItem,
  required bool playing,
  required bool resumable,
}) {
  if (!hasTrack || !hasMediaItem) return false;
  return playing || resumable;
}

String? routeAfterNotificationClick({
  required bool clicked,
  required String currentPath,
}) => clicked && currentPath != playerLocation ? playerLocation : null;
