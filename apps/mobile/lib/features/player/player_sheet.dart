import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import 'audio_card.dart';
import 'audio_controller.dart';

class PlayerSheet extends StatelessWidget {
  const PlayerSheet({super.key, required this.audio});
  final PerlesAudioHandler audio;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            StreamBuilder<MediaItem?>(
              stream: audio.mediaItem,
              builder: (context, item) {
                final track = audio.current;
                if (track == null) {
                  return Text(
                    item.data?.title ?? 'Lecteur',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  );
                }
                return AudioSessionCard(
                  track: track,
                  audio: audio,
                  downloads: audio.downloads,
                  store: audio.store,
                  keyed: false,
                );
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Précédent',
                  color: Colors.white,
                  onPressed: audio.skipToPrevious,
                  icon: const Icon(Icons.skip_previous),
                ),
                TextButton(
                  onPressed: audio.rewind,
                  child: const Text(
                    '−15 s',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                TextButton(
                  onPressed: audio.fastForward,
                  child: const Text(
                    '+15 s',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                IconButton(
                  tooltip: 'Suivant',
                  color: Colors.white,
                  onPressed: audio.skipToNext,
                  icon: const Icon(Icons.skip_next),
                ),
              ],
            ),
            StreamBuilder<double>(
              stream: audio.player.speedStream,
              initialData: audio.player.speed,
              builder: (context, snapshot) => DropdownButton<double>(
                value: snapshot.data,
                dropdownColor: const Color(0xFF2A2A2E),
                style: const TextStyle(color: Colors.white),
                items: [.75, 1.0, 1.25, 1.5, 1.75, 2.0]
                    .map(
                      (speed) => DropdownMenuItem(
                        value: speed,
                        child: Text('Vitesse $speed×'),
                      ),
                    )
                    .toList(),
                onChanged: (speed) {
                  if (speed != null) audio.setSpeed(speed);
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
            const Text(
              'File de lecture',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            StreamBuilder<List<MediaItem>>(
              stream: audio.queue,
              builder: (context, snapshot) => Column(
                children: [
                  for (final (index, item) in (snapshot.data ?? []).indexed)
                    ListTile(
                      title: Text(
                        item.title,
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () => audio.skipToQueueItem(index),
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
