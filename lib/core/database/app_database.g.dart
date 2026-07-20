// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String value;
  final DateTime updatedAt;
  const AppSetting({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AppSetting copyWith({String? key, String? value, DateTime? updatedAt}) =>
      AppSetting(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value),
       updatedAt = Value(updatedAt);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
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
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UsageCacheTable extends UsageCache
    with TableInfo<$UsageCacheTable, UsageCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsageCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _usageDateMeta = const VerificationMeta(
    'usageDate',
  );
  @override
  late final GeneratedColumn<DateTime> usageDate = GeneratedColumn<DateTime>(
    'usage_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dailyLimitMeta = const VerificationMeta(
    'dailyLimit',
  );
  @override
  late final GeneratedColumn<int> dailyLimit = GeneratedColumn<int>(
    'daily_limit',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _usedCountMeta = const VerificationMeta(
    'usedCount',
  );
  @override
  late final GeneratedColumn<int> usedCount = GeneratedColumn<int>(
    'used_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remainingCountMeta = const VerificationMeta(
    'remainingCount',
  );
  @override
  late final GeneratedColumn<int> remainingCount = GeneratedColumn<int>(
    'remaining_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resetsAtMeta = const VerificationMeta(
    'resetsAt',
  );
  @override
  late final GeneratedColumn<DateTime> resetsAt = GeneratedColumn<DateTime>(
    'resets_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    usageDate,
    dailyLimit,
    usedCount,
    remainingCount,
    resetsAt,
    lastSyncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'usage_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<UsageCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('usage_date')) {
      context.handle(
        _usageDateMeta,
        usageDate.isAcceptableOrUnknown(data['usage_date']!, _usageDateMeta),
      );
    } else if (isInserting) {
      context.missing(_usageDateMeta);
    }
    if (data.containsKey('daily_limit')) {
      context.handle(
        _dailyLimitMeta,
        dailyLimit.isAcceptableOrUnknown(data['daily_limit']!, _dailyLimitMeta),
      );
    } else if (isInserting) {
      context.missing(_dailyLimitMeta);
    }
    if (data.containsKey('used_count')) {
      context.handle(
        _usedCountMeta,
        usedCount.isAcceptableOrUnknown(data['used_count']!, _usedCountMeta),
      );
    } else if (isInserting) {
      context.missing(_usedCountMeta);
    }
    if (data.containsKey('remaining_count')) {
      context.handle(
        _remainingCountMeta,
        remainingCount.isAcceptableOrUnknown(
          data['remaining_count']!,
          _remainingCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_remainingCountMeta);
    }
    if (data.containsKey('resets_at')) {
      context.handle(
        _resetsAtMeta,
        resetsAt.isAcceptableOrUnknown(data['resets_at']!, _resetsAtMeta),
      );
    } else if (isInserting) {
      context.missing(_resetsAtMeta);
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {usageDate};
  @override
  UsageCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UsageCacheData(
      usageDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}usage_date'],
      )!,
      dailyLimit: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}daily_limit'],
      )!,
      usedCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}used_count'],
      )!,
      remainingCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remaining_count'],
      )!,
      resetsAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}resets_at'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
    );
  }

  @override
  $UsageCacheTable createAlias(String alias) {
    return $UsageCacheTable(attachedDatabase, alias);
  }
}

