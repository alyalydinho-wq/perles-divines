import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import 'audio_controller.dart';

class PlayerSheet extends StatelessWidget {
  const PlayerSheet({super.key, required this.audio});
  final PerlesAudioHandler audio;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StreamBuilder<MediaItem?>(
              stream: audio.mediaItem,
              builder: (context, s) => Text(
                s.data?.title ?? 'Lecteur',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            StreamBuilder<Duration>(
              stream: audio.player.positionStream,
              builder: (context, s) {
                final max =
                    (audio.player.duration?.inMilliseconds ??
                            audio.current?.durationMs ??
                            1)
                        .toDouble();
                final pos = (s.data?.inMilliseconds ?? 0)
                    .toDouble()
                    .clamp(0, max)
                    .toDouble();
                return Column(
                  children: [
                    Slider(
                      value: pos,
                      max: max > 0 ? max : 1,
                      onChanged: (v) =>
                          audio.seek(Duration(milliseconds: v.round())),
                    ),
                    Text(
                      '${Duration(milliseconds: pos.round()).toString().split('.').first} / ${Duration(milliseconds: max.round()).toString().split('.').first}',
                    ),
                  ],
                );
              },
            ),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Précédent',
                  onPressed: audio.skipToPrevious,
                  icon: const Icon(Icons.skip_previous),
                ),
                TextButton(onPressed: audio.rewind, child: const Text('−15 s')),
                StreamBuilder<PlaybackState>(
                  stream: audio.playbackState,
                  builder: (context, s) => IconButton(
                    tooltip: s.data?.playing == true ? 'Pause' : 'Lire',
                    onPressed: s.data?.playing == true
                        ? audio.pause
                        : audio.play,
                    icon: Icon(
                      s.data?.playing == true
                          ? Icons.pause_circle
                          : Icons.play_circle,
                    ),
                    iconSize: 56,
                  ),
                ),
                TextButton(
                  onPressed: audio.fastForward,
                  child: const Text('+15 s'),
                ),
                IconButton(
                  tooltip: 'Suivant',
                  onPressed: audio.skipToNext,
                  icon: const Icon(Icons.skip_next),
                ),
              ],
            ),
            StreamBuilder<double>(
              stream: audio.player.speedStream,
              initialData: audio.player.speed,
              builder: (context, s) => DropdownButton<double>(
                value: s.data,
                items: [.75, 1.0, 1.25, 1.5, 1.75, 2.0]
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text('Vitesse $v×'),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) audio.setSpeed(v);
                },
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final minutes in [15, 30, 45, 60])
                  ActionChip(
                    label: Text('$minutes min'),
                    onPressed: () => audio.setSleep(Duration(minutes: minutes)),
                  ),
                ActionChip(
                  label: const Text('Fin de piste'),
                  onPressed: () => audio.setSleep(null, endOfTrack: true),
                ),
                ActionChip(
                  label: const Text('Sans minuterie'),
                  onPressed: () => audio.setSleep(null),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('File de lecture'),
            StreamBuilder<List<MediaItem>>(
              stream: audio.queue,
              builder: (context, s) => Column(
                children: [
                  for (final (i, t) in (s.data ?? []).indexed)
                    ListTile(
                      title: Text(t.title),
                      onTap: () => audio.skipToQueueItem(i),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
