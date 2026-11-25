import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:background_downloader/background_downloader.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/store.dart';
import '../../core/track.dart';

/// Fichier présent et de la taille attendue.
///
/// C’est le contrôle de chaque ouverture et de chaque lecture : l’empreinte
/// complète n’est calculée qu’une fois, quand le fichier arrive. Un transfert
/// interrompu laisse un fichier trop court, que ce contrôle refuse.
Future<bool> mediaPresent(String path, int size) async {
  final file = File(path);
  return await file.exists() && await file.length() == size;
}

/// Taille et empreinte SHA-256 : le fichier est exactement celui du catalogue.
Future<bool> verifyMedia(String path, int size, String expectedHash) async {
  if (!await mediaPresent(path, size)) return false;
  return Isolate.run(
    () async =>
        (await sha256.bind(File(path).openRead()).first).toString() ==
        expectedHash,
  );
}

/// États d’un transfert déjà confié au téléchargement en arrière-plan.
const _engineStates = {
  'queued',
  'waitingForNetwork',
  'downloading',
  'verifying',
  'paused',
};

/// Sans progrès pendant ce délai, l’écoute en ligne a décroché : le
/// téléchargement en arrière-plan reprend le fichier.
const streamStallDelay = Duration(seconds: 90);

class DownloadController {
  DownloadController(this.store, {required this.baseUrl});
  final AppStore store;
  final String baseUrl;
  final engine = FileDownloader();
  static const storage = MethodChannel('perles_divines/storage');
  late Directory root;
  bool _pumping = false;
  final _finishing = <String>{};
  Future<void> _events = Future.value();
  StreamSubscription<TaskUpdate>? _subscription;

  /// Écoutes en ligne qui remplissent en même temps le fichier local.
  ///
  /// `LockCachingAudioSource` est marqué expérimental par just_audio : si
  /// l’écoute décroche, [_handOver] confie le fichier au téléchargement en
  /// arrière-plan, comme avant.
  // ignore: experimental_member_use
  final _streams = <String, LockCachingAudioSource>{};
  final _streamProgress = <String, StreamSubscription<double>>{};
  final _stalls = <String, Timer>{};

  String _mediaPath(Track track) =>
      p.join(root.path, 'media', cachedMediaName(track));

  Future<void> initialize() async {
    root = await getApplicationSupportDirectory();
    await engine.configure(globalConfig: (Config.holdingQueue, (3, 3, 3)));
    final media = await Directory(
      p.join(root.path, 'media'),
    ).create(recursive: true);
    await _removeStreamLeftovers(media);
    _subscription = engine.updates.listen((event) {
      _events = _events.then((_) => _handle(event)).catchError((
        Object e,
      ) async {
        await store.updateTransfer(
          event.task.taskId,
          TransfersCompanion(
            state: const Value('failed'),
            error: Value('Le transfert doit être relancé : $e'),
          ),
        );
      });
    });
    await engine.start(markDownloadedComplete: false, autoCleanDatabase: false);
    await _events;
    // Completed native work can predate the Dart process. Never trust existence alone.
    final native = {
      for (final r in await engine.database.allRecords()) r.taskId: r,
    };
    for (final row in await store.select(store.transfers).get()) {
      final track = Track.fromJson(jsonDecode(row.trackJson));
      final finalPath = _mediaPath(track);
      final relative = p.relative(finalPath, from: root.path);
      // Déjà vérifié à son arrivée : la taille suffit, sans relire le fichier.
      if (row.state == 'downloaded' &&
          await mediaPresent(finalPath, track.sizeBytes)) {
        if (row.relativePath != relative) {
          await store.updateTransfer(
            row.id,
            TransfersCompanion(relativePath: Value(relative)),
          );
        }
        continue;
      }
      if (await verifyMedia(finalPath, track.sizeBytes, track.sha256)) {
        await store.updateTransfer(
          row.id,
          TransfersCompanion(
            state: const Value('downloaded'),
            progress: const Value(1),
            relativePath: Value(p.relative(finalPath, from: root.path)),
            error: const Value(null),
          ),
        );
      } else if (native[row.id]?.status == TaskStatus.complete) {
        await _complete(native[row.id]!.task, track);
      } else if (native[row.id]?.status.isFinalState == true) {
        await store.updateTransfer(
          row.id,
          TransfersCompanion(
            state: Value(
              native[row.id]!.status == TaskStatus.canceled
                  ? 'cancelled'
                  : 'failed',
            ),
            error: const Value(
              'Transfert interrompu. Vous pouvez le relancer.',
            ),
          ),
        );
      } else if (row.state == 'streaming') {
        // L’application a été fermée pendant une écoute en ligne : le
        // téléchargement en arrière-plan termine le fichier.
        await store.updateTransfer(
          row.id,
          const TransfersCompanion(state: Value('queued'), progress: Value(0)),
        );
      } else if (row.state == 'downloaded') {
        await store.updateTransfer(
          row.id,
          const TransfersCompanion(
            state: Value('failed'),
            error: Value('Fichier local absent ou corrompu.'),
          ),
        );
      } else if (!native.containsKey(row.id) &&
          !['cancelled', 'failed', 'paused'].contains(row.state)) {
        await store.updateTransfer(
          row.id,
          const TransfersCompanion(
            state: Value('queued'),
            taskJson: Value(null),
          ),
        );
      }
    }
    await pump();
  }

