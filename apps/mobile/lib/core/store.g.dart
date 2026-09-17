// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'store.dart';

// ignore_for_file: type=lint
class $LocalStatesTable extends LocalStates
    with TableInfo<$LocalStatesTable, LocalState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  LocalState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalState(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $LocalStatesTable createAlias(String alias) {
    return $LocalStatesTable(attachedDatabase, alias);
  }
}

class LocalState extends DataClass implements Insertable<LocalState> {
  final String key;
  final String value;
  const LocalState({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  LocalStatesCompanion toCompanion(bool nullToAbsent) {
    return LocalStatesCompanion(key: Value(key), value: Value(value));
  }

  factory LocalState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalState(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  LocalState copyWith({String? key, String? value}) =>
      LocalState(key: key ?? this.key, value: value ?? this.value);
  LocalState copyWithCompanion(LocalStatesCompanion data) {
    return LocalState(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalState(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalState &&
          other.key == this.key &&
          other.value == this.value);
}

class LocalStatesCompanion extends UpdateCompanion<LocalState> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const LocalStatesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalStatesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<LocalState> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalStatesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return LocalStatesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalStatesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TransfersTable extends Transfers
    with TableInfo<$TransfersTable, Transfer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransfersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackJsonMeta = const VerificationMeta(
    'trackJson',
  );
  @override
  late final GeneratedColumn<String> trackJson = GeneratedColumn<String>(
    'track_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskJsonMeta = const VerificationMeta(
    'taskJson',
  );
  @override
  late final GeneratedColumn<String> taskJson = GeneratedColumn<String>(
    'task_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('queued'),
  );
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<double> progress = GeneratedColumn<double>(
    'progress',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(5),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    trackJson,
    taskJson,
    state,
    progress,
    relativePath,
    error,
    priority,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transfers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Transfer> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('track_json')) {
      context.handle(
        _trackJsonMeta,
        trackJson.isAcceptableOrUnknown(data['track_json']!, _trackJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_trackJsonMeta);
    }
    if (data.containsKey('task_json')) {
      context.handle(
        _taskJsonMeta,
        taskJson.isAcceptableOrUnknown(data['task_json']!, _taskJsonMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    }
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Transfer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Transfer(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      trackJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_json'],
      )!,
      taskJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_json'],
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress'],
      )!,
      relativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_path'],
      ),
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
    );
  }

  @override
  $TransfersTable createAlias(String alias) {
    return $TransfersTable(attachedDatabase, alias);
  }
}

class Transfer extends DataClass implements Insertable<Transfer> {
  final String id;
  final String trackJson;
  final String? taskJson;
  final String state;
  final double progress;
  final String? relativePath;
  final String? error;
  final int priority;
  const Transfer({
    required this.id,
    required this.trackJson,
    this.taskJson,
    required this.state,
    required this.progress,
    this.relativePath,
    this.error,
    required this.priority,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['track_json'] = Variable<String>(trackJson);
    if (!nullToAbsent || taskJson != null) {
      map['task_json'] = Variable<String>(taskJson);
    }
    map['state'] = Variable<String>(state);
    map['progress'] = Variable<double>(progress);
    if (!nullToAbsent || relativePath != null) {
      map['relative_path'] = Variable<String>(relativePath);
    }
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    map['priority'] = Variable<int>(priority);
    return map;
  }

  TransfersCompanion toCompanion(bool nullToAbsent) {
    return TransfersCompanion(
      id: Value(id),
      trackJson: Value(trackJson),
      taskJson: taskJson == null && nullToAbsent
          ? const Value.absent()
          : Value(taskJson),
      state: Value(state),
      progress: Value(progress),
      relativePath: relativePath == null && nullToAbsent
          ? const Value.absent()
          : Value(relativePath),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      priority: Value(priority),
    );
  }

  factory Transfer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Transfer(
      id: serializer.fromJson<String>(json['id']),
      trackJson: serializer.fromJson<String>(json['trackJson']),
      taskJson: serializer.fromJson<String?>(json['taskJson']),
      state: serializer.fromJson<String>(json['state']),
      progress: serializer.fromJson<double>(json['progress']),
      relativePath: serializer.fromJson<String?>(json['relativePath']),
      error: serializer.fromJson<String?>(json['error']),
      priority: serializer.fromJson<int>(json['priority']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'trackJson': serializer.toJson<String>(trackJson),
      'taskJson': serializer.toJson<String?>(taskJson),
      'state': serializer.toJson<String>(state),
      'progress': serializer.toJson<double>(progress),
      'relativePath': serializer.toJson<String?>(relativePath),
      'error': serializer.toJson<String?>(error),
      'priority': serializer.toJson<int>(priority),
    };
  }

  Transfer copyWith({
    String? id,
    String? trackJson,
    Value<String?> taskJson = const Value.absent(),
    String? state,
    double? progress,
    Value<String?> relativePath = const Value.absent(),
    Value<String?> error = const Value.absent(),
    int? priority,
  }) => Transfer(
    id: id ?? this.id,
    trackJson: trackJson ?? this.trackJson,
    taskJson: taskJson.present ? taskJson.value : this.taskJson,
    state: state ?? this.state,
    progress: progress ?? this.progress,
    relativePath: relativePath.present ? relativePath.value : this.relativePath,
    error: error.present ? error.value : this.error,
    priority: priority ?? this.priority,
  );
  Transfer copyWithCompanion(TransfersCompanion data) {
    return Transfer(
      id: data.id.present ? data.id.value : this.id,
      trackJson: data.trackJson.present ? data.trackJson.value : this.trackJson,
      taskJson: data.taskJson.present ? data.taskJson.value : this.taskJson,
      state: data.state.present ? data.state.value : this.state,
      progress: data.progress.present ? data.progress.value : this.progress,
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      error: data.error.present ? data.error.value : this.error,
      priority: data.priority.present ? data.priority.value : this.priority,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transfer(')
          ..write('id: $id, ')
          ..write('trackJson: $trackJson, ')
          ..write('taskJson: $taskJson, ')
          ..write('state: $state, ')
          ..write('progress: $progress, ')
          ..write('relativePath: $relativePath, ')
          ..write('error: $error, ')
          ..write('priority: $priority')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    trackJson,
    taskJson,
    state,
    progress,
    relativePath,
    error,
    priority,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transfer &&
          other.id == this.id &&
          other.trackJson == this.trackJson &&
          other.taskJson == this.taskJson &&
          other.state == this.state &&
          other.progress == this.progress &&
          other.relativePath == this.relativePath &&
          other.error == this.error &&
          other.priority == this.priority);
}

class TransfersCompanion extends UpdateCompanion<Transfer> {
  final Value<String> id;
  final Value<String> trackJson;
  final Value<String?> taskJson;
  final Value<String> state;
  final Value<double> progress;
  final Value<String?> relativePath;
  final Value<String?> error;
  final Value<int> priority;
  final Value<int> rowid;
  const TransfersCompanion({
    this.id = const Value.absent(),
    this.trackJson = const Value.absent(),
    this.taskJson = const Value.absent(),
    this.state = const Value.absent(),
    this.progress = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.error = const Value.absent(),
    this.priority = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransfersCompanion.insert({
    required String id,
    required String trackJson,
    this.taskJson = const Value.absent(),
    this.state = const Value.absent(),
    this.progress = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.error = const Value.absent(),
    this.priority = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       trackJson = Value(trackJson);
  static Insertable<Transfer> custom({
    Expression<String>? id,
    Expression<String>? trackJson,
    Expression<String>? taskJson,
    Expression<String>? state,
    Expression<double>? progress,
    Expression<String>? relativePath,
    Expression<String>? error,
    Expression<int>? priority,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trackJson != null) 'track_json': trackJson,
      if (taskJson != null) 'task_json': taskJson,
      if (state != null) 'state': state,
      if (progress != null) 'progress': progress,
      if (relativePath != null) 'relative_path': relativePath,
      if (error != null) 'error': error,
      if (priority != null) 'priority': priority,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransfersCompanion copyWith({
    Value<String>? id,
    Value<String>? trackJson,
    Value<String?>? taskJson,
    Value<String>? state,
    Value<double>? progress,
    Value<String?>? relativePath,
    Value<String?>? error,
    Value<int>? priority,
    Value<int>? rowid,
  }) {
    return TransfersCompanion(
      id: id ?? this.id,
      trackJson: trackJson ?? this.trackJson,
      taskJson: taskJson ?? this.taskJson,
      state: state ?? this.state,
      progress: progress ?? this.progress,
      relativePath: relativePath ?? this.relativePath,
      error: error ?? this.error,
      priority: priority ?? this.priority,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (trackJson.present) {
      map['track_json'] = Variable<String>(trackJson.value);
    }
    if (taskJson.present) {
      map['task_json'] = Variable<String>(taskJson.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (progress.present) {
      map['progress'] = Variable<double>(progress.value);
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransfersCompanion(')
          ..write('id: $id, ')
          ..write('trackJson: $trackJson, ')
          ..write('taskJson: $taskJson, ')
          ..write('state: $state, ')
          ..write('progress: $progress, ')
          ..write('relativePath: $relativePath, ')
          ..write('error: $error, ')
          ..write('priority: $priority, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppStore extends GeneratedDatabase {
  _$AppStore(QueryExecutor e) : super(e);
  $AppStoreManager get managers => $AppStoreManager(this);
  late final $LocalStatesTable localStates = $LocalStatesTable(this);
  late final $TransfersTable transfers = $TransfersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [localStates, transfers];
}

typedef $$LocalStatesTableCreateCompanionBuilder =
    LocalStatesCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$LocalStatesTableUpdateCompanionBuilder =
    LocalStatesCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$LocalStatesTableFilterComposer
    extends Composer<_$AppStore, $LocalStatesTable> {
  $$LocalStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalStatesTableOrderingComposer
    extends Composer<_$AppStore, $LocalStatesTable> {
  $$LocalStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalStatesTableAnnotationComposer
    extends Composer<_$AppStore, $LocalStatesTable> {
  $$LocalStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$LocalStatesTableTableManager
    extends
        RootTableManager<
          _$AppStore,
          $LocalStatesTable,
          LocalState,
          $$LocalStatesTableFilterComposer,
          $$LocalStatesTableOrderingComposer,
          $$LocalStatesTableAnnotationComposer,
          $$LocalStatesTableCreateCompanionBuilder,
          $$LocalStatesTableUpdateCompanionBuilder,
          (
            LocalState,
            BaseReferences<_$AppStore, $LocalStatesTable, LocalState>,
          ),
          LocalState,
          PrefetchHooks Function()
        > {
  $$LocalStatesTableTableManager(_$AppStore db, $LocalStatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => LocalStatesCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => LocalStatesCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalStatesTable, LocalState>(table),
                  BaseReferences<_$AppStore, $LocalStatesTable, LocalState>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppStore,
      $LocalStatesTable,
      LocalState,
      $$LocalStatesTableFilterComposer,
      $$LocalStatesTableOrderingComposer,
      $$LocalStatesTableAnnotationComposer,
      $$LocalStatesTableCreateCompanionBuilder,
      $$LocalStatesTableUpdateCompanionBuilder,
      (LocalState, BaseReferences<_$AppStore, $LocalStatesTable, LocalState>),
      LocalState,
      PrefetchHooks Function()
    >;
typedef $$TransfersTableCreateCompanionBuilder = TransfersCompanion Function({
  required String id,
  required String trackJson,
  Value<String?> taskJson,
  Value<String> state,
  Value<double> progress,
  Value<String?> relativePath,
  Value<String?> error,
  Value<int> priority,
  Value<int> rowid,
});
typedef $$TransfersTableUpdateCompanionBuilder = TransfersCompanion Function({
  Value<String> id,
  Value<String> trackJson,
  Value<String?> taskJson,
  Value<String> state,
  Value<double> progress,
  Value<String?> relativePath,
  Value<String?> error,
  Value<int> priority,
  Value<int> rowid,
});

class $$TransfersTableFilterComposer
    extends Composer<_$AppStore, $TransfersTable> {
  $$TransfersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackJson => $composableBuilder(
    column: $table.trackJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskJson => $composableBuilder(
    column: $table.taskJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TransfersTableOrderingComposer
    extends Composer<_$AppStore, $TransfersTable> {
  $$TransfersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackJson => $composableBuilder(
    column: $table.trackJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskJson => $composableBuilder(
    column: $table.taskJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TransfersTableAnnotationComposer
    extends Composer<_$AppStore, $TransfersTable> {
  $$TransfersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get trackJson =>
      $composableBuilder(column: $table.trackJson, builder: (column) => column);

  GeneratedColumn<String> get taskJson =>
      $composableBuilder(column: $table.taskJson, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<double> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);
}

class $$TransfersTableTableManager
    extends
        RootTableManager<
          _$AppStore,
          $TransfersTable,
          Transfer,
          $$TransfersTableFilterComposer,
          $$TransfersTableOrderingComposer,
          $$TransfersTableAnnotationComposer,
          $$TransfersTableCreateCompanionBuilder,
          $$TransfersTableUpdateCompanionBuilder,
          (Transfer, BaseReferences<_$AppStore, $TransfersTable, Transfer>),
          Transfer,
          PrefetchHooks Function()
        > {
  $$TransfersTableTableManager(_$AppStore db, $TransfersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransfersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransfersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransfersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> trackJson = const Value.absent(),
                Value<String?> taskJson = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<String?> relativePath = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransfersCompanion(
                id: id,
                trackJson: trackJson,
                taskJson: taskJson,
                state: state,
                progress: progress,
                relativePath: relativePath,
                error: error,
                priority: priority,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String trackJson,
                Value<String?> taskJson = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<String?> relativePath = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransfersCompanion.insert(
                id: id,
                trackJson: trackJson,
                taskJson: taskJson,
                state: state,
                progress: progress,
                relativePath: relativePath,
                error: error,
                priority: priority,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TransfersTable, Transfer>(table),
                  BaseReferences<_$AppStore, $TransfersTable, Transfer>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TransfersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppStore,
      $TransfersTable,
      Transfer,
      $$TransfersTableFilterComposer,
      $$TransfersTableOrderingComposer,
      $$TransfersTableAnnotationComposer,
      $$TransfersTableCreateCompanionBuilder,
      $$TransfersTableUpdateCompanionBuilder,
      (Transfer, BaseReferences<_$AppStore, $TransfersTable, Transfer>),
      Transfer,
      PrefetchHooks Function()
    >;

class $AppStoreManager {
  final _$AppStore _db;
  $AppStoreManager(this._db);
  $$LocalStatesTableTableManager get localStates =>
      $$LocalStatesTableTableManager(_db, _db.localStates);
  $$TransfersTableTableManager get transfers =>
      $$TransfersTableTableManager(_db, _db.transfers);
}