class UsageCacheData extends DataClass implements Insertable<UsageCacheData> {
  final DateTime usageDate;
  final int dailyLimit;
  final int usedCount;
  final int remainingCount;
  final DateTime resetsAt;
  final DateTime? lastSyncedAt;
  const UsageCacheData({
    required this.usageDate,
    required this.dailyLimit,
    required this.usedCount,
    required this.remainingCount,
    required this.resetsAt,
    this.lastSyncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['usage_date'] = Variable<DateTime>(usageDate);
    map['daily_limit'] = Variable<int>(dailyLimit);
    map['used_count'] = Variable<int>(usedCount);
    map['remaining_count'] = Variable<int>(remainingCount);
    map['resets_at'] = Variable<DateTime>(resetsAt);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    return map;
  }

  UsageCacheCompanion toCompanion(bool nullToAbsent) {
    return UsageCacheCompanion(
      usageDate: Value(usageDate),
      dailyLimit: Value(dailyLimit),
      usedCount: Value(usedCount),
      remainingCount: Value(remainingCount),
      resetsAt: Value(resetsAt),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
    );
  }

  factory UsageCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UsageCacheData(
      usageDate: serializer.fromJson<DateTime>(json['usageDate']),
      dailyLimit: serializer.fromJson<int>(json['dailyLimit']),
      usedCount: serializer.fromJson<int>(json['usedCount']),
      remainingCount: serializer.fromJson<int>(json['remainingCount']),
      resetsAt: serializer.fromJson<DateTime>(json['resetsAt']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'usageDate': serializer.toJson<DateTime>(usageDate),
      'dailyLimit': serializer.toJson<int>(dailyLimit),
      'usedCount': serializer.toJson<int>(usedCount),
      'remainingCount': serializer.toJson<int>(remainingCount),
      'resetsAt': serializer.toJson<DateTime>(resetsAt),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
    };
  }

  UsageCacheData copyWith({
    DateTime? usageDate,
    int? dailyLimit,
    int? usedCount,
    int? remainingCount,
    DateTime? resetsAt,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
  }) => UsageCacheData(
    usageDate: usageDate ?? this.usageDate,
    dailyLimit: dailyLimit ?? this.dailyLimit,
    usedCount: usedCount ?? this.usedCount,
    remainingCount: remainingCount ?? this.remainingCount,
    resetsAt: resetsAt ?? this.resetsAt,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
  );
  UsageCacheData copyWithCompanion(UsageCacheCompanion data) {
    return UsageCacheData(
      usageDate: data.usageDate.present ? data.usageDate.value : this.usageDate,
      dailyLimit: data.dailyLimit.present
          ? data.dailyLimit.value
          : this.dailyLimit,
      usedCount: data.usedCount.present ? data.usedCount.value : this.usedCount,
      remainingCount: data.remainingCount.present
          ? data.remainingCount.value
          : this.remainingCount,
      resetsAt: data.resetsAt.present ? data.resetsAt.value : this.resetsAt,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UsageCacheData(')
          ..write('usageDate: $usageDate, ')
          ..write('dailyLimit: $dailyLimit, ')
          ..write('usedCount: $usedCount, ')
          ..write('remainingCount: $remainingCount, ')
          ..write('resetsAt: $resetsAt, ')
          ..write('lastSyncedAt: $lastSyncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    usageDate,
    dailyLimit,
    usedCount,
    remainingCount,
    resetsAt,
    lastSyncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UsageCacheData &&
          other.usageDate == this.usageDate &&
          other.dailyLimit == this.dailyLimit &&
          other.usedCount == this.usedCount &&
          other.remainingCount == this.remainingCount &&
          other.resetsAt == this.resetsAt &&
          other.lastSyncedAt == this.lastSyncedAt);
}

class UsageCacheCompanion extends UpdateCompanion<UsageCacheData> {
  final Value<DateTime> usageDate;
  final Value<int> dailyLimit;
  final Value<int> usedCount;
  final Value<int> remainingCount;
  final Value<DateTime> resetsAt;
  final Value<DateTime?> lastSyncedAt;
  final Value<int> rowid;
  const UsageCacheCompanion({
    this.usageDate = const Value.absent(),
    this.dailyLimit = const Value.absent(),
    this.usedCount = const Value.absent(),
    this.remainingCount = const Value.absent(),
    this.resetsAt = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UsageCacheCompanion.insert({
    required DateTime usageDate,
    required int dailyLimit,
    required int usedCount,
    required int remainingCount,
    required DateTime resetsAt,
    this.lastSyncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : usageDate = Value(usageDate),
       dailyLimit = Value(dailyLimit),
       usedCount = Value(usedCount),
       remainingCount = Value(remainingCount),
       resetsAt = Value(resetsAt);
  static Insertable<UsageCacheData> custom({
    Expression<DateTime>? usageDate,
    Expression<int>? dailyLimit,
    Expression<int>? usedCount,
    Expression<int>? remainingCount,
    Expression<DateTime>? resetsAt,
    Expression<DateTime>? lastSyncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (usageDate != null) 'usage_date': usageDate,
      if (dailyLimit != null) 'daily_limit': dailyLimit,
      if (usedCount != null) 'used_count': usedCount,
      if (remainingCount != null) 'remaining_count': remainingCount,
      if (resetsAt != null) 'resets_at': resetsAt,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UsageCacheCompanion copyWith({
    Value<DateTime>? usageDate,
    Value<int>? dailyLimit,
    Value<int>? usedCount,
    Value<int>? remainingCount,
    Value<DateTime>? resetsAt,
    Value<DateTime?>? lastSyncedAt,
    Value<int>? rowid,
  }) {
    return UsageCacheCompanion(
      usageDate: usageDate ?? this.usageDate,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      usedCount: usedCount ?? this.usedCount,
      remainingCount: remainingCount ?? this.remainingCount,
      resetsAt: resetsAt ?? this.resetsAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (usageDate.present) {
      map['usage_date'] = Variable<DateTime>(usageDate.value);
    }
    if (dailyLimit.present) {
      map['daily_limit'] = Variable<int>(dailyLimit.value);
    }
    if (usedCount.present) {
      map['used_count'] = Variable<int>(usedCount.value);
    }
    if (remainingCount.present) {
      map['remaining_count'] = Variable<int>(remainingCount.value);
    }
    if (resetsAt.present) {
      map['resets_at'] = Variable<DateTime>(resetsAt.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsageCacheCompanion(')
          ..write('usageDate: $usageDate, ')
          ..write('dailyLimit: $dailyLimit, ')
          ..write('usedCount: $usedCount, ')
          ..write('remainingCount: $remainingCount, ')
          ..write('resetsAt: $resetsAt, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $UsageCacheTable usageCache = $UsageCacheTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [appSettings, usageCache];
}

typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
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

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
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

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;
typedef $$UsageCacheTableCreateCompanionBuilder =
    UsageCacheCompanion Function({
      required DateTime usageDate,
      required int dailyLimit,
      required int usedCount,
      required int remainingCount,
      required DateTime resetsAt,
      Value<DateTime?> lastSyncedAt,
      Value<int> rowid,
    });
typedef $$UsageCacheTableUpdateCompanionBuilder =
    UsageCacheCompanion Function({
      Value<DateTime> usageDate,
      Value<int> dailyLimit,
      Value<int> usedCount,
      Value<int> remainingCount,
      Value<DateTime> resetsAt,
      Value<DateTime?> lastSyncedAt,
      Value<int> rowid,
    });

class $$UsageCacheTableFilterComposer
    extends Composer<_$AppDatabase, $UsageCacheTable> {
  $$UsageCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get usageDate => $composableBuilder(
    column: $table.usageDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dailyLimit => $composableBuilder(
    column: $table.dailyLimit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get usedCount => $composableBuilder(
    column: $table.usedCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remainingCount => $composableBuilder(
    column: $table.remainingCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get resetsAt => $composableBuilder(
    column: $table.resetsAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UsageCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $UsageCacheTable> {
  $$UsageCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get usageDate => $composableBuilder(
    column: $table.usageDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dailyLimit => $composableBuilder(
    column: $table.dailyLimit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get usedCount => $composableBuilder(
    column: $table.usedCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remainingCount => $composableBuilder(
    column: $table.remainingCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get resetsAt => $composableBuilder(
    column: $table.resetsAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsageCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $UsageCacheTable> {
  $$UsageCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get usageDate =>
      $composableBuilder(column: $table.usageDate, builder: (column) => column);

  GeneratedColumn<int> get dailyLimit => $composableBuilder(
    column: $table.dailyLimit,
    builder: (column) => column,
  );

  GeneratedColumn<int> get usedCount =>
      $composableBuilder(column: $table.usedCount, builder: (column) => column);

  GeneratedColumn<int> get remainingCount => $composableBuilder(
    column: $table.remainingCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get resetsAt =>
      $composableBuilder(column: $table.resetsAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );
}

class $$UsageCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UsageCacheTable,
          UsageCacheData,
          $$UsageCacheTableFilterComposer,
          $$UsageCacheTableOrderingComposer,
          $$UsageCacheTableAnnotationComposer,
          $$UsageCacheTableCreateCompanionBuilder,
          $$UsageCacheTableUpdateCompanionBuilder,
          (
            UsageCacheData,
            BaseReferences<_$AppDatabase, $UsageCacheTable, UsageCacheData>,
          ),
          UsageCacheData,
          PrefetchHooks Function()
        > {
  $$UsageCacheTableTableManager(_$AppDatabase db, $UsageCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsageCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsageCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsageCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> usageDate = const Value.absent(),
                Value<int> dailyLimit = const Value.absent(),
                Value<int> usedCount = const Value.absent(),
                Value<int> remainingCount = const Value.absent(),
                Value<DateTime> resetsAt = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsageCacheCompanion(
                usageDate: usageDate,
                dailyLimit: dailyLimit,
                usedCount: usedCount,
                remainingCount: remainingCount,
                resetsAt: resetsAt,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required DateTime usageDate,
                required int dailyLimit,
                required int usedCount,
                required int remainingCount,
                required DateTime resetsAt,
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsageCacheCompanion.insert(
                usageDate: usageDate,
                dailyLimit: dailyLimit,
                usedCount: usedCount,
                remainingCount: remainingCount,
                resetsAt: resetsAt,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UsageCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UsageCacheTable,
      UsageCacheData,
      $$UsageCacheTableFilterComposer,
      $$UsageCacheTableOrderingComposer,
      $$UsageCacheTableAnnotationComposer,
      $$UsageCacheTableCreateCompanionBuilder,
      $$UsageCacheTableUpdateCompanionBuilder,
      (
        UsageCacheData,
        BaseReferences<_$AppDatabase, $UsageCacheTable, UsageCacheData>,
      ),
      UsageCacheData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$UsageCacheTableTableManager get usageCache =>
      $$UsageCacheTableTableManager(_db, _db.usageCache);
}