  Future<void> enqueue(List<Track> tracks, {bool individual = false}) async {
    final wifi = await store.readState('wifiOnly') != false;
    await store.transaction(() async {
      for (final track in tracks) {
        final old = await store.transfer(track.transferId);
        if (old != null && !['failed', 'cancelled'].contains(old.state)) {
          continue;
        }
        final task = _taskFor(track, individual: individual, wifi: wifi);
        await store
            .into(store.transfers)
            .insertOnConflictUpdate(
              TransfersCompanion.insert(
                id: track.transferId,
                trackJson: jsonEncode(track.toJson()),
                taskJson: Value(jsonEncode(task.toJson())),
                priority: Value(individual ? 1 : 5),
                state: const Value('queued'),
                error: const Value(null),
              ),
            );
      }
    });
    await pump();
  }

  DownloadTask _taskFor(
    Track track, {
    required bool individual,
    required bool wifi,
  }) => DownloadTask(
    taskId: track.transferId,
    url: '$baseUrl/${track.file}',
    filename: '${track.transferId}.part',
    directory: 'staging',
    baseDirectory: BaseDirectory.applicationSupport,
    updates: Updates.statusAndProgress,
    allowPause: true,
    requiresWiFi: individual ? false : wifi,
    retries: 3,
    priority: individual ? 1 : 5,
    displayName: track.title,
  );

  /// Source de lecture d’un audio pas encore sur le téléphone.
  ///
  /// L’écoute en ligne remplit directement le fichier local : un seul
  /// transfert, et l’audio reste ensuite disponible hors connexion. Si un
  /// téléchargement en arrière-plan est déjà en cours, on lit en ligne
  /// sans enregistrer, pour ne pas doubler le transfert.
  Future<AudioSource> playbackSource(Track track) async {
    final remote = Uri.parse('$baseUrl/${track.file}');
    if (track.fixture) return AudioSource.uri(remote);
    final id = track.transferId;
    final active = _streams[id];
    if (active != null) return active;
    final row = await store.transfer(id);
    if (row != null && _engineStates.contains(row.state)) {
      return AudioSource.uri(remote);
    }
    final target = File(_mediaPath(track));
    if (await target.exists()) {
      if (await verifyMedia(target.path, track.sizeBytes, track.sha256)) {
        await store
            .into(store.transfers)
            .insertOnConflictUpdate(
              TransfersCompanion.insert(
                id: id,
                trackJson: jsonEncode(track.toJson()),
                state: const Value('downloaded'),
                progress: const Value(1),
                relativePath: Value('media/${cachedMediaName(track)}'),
                error: const Value(null),
              ),
            );
        return AudioSource.uri(Uri.file(target.path));
      }
      await target.delete();
    }
    final wifi = await store.readState('wifiOnly') != false;
    await store
        .into(store.transfers)
        .insertOnConflictUpdate(
          TransfersCompanion.insert(
            id: id,
            trackJson: jsonEncode(track.toJson()),
            taskJson: Value(
              jsonEncode(
                _taskFor(track, individual: true, wifi: wifi).toJson(),
              ),
            ),
            priority: const Value(1),
            state: const Value('streaming'),
            progress: const Value(0),
            relativePath: const Value(null),
            error: const Value(null),
          ),
        );
    // ignore: experimental_member_use
    final source = LockCachingAudioSource(remote, cacheFile: target);
    _streams[id] = source;
    var shown = -1.0;
    _streamProgress[id] = source.downloadProgressStream.listen((progress) {
      _armStall(track);
      if (progress >= 1) {
        unawaited(_adoptStreamed(track));
      } else if (progress - shown >= 0.01) {
        shown = progress;
        unawaited(
          store.updateTransfer(
            id,
            TransfersCompanion(progress: Value(progress)),
          ),
        );
      }
    });
    _armStall(track);
    return source;
  }

