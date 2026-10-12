import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/scope.dart';
import '../../ui/site.dart';
import 'player_sheet.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = ServicesScope.of(context).audio;
    return Scaffold(
      key: const Key('player-screen'),
      backgroundColor: siteCanvas,
      appBar: AppBar(
        title: const Text('Lecteur'),
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: StreamBuilder<MediaItem?>(
        stream: audio.mediaItem,
        builder: (context, _) {
          if (audio.current == null) {
            return Center(
              child: Text('Aucun audio en cours.', style: siteText()),
            );
          }
          return PlayerSheet(audio: audio, handle: false);
        },
      ),
    );
  }
}
