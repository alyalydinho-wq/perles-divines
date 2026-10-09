import 'package:flutter/material.dart';

import '../../core/store.dart';
import '../../core/track.dart';
import '../../ui/heritage.dart';
import '../../ui/site.dart';
import '../downloads/download_controller.dart';
import '../duas/favorites.dart';
import 'audio_controller.dart';

const audioBusyStates = {
  'queued',
  'downloading',
  'waitingForNetwork',
  'verifying',
};

/// Lecteur compact : titre, durée, favori, lecture au début de la barre
/// et téléchargement à la fin.
class AudioFace extends StatelessWidget {
  const AudioFace({
    super.key,
    required this.title,
    required this.duration,
    this.position = Duration.zero,
    this.playing = false,
    this.favorite = false,
    this.downloadState,
    this.downloadProgress = 0,
    this.error,
    this.onPlay,
    this.onSeek,
    this.onDownload,
    this.onFavorite,
    this.onTitle,
    this.dense = false,
    this.playKey,
    this.downloadKey,
    this.favoriteKey,
  });

  final String title;
  final Duration duration;
  final Duration position;
  final bool playing;
  final bool favorite;
  final String? downloadState;
  final double downloadProgress;
  final String? error;
  final VoidCallback? onPlay;
  final ValueChanged<double>? onSeek;
  final VoidCallback? onDownload;
  final VoidCallback? onFavorite;
  final VoidCallback? onTitle;
  final bool dense;
  final Key? playKey;
  final Key? downloadKey;
  final Key? favoriteKey;

  @override
  Widget build(BuildContext context) {
    final busy = audioBusyStates.contains(downloadState);
    final saved = downloadState == 'downloaded';
    final caption = _caption(busy, saved);
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: siteCanvas,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(dense ? 0 : 8),
            bottom: Radius.circular(dense ? 0 : 8),
          ),
          border: dense
              ? const Border(top: BorderSide(color: siteWhiteButtonBorder))
              : Border.all(color: siteWhiteButtonBorder),
          boxShadow: dense
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            dense ? 12 : 16,
            dense ? 8 : 14,
            dense ? 4 : 6,
            (dense ? 8 : 8) +
                (dense ? MediaQuery.paddingOf(context).bottom : 0),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: onTitle,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: EdgeInsets.only(top: dense ? 4 : 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              maxLines: dense ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: siteText(
                                color: siteBlack,
                                fontSize: dense ? 16 : 18,
                                lineHeight: dense ? 20 : 22,
                                weight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: siteSmallBlack,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _StarButton(
                    key: favoriteKey,
                    favorite: favorite,
                    onPressed: onFavorite,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  _RoundButton(
                    buttonKey: playKey,
                    tooltip: playing ? 'Pause' : 'Lire',
                    onPressed: onPlay,
                    icon: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: siteButtonText,
                      size: dense ? 26 : 30,
                    ),
                    diameter: dense ? 42 : 48,
                  ),
                  Expanded(child: _bar()),
                  _RoundButton(
                    buttonKey: downloadKey,
                    tooltip: busy
                        ? 'Téléchargement'
                        : saved
                        ? 'Retirer du téléphone'
                        : 'Télécharger',
                    filled: !saved,
                    onPressed: busy ? null : onDownload,
                    icon: _downloadIcon(busy, saved),
                    diameter: dense ? 42 : 48,
                  ),
                ],
              ),
              if (error != null && error!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 12, 6),
                  child: Text(
                    error!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: siteText(
                      color: const Color(0xFF9B1C1C),
                      fontSize: 12,
                      lineHeight: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _caption(bool busy, bool saved) {
    final total = formatPlaybackClock(duration);
    final clock = position > Duration.zero
        ? '${formatPlaybackClock(position)} / $total'
        : total;
    if (busy) {
      final percent = (downloadProgress * 100).round().clamp(0, 100);
      return '$clock · $percent %';
    }
    if (saved) return '$clock · Sur le téléphone';
    return clock;
  }

  Widget _bar() {
    final max = duration.inMilliseconds <= 0
        ? 1.0
        : duration.inMilliseconds.toDouble();
    final value = position.inMilliseconds.toDouble().clamp(0, max).toDouble();
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 3,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: dense ? 5 : 6),
        overlayShape: RoundSliderOverlayShape(overlayRadius: dense ? 12 : 14),
        activeTrackColor: siteGreenSolid,
        inactiveTrackColor: siteGreenBottom.withValues(alpha: 0.28),
        thumbColor: siteGreenSolid,
        disabledActiveTrackColor: siteGreenSolid,
        disabledInactiveTrackColor: siteGreenBottom.withValues(alpha: 0.28),
        disabledThumbColor: siteGreenSolid,
      ),
      child: Slider(value: value, max: max, onChanged: onSeek),
    );
  }

  Widget _downloadIcon(bool busy, bool saved) {
    if (busy) {
      final known = downloadProgress > 0 && downloadProgress < 1;
      return SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          color: saved ? siteGreenSolid : siteButtonText,
          value: known ? downloadProgress : null,
        ),
      );
    }
    return Icon(
      saved ? Icons.download_done_rounded : Icons.download_rounded,
      color: saved ? siteGreenSolid : siteButtonText,
      size: 26,
    );
  }
}

