import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../ui/heritage.dart';
import '../../ui/site.dart';
import 'player_sheet.dart';

const _speeds = <double>[1, 1.25, 1.5, 2];

class SiteMiniPlayer extends StatelessWidget {
  const SiteMiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = ServicesScope.maybeOf(context)?.audio;
    if (audio == null) {
      return const _Bar();
    }
    return StreamBuilder<MediaItem?>(
      stream: audio.mediaItem,
      builder: (context, item) {
        return StreamBuilder<PlaybackState>(
          stream: audio.playbackState,
          builder: (context, playback) {
            return StreamBuilder<Duration>(
              stream: audio.player.positionStream,
              builder: (context, position) {
                return StreamBuilder<double>(
                  stream: audio.player.speedStream,
                  initialData: audio.player.speed,
                  builder: (context, speed) {
                    final durationMs =
                        audio.player.duration?.inMilliseconds ??
                        audio.current?.durationMs ??
                        0;
                    final playing = playback.data?.playing == true;
                    return _Bar(
                      title: item.data?.title,
                      position: position.data ?? Duration.zero,
                      duration: Duration(milliseconds: durationMs),
                      playing: playing,
                      speed: speed.data ?? 1,
                      onPlayPause: () async {
                        if (item.data == null) return;
                        if (playing) {
                          await audio.pause();
                        } else {
                          await audio.play();
                        }
                      },
                      onSpeed: () => _cycleSpeed(audio.player.speed, audio.setSpeed),
                      onSeek: durationMs > 0
                          ? (value) => audio.seek(
                              Duration(milliseconds: value.round()),
                            )
                          : null,
                      onOpen: item.data == null
                          ? null
                          : () => showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              builder: (context) => PlayerSheet(audio: audio),
                            ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

Future<void> _cycleSpeed(
  double current,
  Future<void> Function(double speed) setSpeed,
) async {
  final index = _speeds.indexWhere((value) => (value - current).abs() < 0.01);
  final next = _speeds[(index + 1) % _speeds.length];
  await setSpeed(next);
}

class _Bar extends StatelessWidget {
  const _Bar({
    this.title,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.playing = false,
    this.speed = 1,
    this.onPlayPause,
    this.onSpeed,
    this.onSeek,
    this.onOpen,
  });

  final String? title;
  final Duration position;
  final Duration duration;
  final bool playing;
  final double speed;
  final VoidCallback? onPlayPause;
  final VoidCallback? onSpeed;
  final ValueChanged<double>? onSeek;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final max = duration.inMilliseconds <= 0
        ? 1.0
        : duration.inMilliseconds.toDouble();
    final value = position.inMilliseconds.toDouble().clamp(0, max);
    final ready = title != null;
    final speedLabel = speed == speed.roundToDouble()
        ? '${speed.toStringAsFixed(0)}x'
        : '${speed}x';
    return Material(
      key: const Key('site-player'),
      color: Colors.transparent,
      child: Ink(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: siteButtonBorder)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [siteGreenTop, siteGreenBottom],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            8,
            8,
            10,
            8 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: onOpen,
                child: Text(
                  title ?? 'Aucun audio en cours',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: siteText(
                    color: siteButtonText,
                    fontSize: 13,
                    lineHeight: 16,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 7,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 14,
                            ),
                            activeTrackColor: siteGreen,
                            inactiveTrackColor: siteButtonText.withValues(
                              alpha: 0.35,
                            ),
                            thumbColor: siteCanvas,
                          ),
                          child: Slider(
                            value: value.toDouble(),
                            max: max,
                            onChanged: ready ? onSeek : null,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              Text(
                                formatPlaybackClock(position),
                                style: siteText(
                                  color: siteButtonText,
                                  fontSize: 12,
                                  lineHeight: 14,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                formatPlaybackClock(duration),
                                style: siteText(
                                  color: siteButtonText,
                                  fontSize: 12,
                                  lineHeight: 14,
                                ),
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
                    onPressed: ready ? onPlayPause : null,
                  ),
                  const SizedBox(width: 8),
                  _circleButton(
                    label: speedLabel,
                    tooltip: 'Vitesse de lecture',
                    onPressed: onSpeed,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
      color: siteButtonText,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: icon != null
                ? Icon(icon, color: siteGreen, size: 26)
                : Text(
                    label ?? '',
                    style: const TextStyle(
                      color: siteGreen,
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
