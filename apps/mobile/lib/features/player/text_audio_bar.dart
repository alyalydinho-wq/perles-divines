import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../../core/track.dart';
import '../../ui/heritage.dart';
import 'audio_controller.dart';

const _speeds = <double>[1, 1.25, 1.5, 2];

class TextAudioBar extends StatelessWidget {
  const TextAudioBar({
    super.key,
    required this.tracks,
    this.audio,
    this.onUnavailable,
  });

  final List<Track> tracks;
  final PerlesAudioHandler? audio;
  final VoidCallback? onUnavailable;

  bool get hasAudio => tracks.isNotEmpty && audio != null;

  @override
  Widget build(BuildContext context) {
    final handler = audio;
    return Material(
      color: mahogany,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 10, 10),
        child: handler == null
            ? _bar(
                position: Duration.zero,
                duration: Duration.zero,
                playing: false,
                speed: 1,
              )
            : StreamBuilder<MediaItem?>(
                stream: handler.mediaItem,
                builder: (context, item) {
                  final currentId = item.data?.id;
                  final belongsHere = currentId != null &&
                      tracks.any((track) => track.id == currentId);
                  return StreamBuilder<PlaybackState>(
                    stream: handler.playbackState,
                    builder: (context, playback) {
                      return StreamBuilder<Duration>(
                        stream: handler.player.positionStream,
                        builder: (context, position) {
                          final durationMs = belongsHere
                              ? (handler.player.duration?.inMilliseconds ??
                                    handler.current?.durationMs ??
                                    tracks.first.durationMs)
                              : (tracks.isEmpty ? 0 : tracks.first.durationMs);
                          final pos = belongsHere
                              ? position.data ?? Duration.zero
                              : Duration.zero;
                          return _bar(
                            position: pos,
                            duration: Duration(milliseconds: durationMs),
                            playing: belongsHere &&
                                playback.data?.playing == true,
                            speed: handler.player.speed,
                            onSeek: hasAudio && belongsHere
                                ? (value) => handler.seek(
                                    Duration(milliseconds: value.round()),
                                  )
                                : null,
                            onPlayPause: () => _toggle(handler, belongsHere),
                            onSpeed: hasAudio
                                ? () => _cycleSpeed(handler)
                                : null,
                          );
                        },
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  Future<void> _toggle(PerlesAudioHandler handler, bool belongsHere) async {
    if (!hasAudio) {
      onUnavailable?.call();
      return;
    }
    if (belongsHere && handler.player.playing) {
      await handler.pause();
      return;
    }
    if (belongsHere) {
      await handler.play();
      return;
    }
    await handler.playTracks(tracks);
  }

  Future<void> _cycleSpeed(PerlesAudioHandler handler) async {
    final current = handler.player.speed;
    final index = _speeds.indexWhere((value) => (value - current).abs() < 0.01);
    final next = _speeds[(index + 1) % _speeds.length];
    await handler.setSpeed(next);
  }

  Widget _bar({
    required Duration position,
    required Duration duration,
    required bool playing,
    required double speed,
    ValueChanged<double>? onSeek,
    VoidCallback? onPlayPause,
    VoidCallback? onSpeed,
  }) {
    final max = duration.inMilliseconds <= 0
        ? 1.0
        : duration.inMilliseconds.toDouble();
    final value = position.inMilliseconds.toDouble().clamp(0, max);
    final label = speed == speed.roundToDouble()
        ? '${speed.toStringAsFixed(0)}x'
        : '${speed}x';
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  activeTrackColor: parchment,
                  inactiveTrackColor: parchment.withValues(alpha: 0.28),
                  thumbColor: playGreen,
                ),
                child: Slider(
                  value: value.toDouble(),
                  max: max,
                  onChanged: hasAudio ? onSeek : null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Text(
                      formatPlaybackClock(position),
                      style: const TextStyle(color: goldPale, fontSize: 12),
                    ),
                    const Spacer(),
                    Text(
                      formatPlaybackClock(duration),
                      style: const TextStyle(color: goldPale, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        _circleButton(
          icon: playing ? Icons.pause : Icons.play_arrow,
          tooltip: playing ? 'Pause' : 'Lire',
          onPressed: onPlayPause ?? onUnavailable,
        ),
        const SizedBox(width: 8),
        _circleButton(
          label: label,
          tooltip: 'Vitesse de lecture',
          onPressed: onSpeed,
        ),
      ],
    );
  }

  Widget _circleButton({
    IconData? icon,
    String? label,
    required String tooltip,
    VoidCallback? onPressed,
  }) => Tooltip(
    message: tooltip,
    child: Material(
      color: playGreen,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: icon != null
                ? Icon(icon, color: Colors.white, size: 26)
                : Text(
                    label ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
          ),
        ),
      ),
    ),
  );
}