class _StarButton extends StatelessWidget {
  const _StarButton({
    super.key,
    required this.favorite,
    required this.onPressed,
  });

  final bool favorite;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: favorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 42, height: 42),
      icon: Icon(
        favorite ? Icons.star_rounded : Icons.star_border_rounded,
        color: favorite ? siteGreenSolid : siteGreen,
        size: 28,
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.tooltip,
    required this.icon,
    required this.diameter,
    this.onPressed,
    this.buttonKey,
    this.filled = true,
  });

  final String tooltip;
  final Widget icon;
  final double diameter;
  final VoidCallback? onPressed;
  final Key? buttonKey;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          key: buttonKey,
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Ink(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? null : siteCanvas,
              gradient: filled
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: enabled
                          ? const [siteGreenTop, siteGreenBottom]
                          : [
                              siteGreenTop.withValues(alpha: 0.45),
                              siteGreenBottom.withValues(alpha: 0.45),
                            ],
                    )
                  : null,
              border: Border.all(
                color: filled ? siteButtonBorder : siteWhiteButtonBorder,
              ),
            ),
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }
}

class AudioSessionCard extends StatefulWidget {
  const AudioSessionCard({
    super.key,
    required this.track,
    this.audio,
    this.downloads,
    this.store,
    this.dense = false,
    this.keyed = true,
    this.onTitle,
  });

  final Track track;
  final PerlesAudioHandler? audio;
  final DownloadController? downloads;
  final AppStore? store;
  final bool dense;
  final bool keyed;
  final VoidCallback? onTitle;

  @override
  State<AudioSessionCard> createState() => _AudioSessionCardState();
}

class _AudioSessionCardState extends State<AudioSessionCard> {
  AudioFavorites? favorites;
  Stream<List<Transfer>>? transfers;

  @override
  void initState() {
    super.initState();
    final store = widget.store;
    if (store != null) {
      favorites = AudioFavorites(store)..addListener(_onFavorites);
      transfers = store.watchTransfers();
      favorites!.read();
    }
  }

  @override
  void didUpdateWidget(AudioSessionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store == widget.store) return;
    favorites?.removeListener(_onFavorites);
    final store = widget.store;
    if (store == null) {
      favorites = null;
      transfers = null;
      return;
    }
    favorites = AudioFavorites(store)..addListener(_onFavorites);
    transfers = store.watchTransfers();
    favorites!.read();
  }

  @override
  void dispose() {
    favorites?.removeListener(_onFavorites);
    super.dispose();
  }

  void _onFavorites() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Transfer>>(
      stream: transfers,
      builder: (context, transfer) {
        final row = transfer.data?.cast<Transfer?>().firstWhere(
          (item) => item?.id == widget.track.transferId,
          orElse: () => null,
        );
        final audio = widget.audio;
        if (audio == null) return _face(row, false, false, Duration.zero);
        return StreamBuilder(
          stream: audio.mediaItem,
          builder: (context, item) {
            final active = item.data?.id == widget.track.id;
            if (!active) return _face(row, false, false, Duration.zero);
            return StreamBuilder(
              stream: audio.playbackState,
              builder: (context, playback) {
                return StreamBuilder<Duration>(
                  stream: audio.player.positionStream,
                  builder: (context, position) {
                    return _face(
                      row,
                      true,
                      playback.data?.playing == true,
                      position.data ?? Duration.zero,
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

  Widget _face(Transfer? row, bool active, bool playing, Duration position) {
    final track = widget.track;
    final duration = Duration(milliseconds: track.durationMs);
    final busy = audioBusyStates.contains(row?.state);
    return AudioFace(
      title: track.title,
      duration: duration,
      position: active ? position : Duration.zero,
      playing: playing,
      favorite: favorites?.ids.contains(track.id) ?? false,
      downloadState: row?.state,
      downloadProgress: row?.progress ?? 0,
      error: row?.state == 'failed' ? row?.error : null,
      dense: widget.dense,
      onTitle: widget.onTitle,
      onPlay: widget.audio == null ? null : _play,
      onSeek: active && track.durationMs > 0
          ? (value) => widget.audio!.seek(Duration(milliseconds: value.round()))
          : null,
      onDownload: widget.downloads == null || busy
          ? null
          : () => _download(row),
      onFavorite: favorites == null ? null : () => favorites!.toggle(track.id),
      playKey: widget.keyed ? Key('play-${track.id}') : null,
      downloadKey: widget.keyed ? Key('download-${track.id}') : null,
      favoriteKey: widget.keyed ? Key('favorite-${track.id}') : null,
    );
  }

  Future<void> _play() async {
    final audio = widget.audio;
    if (audio == null) return;
    final active = audio.current?.id == widget.track.id;
    if (active && audio.player.playing) {
      await audio.pause();
      return;
    }
    if (active) {
      await audio.play();
      return;
    }
    await audio.playTracks([widget.track]);
  }

  Future<void> _download(Transfer? row) async {
    final downloads = widget.downloads;
    if (downloads == null) return;
    if (row?.state == 'downloaded') {
      await downloads.removeLocal(widget.track);
      return;
    }
    await downloads.enqueue([widget.track], individual: true);
  }
}
