import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:perles_divines/core/track.dart';
import 'package:perles_divines/features/player/playback_notice.dart';

const _track = Track(
  id: 'kumayl',
  title: 'Doua-e-Kumayl',
  version: 1,
  durationMs: 120000,
  sizeBytes: 10,
  sha256: 'abc',
  file: 'audio/kumayl.m4a',
  author: 'Récitant',
);

void main() {
  test('la session reste une lecture média en arrière-plan', () {
    expect(
      backgroundPlaybackSession.avAudioSessionCategory,
      AVAudioSessionCategory.playback,
    );
    expect(
      backgroundPlaybackSession.avAudioSessionMode,
      AVAudioSessionMode.spokenAudio,
    );
    expect(
      backgroundPlaybackSession.androidAudioAttributes?.usage,
      AndroidAudioUsage.media,
    );
  });

  test('la notification montre le titre et le nom de l’application', () {
    final item = playbackNotice(_track);
    expect(item.title, 'Doua-e-Kumayl');
    expect(item.displayTitle, 'Doua-e-Kumayl');
    expect(item.artist, playbackAppName);
    expect(item.displaySubtitle, playbackAppName);
    expect(item.album, 'Récitant');
    expect(item.duration, const Duration(milliseconds: 120000));
  });

  test('la lecture expose pause, la pause retire la notification', () {
    final playing = systemPlaybackState(
      playing: true,
      retain: false,
      processingState: AudioProcessingState.ready,
      position: const Duration(seconds: 4),
      bufferedPosition: const Duration(seconds: 8),
      speed: 1,
      queueIndex: 0,
    );
    expect(playing.playing, isTrue);
    expect(playing.processingState, AudioProcessingState.ready);
    expect(playing.controls.map((control) => control.action), [
      MediaAction.skipToPrevious,
      MediaAction.pause,
      MediaAction.skipToNext,
    ]);

    final paused = systemPlaybackState(
      playing: false,
      retain: false,
      processingState: AudioProcessingState.ready,
      position: const Duration(seconds: 4),
      bufferedPosition: Duration.zero,
      speed: 1,
    );
    expect(paused.playing, isFalse);
    expect(paused.processingState, AudioProcessingState.idle);
    expect(paused.controls, isEmpty);
  });

  test('une transition garde la notification avec le bouton lire', () {
    final held = systemPlaybackState(
      playing: false,
      retain: true,
      processingState: AudioProcessingState.loading,
      position: Duration.zero,
      bufferedPosition: Duration.zero,
      speed: 1,
      queueIndex: 1,
    );
    expect(held.processingState, AudioProcessingState.loading);
    expect(
      held.controls.map((control) => control.action),
      contains(MediaAction.play),
    );
  });

  test('le lecteur de l’app reste visible en pause et se ferme à la fin', () {
    expect(
      inAppPlayerVisible(
        hasTrack: true,
        hasMediaItem: true,
        playing: false,
        resumable: playbackResumable(ProcessingState.ready),
      ),
      isTrue,
    );
    expect(
      inAppPlayerVisible(
        hasTrack: true,
        hasMediaItem: true,
        playing: true,
        resumable: false,
      ),
      isTrue,
    );
    expect(playbackResumable(ProcessingState.completed), isFalse);
    expect(
      inAppPlayerVisible(
        hasTrack: true,
        hasMediaItem: true,
        playing: false,
        resumable: playbackResumable(ProcessingState.completed),
      ),
      isFalse,
    );
    expect(
      inAppPlayerVisible(
        hasTrack: false,
        hasMediaItem: true,
        playing: true,
        resumable: true,
      ),
      isFalse,
    );
  });

  test('un appui masque la barre arrêtée jusqu’à la prochaine lecture', () {
    expect(
      retainedMiniPlayerDismissal(
        dismissedId: 'ziarat',
        itemId: 'ziarat',
        playing: false,
      ),
      'ziarat',
    );
    expect(
      retainedMiniPlayerDismissal(
        dismissedId: 'ziarat',
        itemId: 'ziarat',
        playing: true,
      ),
      isNull,
    );
    expect(
      retainedMiniPlayerDismissal(
        dismissedId: 'ziarat',
        itemId: 'autre',
        playing: false,
      ),
      isNull,
    );
    expect(
      retainedMiniPlayerDismissal(
        dismissedId: null,
        itemId: 'ziarat',
        playing: false,
      ),
      isNull,
    );
  });

  test('un appui sur la notification ouvre le lecteur', () {
    expect(
      routeAfterNotificationClick(clicked: true, currentPath: '/audios'),
      playerLocation,
    );
    expect(
      routeAfterNotificationClick(clicked: true, currentPath: playerLocation),
      isNull,
    );
    expect(
      routeAfterNotificationClick(clicked: false, currentPath: '/'),
      isNull,
    );
  });
}