  /// Garde [track] pour l’écoute hors connexion, sauf s’il se remplit déjà
  /// pendant l’écoute.
  Future<void> keepOffline(Track track) async {
    if (track.fixture ||
        track.bundled ||
        _streams.containsKey(track.transferId)) {
      return;
    }
    await enqueue([track], individual: true);
  }

  void _armStall(Track track) {
    _stalls.remove(track.transferId)?.cancel();
    _stalls[track.transferId] = Timer(
      streamStallDelay,
      () => unawaited(_handOver(track)),
    );
  }

  void _forgetStream(String id) {
    _streams.remove(id);
    unawaited(_streamProgress.remove(id)?.cancel());
    _stalls.remove(id)?.cancel();
  }

  /// L’écoute en ligne a décroché : le téléchargement en arrière-plan prend
  /// le relais et attend le réseau s’il le faut.
  Future<void> _handOver(Track track) async {
    final id = track.transferId;
    _forgetStream(id);
    final row = await store.transfer(id);
    if (row?.state != 'streaming') return;
    await store.updateTransfer(
      id,
      const TransfersCompanion(state: Value('queued'), progress: Value(0)),
    );
    await pump();
  }

  /// L’écoute a reçu tout le fichier : on le vérifie une fois, puis il
  /// compte comme téléchargé.
  Future<void> _adoptStreamed(Track track) async {
    final id = track.transferId;
    if (!_streams.containsKey(id)) return;
    _forgetStream(id);
    final target = File(_mediaPath(track));
    // La progression atteint 100 % juste avant que le fichier prenne son nom.
    for (var wait = 0; wait < 50 && !await target.exists(); wait++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (await verifyMedia(target.path, track.sizeBytes, track.sha256)) {
      await _markDownloaded(id);
      return;
    }
    if (await target.exists()) await target.delete();
    final row = await store.transfer(id);
    if (row?.state != 'streaming') return;
    await store.updateTransfer(
      id,
      const TransfersCompanion(state: Value('queued'), progress: Value(0)),
    );
    await pump();
  }

  Future<void> _markDownloaded(String id) async {
    final row = await store.transfer(id);
    if (row == null) return;
    final track = Track.fromJson(jsonDecode(row.trackJson));
    await store.updateTransfer(
      id,
      TransfersCompanion(
        state: const Value('downloaded'),
        progress: const Value(1),
        relativePath: Value('media/${cachedMediaName(track)}'),
        error: const Value(null),
      ),
    );
  }

  /// Morceaux laissés par une écoute en ligne interrompue (`.part`) et
  /// types de fichier notés pendant l’écoute (`.mime`).
  static Future<void> _removeStreamLeftovers(Directory media) async {
    try {
      await for (final entry in media.list(followLinks: false)) {
        if (entry is File &&
            (entry.path.endsWith('.part') || entry.path.endsWith('.mime'))) {
          await entry.delete();
        }
      }
    } on FileSystemException {
      return;
    }
  }

  /// Espace libre, ou null quand Android a relancé le service audio avant
  /// l’écran principal : le canal natif n’existe pas encore. Cet état ne doit
  /// ni bloquer le démarrage, ni être pris pour un manque de place.
  static Future<int?> readFreeBytes(MethodChannel channel) async {
    try {
      return await channel.invokeMethod<int>('freeBytes');
    } on MissingPluginException {
      return null;
    }
  }

  Future<void> pump() async {
    if (_pumping) return;
    _pumping = true;
    try {
      final rows = await (store.select(
        store.transfers,
      )..orderBy([(t) => OrderingTerm(expression: t.priority)])).get();
      var available =
          3 -
          rows
              .where(
                (r) => [
                  'downloading',
                  'waitingForNetwork',
                  'verifying',
                ].contains(r.state),
              )
              .length;
      for (final row in rows.where((r) => r.state == 'queued')) {
        if (available <= 0) break;
        final track = Track.fromJson(jsonDecode(row.trackJson));
        final free = await readFreeBytes(storage);
        if (free != null && free < track.sizeBytes + 50 * 1024 * 1024) {
          await store.updateTransfer(
            row.id,
            const TransfersCompanion(
              state: Value('failed'),
              error: Value(
                'Espace insuffisant. Libérez de la place puis relancez.',
              ),
            ),
          );
          continue;
        }
        if (row.taskJson == null) {
          await store.updateTransfer(
            row.id,
            const TransfersCompanion(
              state: Value('failed'),
              error: Value('Tâche à relancer.'),
            ),
          );
          continue;
        }
        final task = DownloadTask.fromJson(jsonDecode(row.taskJson!));
        await store.updateTransfer(
          row.id,
          const TransfersCompanion(state: Value('waitingForNetwork')),
        );
        if (!await engine.enqueue(task)) {
          await store.updateTransfer(
            row.id,
            const TransfersCompanion(
              state: Value('failed'),
              error: Value('Le système a refusé le transfert.'),
            ),
          );
        } else {
          available--;
        }
      }
    } finally {
      _pumping = false;
    }
  }

  Future<void> _handle(TaskUpdate event) async {
    final row = await store.transfer(event.task.taskId);
    if (row == null) return;
    if (event is TaskProgressUpdate && event.progress >= 0) {
      await store.updateTransfer(
        row.id,
        TransfersCompanion(progress: Value(event.progress)),
      );
      return;
    }
    if (event is! TaskStatusUpdate) return;
    if (event.status == TaskStatus.complete) {
      await _complete(event.task, Track.fromJson(jsonDecode(row.trackJson)));
    } else {
      final state = switch (event.status) {
        TaskStatus.enqueued => 'waitingForNetwork',
        TaskStatus.running => 'downloading',
        TaskStatus.paused => 'paused',
        TaskStatus.waitingToRetry => 'waitingForNetwork',
        TaskStatus.canceled => 'cancelled',
        _ => 'failed',
      };
      await store.updateTransfer(
        row.id,
        TransfersCompanion(
          state: Value(state),
          error: Value(
            state == 'failed'
                ? 'Le fichier est indisponible ou le transfert a échoué.'
                : null,
          ),
        ),
      );
    }
    await pump();
  }

  Future<void> _complete(Task task, Track track) async {
    if (!_finishing.add(task.taskId)) return;
    try {
      final relative = 'media/${cachedMediaName(track)}';
      final target = File(p.join(root.path, relative));
      // Native completion can be replayed after process death or reconciliation.
      // The file may also have arrived first, filled while listening.
      if (await verifyMedia(target.path, track.sizeBytes, track.sha256)) {
        try {
          final staged = File(await task.filePath());
          if (await staged.exists()) await staged.delete();
        } on FileSystemException {
          // Un reste dans staging ne gêne pas la lecture.
        }
        await store.updateTransfer(
          task.taskId,
          TransfersCompanion(
            state: const Value('downloaded'),
            progress: const Value(1),
            relativePath: Value(relative),
            error: const Value(null),
          ),
        );
        return;
      }
      await store.updateTransfer(
        task.taskId,
        const TransfersCompanion(state: Value('verifying')),
      );
      final downloaded = await task.filePath();
      if (!await verifyMedia(downloaded, track.sizeBytes, track.sha256)) {
        await store.updateTransfer(
          task.taskId,
          const TransfersCompanion(
            state: Value('failed'),
            error: Value(
              'Taille ou empreinte incorrecte. Fichier non utilisable.',
            ),
          ),
        );
        return;
      }
      if (await target.exists()) await target.delete();
      await File(downloaded).rename(target.path);
      await store.updateTransfer(
        task.taskId,
        TransfersCompanion(
          state: const Value('downloaded'),
          progress: const Value(1),
          relativePath: Value(relative),
          error: const Value(null),
        ),
      );
    } finally {
      _finishing.remove(task.taskId);
    }
  }

  Future<String?> localFile(Track track) async {
    final row = await store.transfer(track.transferId);
    if (row?.state != 'downloaded' || row?.relativePath == null) return null;
    final file = File(p.join(root.path, row!.relativePath!));
    if (!await mediaPresent(file.path, track.sizeBytes)) {
      await store.updateTransfer(
        track.transferId,
        const TransfersCompanion(
          state: Value('failed'),
          error: Value('Fichier local absent ou corrompu.'),
        ),
      );
      return null;
    }
    return file.path;
  }

  Future<void> pause(String id) async {
    final row = await store.transfer(id);
    if (row == null) return;
    if (row.state == 'queued') {
      await store.updateTransfer(
        id,
        const TransfersCompanion(state: Value('paused')),
      );
      return;
    }
    if (row.taskJson == null ||
        !await engine.pause(DownloadTask.fromJson(jsonDecode(row.taskJson!)))) {
      throw StateError(
        'Le système ne peut pas suspendre ce transfert maintenant.',
      );
    }
  }

  Future<void> resume(String id) async {
    final row = await store.transfer(id);
    if (row?.taskJson == null) return;
    final task = DownloadTask.fromJson(jsonDecode(row!.taskJson!));
    if (!await engine.resume(task)) {
      await store.updateTransfer(
        id,
        const TransfersCompanion(state: Value('queued'), progress: Value(0)),
      );
      await pump();
    }
  }

  Future<void> cancel(String id) async {
    final row = await store.transfer(id);
    if (row?.state == 'downloaded') return;
    await engine.cancelTasksWithIds([id]);
    await store.updateTransfer(
      id,
      const TransfersCompanion(state: Value('cancelled')),
    );
    await pump();
  }

  Future<void> export(Track track) async {
    final source = await localFile(track);
    if (source == null ||
        !await verifyMedia(source, track.sizeBytes, track.sha256)) {
      throw StateError('Téléchargez et validez cet audio avant de l’exporter.');
    }
    final temp = await getTemporaryDirectory();
    final directory = await Directory(
      p.join(temp.path, 'exports', track.transferId),
    ).create(recursive: true);
    final extension = p.extension(track.file).isEmpty
        ? '.m4a'
        : p.extension(track.file);
    final copy = await File(source).copy(
      p.join(directory.path, exportName(track.title, extension: extension)),
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            copy.path,
            mimeType: extension == '.mp3' ? 'audio/mpeg' : 'audio/mp4',
          ),
        ],
        title: track.title,
      ),
    );
  }

  Future<void> removeLocal(Track track) async {
    final row = await store.transfer(track.transferId);
    if (row?.relativePath != null) {
      final file = File(p.join(root.path, row!.relativePath!));
      if (await file.exists()) await file.delete();
    }
    await store.updateTransfer(
      track.transferId,
      const TransfersCompanion(
        state: Value('cancelled'),
        progress: Value(0),
        relativePath: Value(null),
        error: Value(null),
        taskJson: Value(null),
      ),
    );
  }

  Future<void> dispose() async {
    for (final id in _streams.keys.toList()) {
      _forgetStream(id);
    }
    await _subscription?.cancel();
  }
}
