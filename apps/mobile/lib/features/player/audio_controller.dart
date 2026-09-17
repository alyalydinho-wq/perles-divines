import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/store.dart';
import '../../core/track.dart';
import '../downloads/download_controller.dart';

class PerlesAudioHandler extends BaseAudioHandler with SeekHandler {
  PerlesAudioHandler(this.store, this.downloads) {
    player.playbackEventStream.listen(
      (_) => _broadcast(),
      onError: (Object e) {
        error.add('Lecture impossible : $e');
      },
    );
    player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) unawaited(_finished());
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (player.playing && ++_ticks % 5 == 0) unawaited(_save());
      if (_deadline != null &&
          _remaining != null &&
          _clock.elapsed >= _remaining!) {
        unawaited(setSleep(null));
        unawaited(pause());
      }
    });
  }
  final AppStore store;
  final DownloadController downloads;
  final AudioPlayer player = AudioPlayer(
    handleInterruptions: false,
    handleAudioSessionActivation: false,
  );
  final error = StreamController<String>.broadcast();
  List<Track> _tracks = [];
  int _index = 0, _ticks = 0, _intent = 0;
  bool _loading = false, _endOfTrack = false, _bundled = false;
  late Timer _ticker;
  DateTime? _deadline;
  Duration? _remaining;
  final _clock = Stopwatch();
  final _subscriptions = <StreamSubscription>[];
  bool _resumeAfterInterruption = false;
  int _interruptionIntent = 0;
  Track? get current => _tracks.isEmpty ? null : _tracks[_index];
  Future<void> initialize() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    _subscriptions.add(
      session.becomingNoisyEventStream.listen((_) {
        unawaited(pause());
      }),
    );
    _subscriptions.add(
      session.interruptionEventStream.listen((event) async {
        if (event.begin) {
          _resumeAfterInterruption = player.playing;
          _interruptionIntent = _intent;
          await player.pause();
          await _save();
        } else if (_resumeAfterInterruption &&
            _interruptionIntent == _intent &&
            event.type != AudioInterruptionType.unknown) {
          _resumeAfterInterruption = false;
          await play();
        }
      }),
    );
    final speed = await store.readState('speed');
    if (speed is num) await player.setSpeed(speed.toDouble());
    final sleep = await store.readState('sleep');
    _endOfTrack = sleep is Map && sleep['endOfTrack'] == true;
    if (sleep is Map && sleep['deadline'] is String) {
      _deadline = DateTime.parse(sleep['deadline']);
      if (DateTime.now().toUtc().isAfter(_deadline!)) {
        await setSleep(null);
      } else {
        _remaining = _deadline!.difference(DateTime.now().toUtc());
        _clock.start();
      }
    }
    final saved = await store.readState('queue');
    if (saved is Map && (saved['tracks'] as List).isNotEmpty) {
      _tracks = (saved['tracks'] as List)
          .map((j) => Track.fromJson(Map<String, dynamic>.from(j)))
          .toList();
      _index = (saved['index'] as int).clamp(0, _tracks.length - 1);
      _bundled = saved['bundled'] == true;
      _publishQueue();
      await _load(_index, autoplay: false);
    }
  }

  void _publishQueue() => queue.add(
    _tracks
        .map(
          (t) => MediaItem(
            id: t.id,
            title: t.title,
            artist: t.author,
            duration: Duration(milliseconds: t.durationMs),
          ),
        )
        .toList(),
  );
  Future<void> playTracks(
    List<Track> tracks, {
    int index = 0,
    bool bundled = false,
  }) async {
    await _save();
    _intent++;
    _tracks = List.of(tracks);
    _bundled = bundled;
    _publishQueue();
    if (_tracks.isNotEmpty) await _load(index, autoplay: true);
  }

  Future<void> _load(int index, {required bool autoplay}) async {
    if (_loading) return;
    _loading = true;
    try {
      await player.pause();
      for (var next = index; next < _tracks.length; next++) {
        _index = next;
        final track = _tracks[next];
        final saved = await store.readState('position:${track.transferId}');
        final position = restoredPosition(
          saved?['ms'] ?? 0,
          track.durationMs,
          completed: saved?['completed'] == true,
        );
        final local = await downloads.localFile(track);
        final source = local != null
            ? AudioSource.uri(Uri.file(local))
            : _bundled && track.fixture && track.file != 'tone-3.mp3'
            ? AudioSource.asset('assets/fixtures/${track.file}')
            : AudioSource.uri(Uri.parse('${downloads.baseUrl}/${track.file}'));
        try {
          mediaItem.add(queue.value[next]);
          await player.setAudioSource(source, initialPosition: position);
          await store.writeState('queue', {
            'tracks': _tracks.map((t) => t.toJson()).toList(),
            'index': next,
            'bundled': _bundled,
          });
          if (autoplay) await play();
          return;
        } catch (_) {
          error.add(
            '« ${track.title} » est indisponible. Tentative de la piste suivante.',
          );
        }
      }
      await player.stop();
      error.add('Aucune piste disponible dans cette file.');
    } finally {
      _loading = false;
    }
  }

  Future<void> _save({bool completed = false}) async {
    final track = current;
    if (track == null || _loading) return;
    await store.writeState('position:${track.transferId}', {
      'ms': player.position.inMilliseconds,
      'completed': completed,
      'savedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> _finished() async {
    if (_loading || current == null) return;
    await _save(completed: true);
    if (_endOfTrack) {
      _endOfTrack = false;
      await pause();
      return;
    }
    if (_index + 1 < _tracks.length) {
      await _load(_index + 1, autoplay: true);
    } else {
      await pause();
    }
  }

  @override
  Future<void> play() async {
    _intent++;
    if (current == null) return;
    if (player.processingState == ProcessingState.completed) {
      await player.seek(Duration.zero);
    }
    final session = await AudioSession.instance;
    if (await session.setActive(true)) {
      unawaited(
        player.play().catchError((Object e) {
          error.add('Lecture impossible : $e');
        }),
      );
    }
  }

  @override
  Future<void> pause() async {
    _intent++;
    await player.pause();
    await _save();
  }

  @override
  Future<void> stop() async {
    await pause();
    await player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await player.seek(
      Duration(
        milliseconds: position.inMilliseconds.clamp(
          0,
          current?.durationMs ?? 0,
        ),
      ),
    );
    await _save();
  }

  @override
  Future<void> skipToNext() async {
    await _save();
    if (_index + 1 < _tracks.length) {
      await _load(_index + 1, autoplay: player.playing);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    await _save();
    if (_index > 0) {
      await _load(_index - 1, autoplay: player.playing);
    } else {
      await seek(Duration.zero);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < _tracks.length) {
      await _save();
      await _load(index, autoplay: player.playing);
    }
  }

  @override
  Future<void> fastForward() =>
      seek(player.position + const Duration(seconds: 15));
  @override
  Future<void> rewind() => seek(player.position - const Duration(seconds: 15));
  @override
  Future<void> setSpeed(double speed) async {
    if (![.75, 1, 1.25, 1.5, 1.75, 2].contains(speed)) return;
    await player.setSpeed(speed);
    await store.writeState('speed', speed);
  }

  Future<void> setSleep(Duration? duration, {bool endOfTrack = false}) async {
    _endOfTrack = endOfTrack;
    _remaining = duration;
    _clock.reset();
    _deadline = duration == null ? null : DateTime.now().toUtc().add(duration);
    if (duration != null) {
      _clock.start();
    } else {
      _clock.stop();
    }
    await store.writeState('sleep', {
      'deadline': _deadline?.toIso8601String(),
      'endOfTrack': endOfTrack,
    });
  }

  void _broadcast() => playbackState.add(
    PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        player.playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[player.processingState]!,
      playing: player.playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
      queueIndex: _index,
    ),
  );
  Future<void> dispose() async {
    _ticker.cancel();
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _save();
    await player.dispose();
    await error.close();
  }
}
