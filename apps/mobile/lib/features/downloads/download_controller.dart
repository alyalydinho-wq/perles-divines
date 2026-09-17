import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:background_downloader/background_downloader.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/store.dart';
import '../../core/track.dart';

Future<bool> verifyMedia(String path, int size, String expectedHash) =>
    Isolate.run(() async {
      final file = File(path);
      if (!await file.exists() || await file.length() != size) return false;
      return (await sha256.bind(file.openRead()).first).toString() ==
          expectedHash;
    });

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
  Future<void> initialize() async {
    root = await getApplicationSupportDirectory();
    await engine.configure(globalConfig: (Config.holdingQueue, (3, 3, 3)));
    await Directory(p.join(root.path, 'media')).create(recursive: true);
    await storage.invokeMethod('excludeBackup', {
      'path': p.join(root.path, 'media'),
    });
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
      final finalPath = p.join(
        root.path,
        'media',
        '${track.transferId}-${track.sha256}.mp3',
      );
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
        final task = DownloadTask(
          taskId: track.transferId,
          url: '$baseUrl/${track.file}',
          filename: '${track.transferId}.part',
          directory: 'staging',
          baseDirectory: BaseDirectory.applicationSupport,
          updates: Updates.statusAndProgress,
          allowPause: true,
          requiresWiFi: wifi,
          retries: 3,
          priority: individual ? 1 : 5,
          displayName: track.title,
        );
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
        final free = await storage.invokeMethod<int>('freeBytes') ?? 0;
        if (free < track.sizeBytes + 50 * 1024 * 1024) {
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
      final relative = 'media/${track.transferId}-${track.sha256}.mp3';
      final target = File(p.join(root.path, relative));
      // Native completion can be replayed after process death or reconciliation.
      if (await verifyMedia(target.path, track.sizeBytes, track.sha256)) {
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
    if (!await verifyMedia(file.path, track.sizeBytes, track.sha256)) {
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
      throw StateError('Téléchargez et validez ce MP3 avant de l’exporter.');
    }
    final temp = await getTemporaryDirectory();
    final directory = await Directory(
      p.join(temp.path, 'exports', track.transferId),
    ).create(recursive: true);
    final copy = await File(source)
        .copy(p.join(directory.path, exportName(track.title)));
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(copy.path, mimeType: 'audio/mpeg')],
        title: track.title,
      ),
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
  }
}
