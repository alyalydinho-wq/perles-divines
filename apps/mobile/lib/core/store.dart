import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'store.g.dart';

class LocalStates extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

class Transfers extends Table {
  TextColumn get id => text()();
  TextColumn get trackJson => text()();
  TextColumn get taskJson => text().nullable()();
  TextColumn get state => text().withDefault(const Constant('queued'))();
  RealColumn get progress => real().withDefault(const Constant(0))();
  TextColumn get relativePath => text().nullable()();
  TextColumn get error => text().nullable()();
  IntColumn get priority => integer().withDefault(const Constant(5))();
  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [LocalStates, Transfers])
class AppStore extends _$AppStore {
  AppStore([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'perles_divines'));
  @override
  int get schemaVersion => 1;
  Future<dynamic> readState(String key) async {
    final row = await (select(
      localStates,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row == null ? null : jsonDecode(row.value);
  }

  Future<void> writeState(String key, Object? value) => into(localStates)
      .insertOnConflictUpdate(
        LocalStatesCompanion.insert(key: key, value: jsonEncode(value)),
      );
  Stream<List<Transfer>> watchTransfers() => (select(
    transfers,
  )..orderBy([(t) => OrderingTerm(expression: t.priority)])).watch();
  Future<Transfer?> transfer(String id) =>
      (select(transfers)..where((t) => t.id.equals(id))).getSingleOrNull();
  Future<void> updateTransfer(String id, TransfersCompanion value) =>
      (update(transfers)..where((t) => t.id.equals(id))).write(value);
}
