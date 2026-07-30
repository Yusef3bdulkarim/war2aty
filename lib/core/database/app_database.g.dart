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

class $DocumentsTable extends Documents
    with TableInfo<$DocumentsTable, DocumentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DocumentCategory, String>
  category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<DocumentCategory>($DocumentsTable.$convertercategory);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindConfidenceMeta = const VerificationMeta(
    'kindConfidence',
  );
  @override
  late final GeneratedColumn<String> kindConfidence = GeneratedColumn<String>(
    'kind_confidence',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryShortMeta = const VerificationMeta(
    'summaryShort',
  );
  @override
  late final GeneratedColumn<String> summaryShort = GeneratedColumn<String>(
    'summary_short',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryDetailedMeta = const VerificationMeta(
    'summaryDetailed',
  );
  @override
  late final GeneratedColumn<String> summaryDetailed = GeneratedColumn<String>(
    'summary_detailed',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _extractedTextMeta = const VerificationMeta(
    'extractedText',
  );
  @override
  late final GeneratedColumn<String> extractedText = GeneratedColumn<String>(
    'extracted_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DocumentStorageMode, String>
  storageMode = GeneratedColumn<String>(
    'storage_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<DocumentStorageMode>($DocumentsTable.$converterstorageMode);
  static const VerificationMeta _encryptedImagePathMeta =
      const VerificationMeta('encryptedImagePath');
  @override
  late final GeneratedColumn<String> encryptedImagePath =
      GeneratedColumn<String>(
        'encrypted_image_path',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _savedAtMeta = const VerificationMeta(
    'savedAt',
  );
  @override
  late final GeneratedColumn<DateTime> savedAt = GeneratedColumn<DateTime>(
    'saved_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
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
  List<GeneratedColumn> get $columns => [
    id,
    title,
    category,
    kind,
    status,
    kindConfidence,
    summaryShort,
    summaryDetailed,
    extractedText,
    storageMode,
    encryptedImagePath,
    note,
    sessionId,
    savedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'documents';
  @override
  VerificationContext validateIntegrity(
    Insertable<DocumentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('kind_confidence')) {
      context.handle(
        _kindConfidenceMeta,
        kindConfidence.isAcceptableOrUnknown(
          data['kind_confidence']!,
          _kindConfidenceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_kindConfidenceMeta);
    }
    if (data.containsKey('summary_short')) {
      context.handle(
        _summaryShortMeta,
        summaryShort.isAcceptableOrUnknown(
          data['summary_short']!,
          _summaryShortMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_summaryShortMeta);
    }
    if (data.containsKey('summary_detailed')) {
      context.handle(
        _summaryDetailedMeta,
        summaryDetailed.isAcceptableOrUnknown(
          data['summary_detailed']!,
          _summaryDetailedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_summaryDetailedMeta);
    }
    if (data.containsKey('extracted_text')) {
      context.handle(
        _extractedTextMeta,
        extractedText.isAcceptableOrUnknown(
          data['extracted_text']!,
          _extractedTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_extractedTextMeta);
    }
    if (data.containsKey('encrypted_image_path')) {
      context.handle(
        _encryptedImagePathMeta,
        encryptedImagePath.isAcceptableOrUnknown(
          data['encrypted_image_path']!,
          _encryptedImagePathMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('saved_at')) {
      context.handle(
        _savedAtMeta,
        savedAt.isAcceptableOrUnknown(data['saved_at']!, _savedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_savedAtMeta);
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DocumentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DocumentRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      category: $DocumentsTable.$convertercategory.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}category'],
        )!,
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      kindConfidence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind_confidence'],
      )!,
      summaryShort: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary_short'],
      )!,
      summaryDetailed: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary_detailed'],
      )!,
      extractedText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extracted_text'],
      )!,
      storageMode: $DocumentsTable.$converterstorageMode.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}storage_mode'],
        )!,
      ),
      encryptedImagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_image_path'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      savedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}saved_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DocumentsTable createAlias(String alias) {
    return $DocumentsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DocumentCategory, String, String>
  $convertercategory = const EnumNameConverter<DocumentCategory>(
    DocumentCategory.values,
  );
  static JsonTypeConverter2<DocumentStorageMode, String, String>
  $converterstorageMode = const EnumNameConverter<DocumentStorageMode>(
    DocumentStorageMode.values,
  );
}

class DocumentRow extends DataClass implements Insertable<DocumentRow> {
  /// Client-generated identifier — also what F09 links a reminder to.
  final String id;

  /// Arabic display title, editable by the user (F08-T10).
  final String title;

  /// Coarse category behind Home's recent strip and the list filters.
  final DocumentCategory category;

  /// `DocumentKind` name, e.g. `invoice`.
  final String kind;

  /// `AnalysisStatus` name — `partial` still shows the review banner on a
  /// saved document, exactly as it did on the result screen.
  final String status;

  /// `ConfidenceBand` name for [kind] and [title].
  final String kindConfidence;

  /// One-line «الخلاصة السريعة».
  final String summaryShort;

  /// The full explanation, also what the audio reader speaks.
  final String summaryDetailed;

  /// The normalized OCR text the analysis was built from (UX §5.12).
  final String extractedText;

  /// Result-only or result-plus-image. The default is result-only.
  final DocumentStorageMode storageMode;

  /// Path to the encrypted picture, or `null` in result-only mode.
  final String? encryptedImagePath;

  /// The user's own note — «ملاحظتي» (F08-T09). `null` until they write one.
  final String? note;

  /// The capture session this came from. A per-run id, not a user identifier.
  final String sessionId;
  final DateTime savedAt;

  /// Last edit to title, category, note or stored image.
  final DateTime updatedAt;
  const DocumentRow({
    required this.id,
    required this.title,
    required this.category,
    required this.kind,
    required this.status,
    required this.kindConfidence,
    required this.summaryShort,
    required this.summaryDetailed,
    required this.extractedText,
    required this.storageMode,
    this.encryptedImagePath,
    this.note,
    required this.sessionId,
    required this.savedAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    {
      map['category'] = Variable<String>(
        $DocumentsTable.$convertercategory.toSql(category),
      );
    }
    map['kind'] = Variable<String>(kind);
    map['status'] = Variable<String>(status);
    map['kind_confidence'] = Variable<String>(kindConfidence);
    map['summary_short'] = Variable<String>(summaryShort);
    map['summary_detailed'] = Variable<String>(summaryDetailed);
    map['extracted_text'] = Variable<String>(extractedText);
    {
      map['storage_mode'] = Variable<String>(
        $DocumentsTable.$converterstorageMode.toSql(storageMode),
      );
    }
    if (!nullToAbsent || encryptedImagePath != null) {
      map['encrypted_image_path'] = Variable<String>(encryptedImagePath);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['session_id'] = Variable<String>(sessionId);
    map['saved_at'] = Variable<DateTime>(savedAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DocumentsCompanion toCompanion(bool nullToAbsent) {
    return DocumentsCompanion(
      id: Value(id),
      title: Value(title),
      category: Value(category),
      kind: Value(kind),
      status: Value(status),
      kindConfidence: Value(kindConfidence),
      summaryShort: Value(summaryShort),
      summaryDetailed: Value(summaryDetailed),
      extractedText: Value(extractedText),
      storageMode: Value(storageMode),
      encryptedImagePath: encryptedImagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(encryptedImagePath),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      sessionId: Value(sessionId),
      savedAt: Value(savedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DocumentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DocumentRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      category: $DocumentsTable.$convertercategory.fromJson(
        serializer.fromJson<String>(json['category']),
      ),
      kind: serializer.fromJson<String>(json['kind']),
      status: serializer.fromJson<String>(json['status']),
      kindConfidence: serializer.fromJson<String>(json['kindConfidence']),
      summaryShort: serializer.fromJson<String>(json['summaryShort']),
      summaryDetailed: serializer.fromJson<String>(json['summaryDetailed']),
      extractedText: serializer.fromJson<String>(json['extractedText']),
      storageMode: $DocumentsTable.$converterstorageMode.fromJson(
        serializer.fromJson<String>(json['storageMode']),
      ),
      encryptedImagePath: serializer.fromJson<String?>(
        json['encryptedImagePath'],
      ),
      note: serializer.fromJson<String?>(json['note']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      savedAt: serializer.fromJson<DateTime>(json['savedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'category': serializer.toJson<String>(
        $DocumentsTable.$convertercategory.toJson(category),
      ),
      'kind': serializer.toJson<String>(kind),
      'status': serializer.toJson<String>(status),
      'kindConfidence': serializer.toJson<String>(kindConfidence),
      'summaryShort': serializer.toJson<String>(summaryShort),
      'summaryDetailed': serializer.toJson<String>(summaryDetailed),
      'extractedText': serializer.toJson<String>(extractedText),
      'storageMode': serializer.toJson<String>(
        $DocumentsTable.$converterstorageMode.toJson(storageMode),
      ),
      'encryptedImagePath': serializer.toJson<String?>(encryptedImagePath),
      'note': serializer.toJson<String?>(note),
      'sessionId': serializer.toJson<String>(sessionId),
      'savedAt': serializer.toJson<DateTime>(savedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DocumentRow copyWith({
    String? id,
    String? title,
    DocumentCategory? category,
    String? kind,
    String? status,
    String? kindConfidence,
    String? summaryShort,
    String? summaryDetailed,
    String? extractedText,
    DocumentStorageMode? storageMode,
    Value<String?> encryptedImagePath = const Value.absent(),
    Value<String?> note = const Value.absent(),
    String? sessionId,
    DateTime? savedAt,
    DateTime? updatedAt,
  }) => DocumentRow(
    id: id ?? this.id,
    title: title ?? this.title,
    category: category ?? this.category,
    kind: kind ?? this.kind,
    status: status ?? this.status,
    kindConfidence: kindConfidence ?? this.kindConfidence,
    summaryShort: summaryShort ?? this.summaryShort,
    summaryDetailed: summaryDetailed ?? this.summaryDetailed,
    extractedText: extractedText ?? this.extractedText,
    storageMode: storageMode ?? this.storageMode,
    encryptedImagePath: encryptedImagePath.present
        ? encryptedImagePath.value
        : this.encryptedImagePath,
    note: note.present ? note.value : this.note,
    sessionId: sessionId ?? this.sessionId,
    savedAt: savedAt ?? this.savedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DocumentRow copyWithCompanion(DocumentsCompanion data) {
    return DocumentRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      category: data.category.present ? data.category.value : this.category,
      kind: data.kind.present ? data.kind.value : this.kind,
      status: data.status.present ? data.status.value : this.status,
      kindConfidence: data.kindConfidence.present
          ? data.kindConfidence.value
          : this.kindConfidence,
      summaryShort: data.summaryShort.present
          ? data.summaryShort.value
          : this.summaryShort,
      summaryDetailed: data.summaryDetailed.present
          ? data.summaryDetailed.value
          : this.summaryDetailed,
      extractedText: data.extractedText.present
          ? data.extractedText.value
          : this.extractedText,
      storageMode: data.storageMode.present
          ? data.storageMode.value
          : this.storageMode,
      encryptedImagePath: data.encryptedImagePath.present
          ? data.encryptedImagePath.value
          : this.encryptedImagePath,
      note: data.note.present ? data.note.value : this.note,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      savedAt: data.savedAt.present ? data.savedAt.value : this.savedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DocumentRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('category: $category, ')
          ..write('kind: $kind, ')
          ..write('status: $status, ')
          ..write('kindConfidence: $kindConfidence, ')
          ..write('summaryShort: $summaryShort, ')
          ..write('summaryDetailed: $summaryDetailed, ')
          ..write('extractedText: $extractedText, ')
          ..write('storageMode: $storageMode, ')
          ..write('encryptedImagePath: $encryptedImagePath, ')
          ..write('note: $note, ')
          ..write('sessionId: $sessionId, ')
          ..write('savedAt: $savedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    category,
    kind,
    status,
    kindConfidence,
    summaryShort,
    summaryDetailed,
    extractedText,
    storageMode,
    encryptedImagePath,
    note,
    sessionId,
    savedAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DocumentRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.category == this.category &&
          other.kind == this.kind &&
          other.status == this.status &&
          other.kindConfidence == this.kindConfidence &&
          other.summaryShort == this.summaryShort &&
          other.summaryDetailed == this.summaryDetailed &&
          other.extractedText == this.extractedText &&
          other.storageMode == this.storageMode &&
          other.encryptedImagePath == this.encryptedImagePath &&
          other.note == this.note &&
          other.sessionId == this.sessionId &&
          other.savedAt == this.savedAt &&
          other.updatedAt == this.updatedAt);
}

class DocumentsCompanion extends UpdateCompanion<DocumentRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<DocumentCategory> category;
  final Value<String> kind;
  final Value<String> status;
  final Value<String> kindConfidence;
  final Value<String> summaryShort;
  final Value<String> summaryDetailed;
  final Value<String> extractedText;
  final Value<DocumentStorageMode> storageMode;
  final Value<String?> encryptedImagePath;
  final Value<String?> note;
  final Value<String> sessionId;
  final Value<DateTime> savedAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const DocumentsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.category = const Value.absent(),
    this.kind = const Value.absent(),
    this.status = const Value.absent(),
    this.kindConfidence = const Value.absent(),
    this.summaryShort = const Value.absent(),
    this.summaryDetailed = const Value.absent(),
    this.extractedText = const Value.absent(),
    this.storageMode = const Value.absent(),
    this.encryptedImagePath = const Value.absent(),
    this.note = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.savedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DocumentsCompanion.insert({
    required String id,
    required String title,
    required DocumentCategory category,
    required String kind,
    required String status,
    required String kindConfidence,
    required String summaryShort,
    required String summaryDetailed,
    required String extractedText,
    required DocumentStorageMode storageMode,
    this.encryptedImagePath = const Value.absent(),
    this.note = const Value.absent(),
    required String sessionId,
    required DateTime savedAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       category = Value(category),
       kind = Value(kind),
       status = Value(status),
       kindConfidence = Value(kindConfidence),
       summaryShort = Value(summaryShort),
       summaryDetailed = Value(summaryDetailed),
       extractedText = Value(extractedText),
       storageMode = Value(storageMode),
       sessionId = Value(sessionId),
       savedAt = Value(savedAt),
       updatedAt = Value(updatedAt);
  static Insertable<DocumentRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? category,
    Expression<String>? kind,
    Expression<String>? status,
    Expression<String>? kindConfidence,
    Expression<String>? summaryShort,
    Expression<String>? summaryDetailed,
    Expression<String>? extractedText,
    Expression<String>? storageMode,
    Expression<String>? encryptedImagePath,
    Expression<String>? note,
    Expression<String>? sessionId,
    Expression<DateTime>? savedAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (category != null) 'category': category,
      if (kind != null) 'kind': kind,
      if (status != null) 'status': status,
      if (kindConfidence != null) 'kind_confidence': kindConfidence,
      if (summaryShort != null) 'summary_short': summaryShort,
      if (summaryDetailed != null) 'summary_detailed': summaryDetailed,
      if (extractedText != null) 'extracted_text': extractedText,
      if (storageMode != null) 'storage_mode': storageMode,
      if (encryptedImagePath != null)
        'encrypted_image_path': encryptedImagePath,
      if (note != null) 'note': note,
      if (sessionId != null) 'session_id': sessionId,
      if (savedAt != null) 'saved_at': savedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DocumentsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<DocumentCategory>? category,
    Value<String>? kind,
    Value<String>? status,
    Value<String>? kindConfidence,
    Value<String>? summaryShort,
    Value<String>? summaryDetailed,
    Value<String>? extractedText,
    Value<DocumentStorageMode>? storageMode,
    Value<String?>? encryptedImagePath,
    Value<String?>? note,
    Value<String>? sessionId,
    Value<DateTime>? savedAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return DocumentsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      kind: kind ?? this.kind,
      status: status ?? this.status,
      kindConfidence: kindConfidence ?? this.kindConfidence,
      summaryShort: summaryShort ?? this.summaryShort,
      summaryDetailed: summaryDetailed ?? this.summaryDetailed,
      extractedText: extractedText ?? this.extractedText,
      storageMode: storageMode ?? this.storageMode,
      encryptedImagePath: encryptedImagePath ?? this.encryptedImagePath,
      note: note ?? this.note,
      sessionId: sessionId ?? this.sessionId,
      savedAt: savedAt ?? this.savedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(
        $DocumentsTable.$convertercategory.toSql(category.value),
      );
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (kindConfidence.present) {
      map['kind_confidence'] = Variable<String>(kindConfidence.value);
    }
    if (summaryShort.present) {
      map['summary_short'] = Variable<String>(summaryShort.value);
    }
    if (summaryDetailed.present) {
      map['summary_detailed'] = Variable<String>(summaryDetailed.value);
    }
    if (extractedText.present) {
      map['extracted_text'] = Variable<String>(extractedText.value);
    }
    if (storageMode.present) {
      map['storage_mode'] = Variable<String>(
        $DocumentsTable.$converterstorageMode.toSql(storageMode.value),
      );
    }
    if (encryptedImagePath.present) {
      map['encrypted_image_path'] = Variable<String>(encryptedImagePath.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (savedAt.present) {
      map['saved_at'] = Variable<DateTime>(savedAt.value);
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
    return (StringBuffer('DocumentsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('category: $category, ')
          ..write('kind: $kind, ')
          ..write('status: $status, ')
          ..write('kindConfidence: $kindConfidence, ')
          ..write('summaryShort: $summaryShort, ')
          ..write('summaryDetailed: $summaryDetailed, ')
          ..write('extractedText: $extractedText, ')
          ..write('storageMode: $storageMode, ')
          ..write('encryptedImagePath: $encryptedImagePath, ')
          ..write('note: $note, ')
          ..write('sessionId: $sessionId, ')
          ..write('savedAt: $savedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DocumentKeyInformationTable extends DocumentKeyInformation
    with TableInfo<$DocumentKeyInformationTable, DocumentInfoRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentKeyInformationTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES documents (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
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
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<String> confidence = GeneratedColumn<String>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    documentId,
    position,
    label,
    value,
    confidence,
    source,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'document_key_information';
  @override
  VerificationContext validateIntegrity(
    Insertable<DocumentInfoRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    } else if (isInserting) {
      context.missing(_confidenceMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {documentId, position};
  @override
  DocumentInfoRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DocumentInfoRow(
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}confidence'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
    );
  }

  @override
  $DocumentKeyInformationTable createAlias(String alias) {
    return $DocumentKeyInformationTable(attachedDatabase, alias);
  }
}

class DocumentInfoRow extends DataClass implements Insertable<DocumentInfoRow> {
  final String documentId;
  final int position;
  final String label;
  final String value;

  /// `ConfidenceBand` name — confidence is per field, never per document.
  final String confidence;

  /// `InfoSource` name: read off the paper, or worked out by the analysis.
  final String source;
  const DocumentInfoRow({
    required this.documentId,
    required this.position,
    required this.label,
    required this.value,
    required this.confidence,
    required this.source,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['document_id'] = Variable<String>(documentId);
    map['position'] = Variable<int>(position);
    map['label'] = Variable<String>(label);
    map['value'] = Variable<String>(value);
    map['confidence'] = Variable<String>(confidence);
    map['source'] = Variable<String>(source);
    return map;
  }

  DocumentKeyInformationCompanion toCompanion(bool nullToAbsent) {
    return DocumentKeyInformationCompanion(
      documentId: Value(documentId),
      position: Value(position),
      label: Value(label),
      value: Value(value),
      confidence: Value(confidence),
      source: Value(source),
    );
  }

  factory DocumentInfoRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DocumentInfoRow(
      documentId: serializer.fromJson<String>(json['documentId']),
      position: serializer.fromJson<int>(json['position']),
      label: serializer.fromJson<String>(json['label']),
      value: serializer.fromJson<String>(json['value']),
      confidence: serializer.fromJson<String>(json['confidence']),
      source: serializer.fromJson<String>(json['source']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'documentId': serializer.toJson<String>(documentId),
      'position': serializer.toJson<int>(position),
      'label': serializer.toJson<String>(label),
      'value': serializer.toJson<String>(value),
      'confidence': serializer.toJson<String>(confidence),
      'source': serializer.toJson<String>(source),
    };
  }

  DocumentInfoRow copyWith({
    String? documentId,
    int? position,
    String? label,
    String? value,
    String? confidence,
    String? source,
  }) => DocumentInfoRow(
    documentId: documentId ?? this.documentId,
    position: position ?? this.position,
    label: label ?? this.label,
    value: value ?? this.value,
    confidence: confidence ?? this.confidence,
    source: source ?? this.source,
  );
  DocumentInfoRow copyWithCompanion(DocumentKeyInformationCompanion data) {
    return DocumentInfoRow(
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      position: data.position.present ? data.position.value : this.position,
      label: data.label.present ? data.label.value : this.label,
      value: data.value.present ? data.value.value : this.value,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DocumentInfoRow(')
          ..write('documentId: $documentId, ')
          ..write('position: $position, ')
          ..write('label: $label, ')
          ..write('value: $value, ')
          ..write('confidence: $confidence, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(documentId, position, label, value, confidence, source);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DocumentInfoRow &&
          other.documentId == this.documentId &&
          other.position == this.position &&
          other.label == this.label &&
          other.value == this.value &&
          other.confidence == this.confidence &&
          other.source == this.source);
}

class DocumentKeyInformationCompanion extends UpdateCompanion<DocumentInfoRow> {
  final Value<String> documentId;
  final Value<int> position;
  final Value<String> label;
  final Value<String> value;
  final Value<String> confidence;
  final Value<String> source;
  final Value<int> rowid;
  const DocumentKeyInformationCompanion({
    this.documentId = const Value.absent(),
    this.position = const Value.absent(),
    this.label = const Value.absent(),
    this.value = const Value.absent(),
    this.confidence = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DocumentKeyInformationCompanion.insert({
    required String documentId,
    required int position,
    required String label,
    required String value,
    required String confidence,
    required String source,
    this.rowid = const Value.absent(),
  }) : documentId = Value(documentId),
       position = Value(position),
       label = Value(label),
       value = Value(value),
       confidence = Value(confidence),
       source = Value(source);
  static Insertable<DocumentInfoRow> custom({
    Expression<String>? documentId,
    Expression<int>? position,
    Expression<String>? label,
    Expression<String>? value,
    Expression<String>? confidence,
    Expression<String>? source,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (documentId != null) 'document_id': documentId,
      if (position != null) 'position': position,
      if (label != null) 'label': label,
      if (value != null) 'value': value,
      if (confidence != null) 'confidence': confidence,
      if (source != null) 'source': source,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DocumentKeyInformationCompanion copyWith({
    Value<String>? documentId,
    Value<int>? position,
    Value<String>? label,
    Value<String>? value,
    Value<String>? confidence,
    Value<String>? source,
    Value<int>? rowid,
  }) {
    return DocumentKeyInformationCompanion(
      documentId: documentId ?? this.documentId,
      position: position ?? this.position,
      label: label ?? this.label,
      value: value ?? this.value,
      confidence: confidence ?? this.confidence,
      source: source ?? this.source,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<String>(confidence.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentKeyInformationCompanion(')
          ..write('documentId: $documentId, ')
          ..write('position: $position, ')
          ..write('label: $label, ')
          ..write('value: $value, ')
          ..write('confidence: $confidence, ')
          ..write('source: $source, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DocumentDatesTable extends DocumentDates
    with TableInfo<$DocumentDatesTable, DocumentDateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentDatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES documents (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _minuteOfDayMeta = const VerificationMeta(
    'minuteOfDay',
  );
  @override
  late final GeneratedColumn<int> minuteOfDay = GeneratedColumn<int>(
    'minute_of_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isReminderWorthyMeta = const VerificationMeta(
    'isReminderWorthy',
  );
  @override
  late final GeneratedColumn<bool> isReminderWorthy = GeneratedColumn<bool>(
    'is_reminder_worthy',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_reminder_worthy" IN (0, 1))',
    ),
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<String> confidence = GeneratedColumn<String>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    documentId,
    position,
    label,
    date,
    minuteOfDay,
    role,
    isReminderWorthy,
    confidence,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'document_dates';
  @override
  VerificationContext validateIntegrity(
    Insertable<DocumentDateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('minute_of_day')) {
      context.handle(
        _minuteOfDayMeta,
        minuteOfDay.isAcceptableOrUnknown(
          data['minute_of_day']!,
          _minuteOfDayMeta,
        ),
      );
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('is_reminder_worthy')) {
      context.handle(
        _isReminderWorthyMeta,
        isReminderWorthy.isAcceptableOrUnknown(
          data['is_reminder_worthy']!,
          _isReminderWorthyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_isReminderWorthyMeta);
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    } else if (isInserting) {
      context.missing(_confidenceMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {documentId, position};
  @override
  DocumentDateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DocumentDateRow(
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      minuteOfDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}minute_of_day'],
      ),
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      isReminderWorthy: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_reminder_worthy'],
      )!,
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}confidence'],
      )!,
    );
  }

  @override
  $DocumentDatesTable createAlias(String alias) {
    return $DocumentDatesTable(attachedDatabase, alias);
  }
}

class DocumentDateRow extends DataClass implements Insertable<DocumentDateRow> {
  final String documentId;
  final int position;
  final String label;

  /// The calendar day, at local midnight.
  final DateTime date;

  /// Time of day as minutes since midnight, or `null` when the paper gave a
  /// day but no hour. The distinction is load-bearing: a reminder on a date
  /// with no time has to ask the user rather than invent one, so "no time" is
  /// stored as absent and never as `00:00`.
  final int? minuteOfDay;

  /// `DateRole` name — deadline, appointment, expiry, …
  final String role;

  /// What the analysis suggested. Nothing is ever scheduled off this alone.
  final bool isReminderWorthy;

  /// `ConfidenceBand` name.
  final String confidence;
  const DocumentDateRow({
    required this.documentId,
    required this.position,
    required this.label,
    required this.date,
    this.minuteOfDay,
    required this.role,
    required this.isReminderWorthy,
    required this.confidence,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['document_id'] = Variable<String>(documentId);
    map['position'] = Variable<int>(position);
    map['label'] = Variable<String>(label);
    map['date'] = Variable<DateTime>(date);
    if (!nullToAbsent || minuteOfDay != null) {
      map['minute_of_day'] = Variable<int>(minuteOfDay);
    }
    map['role'] = Variable<String>(role);
    map['is_reminder_worthy'] = Variable<bool>(isReminderWorthy);
    map['confidence'] = Variable<String>(confidence);
    return map;
  }

  DocumentDatesCompanion toCompanion(bool nullToAbsent) {
    return DocumentDatesCompanion(
      documentId: Value(documentId),
      position: Value(position),
      label: Value(label),
      date: Value(date),
      minuteOfDay: minuteOfDay == null && nullToAbsent
          ? const Value.absent()
          : Value(minuteOfDay),
      role: Value(role),
      isReminderWorthy: Value(isReminderWorthy),
      confidence: Value(confidence),
    );
  }

  factory DocumentDateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DocumentDateRow(
      documentId: serializer.fromJson<String>(json['documentId']),
      position: serializer.fromJson<int>(json['position']),
      label: serializer.fromJson<String>(json['label']),
      date: serializer.fromJson<DateTime>(json['date']),
      minuteOfDay: serializer.fromJson<int?>(json['minuteOfDay']),
      role: serializer.fromJson<String>(json['role']),
      isReminderWorthy: serializer.fromJson<bool>(json['isReminderWorthy']),
      confidence: serializer.fromJson<String>(json['confidence']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'documentId': serializer.toJson<String>(documentId),
      'position': serializer.toJson<int>(position),
      'label': serializer.toJson<String>(label),
      'date': serializer.toJson<DateTime>(date),
      'minuteOfDay': serializer.toJson<int?>(minuteOfDay),
      'role': serializer.toJson<String>(role),
      'isReminderWorthy': serializer.toJson<bool>(isReminderWorthy),
      'confidence': serializer.toJson<String>(confidence),
    };
  }

  DocumentDateRow copyWith({
    String? documentId,
    int? position,
    String? label,
    DateTime? date,
    Value<int?> minuteOfDay = const Value.absent(),
    String? role,
    bool? isReminderWorthy,
    String? confidence,
  }) => DocumentDateRow(
    documentId: documentId ?? this.documentId,
    position: position ?? this.position,
    label: label ?? this.label,
    date: date ?? this.date,
    minuteOfDay: minuteOfDay.present ? minuteOfDay.value : this.minuteOfDay,
    role: role ?? this.role,
    isReminderWorthy: isReminderWorthy ?? this.isReminderWorthy,
    confidence: confidence ?? this.confidence,
  );
  DocumentDateRow copyWithCompanion(DocumentDatesCompanion data) {
    return DocumentDateRow(
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      position: data.position.present ? data.position.value : this.position,
      label: data.label.present ? data.label.value : this.label,
      date: data.date.present ? data.date.value : this.date,
      minuteOfDay: data.minuteOfDay.present
          ? data.minuteOfDay.value
          : this.minuteOfDay,
      role: data.role.present ? data.role.value : this.role,
      isReminderWorthy: data.isReminderWorthy.present
          ? data.isReminderWorthy.value
          : this.isReminderWorthy,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DocumentDateRow(')
          ..write('documentId: $documentId, ')
          ..write('position: $position, ')
          ..write('label: $label, ')
          ..write('date: $date, ')
          ..write('minuteOfDay: $minuteOfDay, ')
          ..write('role: $role, ')
          ..write('isReminderWorthy: $isReminderWorthy, ')
          ..write('confidence: $confidence')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    documentId,
    position,
    label,
    date,
    minuteOfDay,
    role,
    isReminderWorthy,
    confidence,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DocumentDateRow &&
          other.documentId == this.documentId &&
          other.position == this.position &&
          other.label == this.label &&
          other.date == this.date &&
          other.minuteOfDay == this.minuteOfDay &&
          other.role == this.role &&
          other.isReminderWorthy == this.isReminderWorthy &&
          other.confidence == this.confidence);
}

class DocumentDatesCompanion extends UpdateCompanion<DocumentDateRow> {
  final Value<String> documentId;
  final Value<int> position;
  final Value<String> label;
  final Value<DateTime> date;
  final Value<int?> minuteOfDay;
  final Value<String> role;
  final Value<bool> isReminderWorthy;
  final Value<String> confidence;
  final Value<int> rowid;
  const DocumentDatesCompanion({
    this.documentId = const Value.absent(),
    this.position = const Value.absent(),
    this.label = const Value.absent(),
    this.date = const Value.absent(),
    this.minuteOfDay = const Value.absent(),
    this.role = const Value.absent(),
    this.isReminderWorthy = const Value.absent(),
    this.confidence = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DocumentDatesCompanion.insert({
    required String documentId,
    required int position,
    required String label,
    required DateTime date,
    this.minuteOfDay = const Value.absent(),
    required String role,
    required bool isReminderWorthy,
    required String confidence,
    this.rowid = const Value.absent(),
  }) : documentId = Value(documentId),
       position = Value(position),
       label = Value(label),
       date = Value(date),
       role = Value(role),
       isReminderWorthy = Value(isReminderWorthy),
       confidence = Value(confidence);
  static Insertable<DocumentDateRow> custom({
    Expression<String>? documentId,
    Expression<int>? position,
    Expression<String>? label,
    Expression<DateTime>? date,
    Expression<int>? minuteOfDay,
    Expression<String>? role,
    Expression<bool>? isReminderWorthy,
    Expression<String>? confidence,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (documentId != null) 'document_id': documentId,
      if (position != null) 'position': position,
      if (label != null) 'label': label,
      if (date != null) 'date': date,
      if (minuteOfDay != null) 'minute_of_day': minuteOfDay,
      if (role != null) 'role': role,
      if (isReminderWorthy != null) 'is_reminder_worthy': isReminderWorthy,
      if (confidence != null) 'confidence': confidence,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DocumentDatesCompanion copyWith({
    Value<String>? documentId,
    Value<int>? position,
    Value<String>? label,
    Value<DateTime>? date,
    Value<int?>? minuteOfDay,
    Value<String>? role,
    Value<bool>? isReminderWorthy,
    Value<String>? confidence,
    Value<int>? rowid,
  }) {
    return DocumentDatesCompanion(
      documentId: documentId ?? this.documentId,
      position: position ?? this.position,
      label: label ?? this.label,
      date: date ?? this.date,
      minuteOfDay: minuteOfDay ?? this.minuteOfDay,
      role: role ?? this.role,
      isReminderWorthy: isReminderWorthy ?? this.isReminderWorthy,
      confidence: confidence ?? this.confidence,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (minuteOfDay.present) {
      map['minute_of_day'] = Variable<int>(minuteOfDay.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (isReminderWorthy.present) {
      map['is_reminder_worthy'] = Variable<bool>(isReminderWorthy.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<String>(confidence.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentDatesCompanion(')
          ..write('documentId: $documentId, ')
          ..write('position: $position, ')
          ..write('label: $label, ')
          ..write('date: $date, ')
          ..write('minuteOfDay: $minuteOfDay, ')
          ..write('role: $role, ')
          ..write('isReminderWorthy: $isReminderWorthy, ')
          ..write('confidence: $confidence, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DocumentAmountsTable extends DocumentAmounts
    with TableInfo<$DocumentAmountsTable, DocumentAmountRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentAmountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES documents (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<double> value = GeneratedColumn<double>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<String> confidence = GeneratedColumn<String>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    documentId,
    position,
    label,
    value,
    currency,
    confidence,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'document_amounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<DocumentAmountRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    } else if (isInserting) {
      context.missing(_confidenceMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {documentId, position};
  @override
  DocumentAmountRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DocumentAmountRow(
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}value'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}confidence'],
      )!,
    );
  }

  @override
  $DocumentAmountsTable createAlias(String alias) {
    return $DocumentAmountsTable(attachedDatabase, alias);
  }
}

class DocumentAmountRow extends DataClass
    implements Insertable<DocumentAmountRow> {
  final String documentId;
  final int position;
  final String label;
  final double value;

  /// Currency code as the analysis reported it, e.g. `EGP`.
  final String currency;

  /// `ConfidenceBand` name.
  final String confidence;
  const DocumentAmountRow({
    required this.documentId,
    required this.position,
    required this.label,
    required this.value,
    required this.currency,
    required this.confidence,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['document_id'] = Variable<String>(documentId);
    map['position'] = Variable<int>(position);
    map['label'] = Variable<String>(label);
    map['value'] = Variable<double>(value);
    map['currency'] = Variable<String>(currency);
    map['confidence'] = Variable<String>(confidence);
    return map;
  }

  DocumentAmountsCompanion toCompanion(bool nullToAbsent) {
    return DocumentAmountsCompanion(
      documentId: Value(documentId),
      position: Value(position),
      label: Value(label),
      value: Value(value),
      currency: Value(currency),
      confidence: Value(confidence),
    );
  }

  factory DocumentAmountRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DocumentAmountRow(
      documentId: serializer.fromJson<String>(json['documentId']),
      position: serializer.fromJson<int>(json['position']),
      label: serializer.fromJson<String>(json['label']),
      value: serializer.fromJson<double>(json['value']),
      currency: serializer.fromJson<String>(json['currency']),
      confidence: serializer.fromJson<String>(json['confidence']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'documentId': serializer.toJson<String>(documentId),
      'position': serializer.toJson<int>(position),
      'label': serializer.toJson<String>(label),
      'value': serializer.toJson<double>(value),
      'currency': serializer.toJson<String>(currency),
      'confidence': serializer.toJson<String>(confidence),
    };
  }

  DocumentAmountRow copyWith({
    String? documentId,
    int? position,
    String? label,
    double? value,
    String? currency,
    String? confidence,
  }) => DocumentAmountRow(
    documentId: documentId ?? this.documentId,
    position: position ?? this.position,
    label: label ?? this.label,
    value: value ?? this.value,
    currency: currency ?? this.currency,
    confidence: confidence ?? this.confidence,
  );
  DocumentAmountRow copyWithCompanion(DocumentAmountsCompanion data) {
    return DocumentAmountRow(
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      position: data.position.present ? data.position.value : this.position,
      label: data.label.present ? data.label.value : this.label,
      value: data.value.present ? data.value.value : this.value,
      currency: data.currency.present ? data.currency.value : this.currency,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DocumentAmountRow(')
          ..write('documentId: $documentId, ')
          ..write('position: $position, ')
          ..write('label: $label, ')
          ..write('value: $value, ')
          ..write('currency: $currency, ')
          ..write('confidence: $confidence')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(documentId, position, label, value, currency, confidence);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DocumentAmountRow &&
          other.documentId == this.documentId &&
          other.position == this.position &&
          other.label == this.label &&
          other.value == this.value &&
          other.currency == this.currency &&
          other.confidence == this.confidence);
}

class DocumentAmountsCompanion extends UpdateCompanion<DocumentAmountRow> {
  final Value<String> documentId;
  final Value<int> position;
  final Value<String> label;
  final Value<double> value;
  final Value<String> currency;
  final Value<String> confidence;
  final Value<int> rowid;
  const DocumentAmountsCompanion({
    this.documentId = const Value.absent(),
    this.position = const Value.absent(),
    this.label = const Value.absent(),
    this.value = const Value.absent(),
    this.currency = const Value.absent(),
    this.confidence = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DocumentAmountsCompanion.insert({
    required String documentId,
    required int position,
    required String label,
    required double value,
    required String currency,
    required String confidence,
    this.rowid = const Value.absent(),
  }) : documentId = Value(documentId),
       position = Value(position),
       label = Value(label),
       value = Value(value),
       currency = Value(currency),
       confidence = Value(confidence);
  static Insertable<DocumentAmountRow> custom({
    Expression<String>? documentId,
    Expression<int>? position,
    Expression<String>? label,
    Expression<double>? value,
    Expression<String>? currency,
    Expression<String>? confidence,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (documentId != null) 'document_id': documentId,
      if (position != null) 'position': position,
      if (label != null) 'label': label,
      if (value != null) 'value': value,
      if (currency != null) 'currency': currency,
      if (confidence != null) 'confidence': confidence,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DocumentAmountsCompanion copyWith({
    Value<String>? documentId,
    Value<int>? position,
    Value<String>? label,
    Value<double>? value,
    Value<String>? currency,
    Value<String>? confidence,
    Value<int>? rowid,
  }) {
    return DocumentAmountsCompanion(
      documentId: documentId ?? this.documentId,
      position: position ?? this.position,
      label: label ?? this.label,
      value: value ?? this.value,
      currency: currency ?? this.currency,
      confidence: confidence ?? this.confidence,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (value.present) {
      map['value'] = Variable<double>(value.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<String>(confidence.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentAmountsCompanion(')
          ..write('documentId: $documentId, ')
          ..write('position: $position, ')
          ..write('label: $label, ')
          ..write('value: $value, ')
          ..write('currency: $currency, ')
          ..write('confidence: $confidence, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DocumentActionsTable extends DocumentActions
    with TableInfo<$DocumentActionsTable, DocumentActionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentActionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES documents (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _basisMeta = const VerificationMeta('basis');
  @override
  late final GeneratedColumn<String> basis = GeneratedColumn<String>(
    'basis',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<String> priority = GeneratedColumn<String>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    documentId,
    position,
    description,
    basis,
    priority,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'document_actions';
  @override
  VerificationContext validateIntegrity(
    Insertable<DocumentActionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('basis')) {
      context.handle(
        _basisMeta,
        basis.isAcceptableOrUnknown(data['basis']!, _basisMeta),
      );
    } else if (isInserting) {
      context.missing(_basisMeta);
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    } else if (isInserting) {
      context.missing(_priorityMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {documentId, position};
  @override
  DocumentActionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DocumentActionRow(
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      basis: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}basis'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}priority'],
      )!,
    );
  }

  @override
  $DocumentActionsTable createAlias(String alias) {
    return $DocumentActionsTable(attachedDatabase, alias);
  }
}

class DocumentActionRow extends DataClass
    implements Insertable<DocumentActionRow> {
  final String documentId;
  final int position;
  final String description;

  /// `ActionBasis` name: written on the paper, or inferred.
  final String basis;

  /// `ActionPriority` name.
  final String priority;
  const DocumentActionRow({
    required this.documentId,
    required this.position,
    required this.description,
    required this.basis,
    required this.priority,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['document_id'] = Variable<String>(documentId);
    map['position'] = Variable<int>(position);
    map['description'] = Variable<String>(description);
    map['basis'] = Variable<String>(basis);
    map['priority'] = Variable<String>(priority);
    return map;
  }

  DocumentActionsCompanion toCompanion(bool nullToAbsent) {
    return DocumentActionsCompanion(
      documentId: Value(documentId),
      position: Value(position),
      description: Value(description),
      basis: Value(basis),
      priority: Value(priority),
    );
  }

  factory DocumentActionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DocumentActionRow(
      documentId: serializer.fromJson<String>(json['documentId']),
      position: serializer.fromJson<int>(json['position']),
      description: serializer.fromJson<String>(json['description']),
      basis: serializer.fromJson<String>(json['basis']),
      priority: serializer.fromJson<String>(json['priority']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'documentId': serializer.toJson<String>(documentId),
      'position': serializer.toJson<int>(position),
      'description': serializer.toJson<String>(description),
      'basis': serializer.toJson<String>(basis),
      'priority': serializer.toJson<String>(priority),
    };
  }

  DocumentActionRow copyWith({
    String? documentId,
    int? position,
    String? description,
    String? basis,
    String? priority,
  }) => DocumentActionRow(
    documentId: documentId ?? this.documentId,
    position: position ?? this.position,
    description: description ?? this.description,
    basis: basis ?? this.basis,
    priority: priority ?? this.priority,
  );
  DocumentActionRow copyWithCompanion(DocumentActionsCompanion data) {
    return DocumentActionRow(
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      position: data.position.present ? data.position.value : this.position,
      description: data.description.present
          ? data.description.value
          : this.description,
      basis: data.basis.present ? data.basis.value : this.basis,
      priority: data.priority.present ? data.priority.value : this.priority,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DocumentActionRow(')
          ..write('documentId: $documentId, ')
          ..write('position: $position, ')
          ..write('description: $description, ')
          ..write('basis: $basis, ')
          ..write('priority: $priority')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(documentId, position, description, basis, priority);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DocumentActionRow &&
          other.documentId == this.documentId &&
          other.position == this.position &&
          other.description == this.description &&
          other.basis == this.basis &&
          other.priority == this.priority);
}

class DocumentActionsCompanion extends UpdateCompanion<DocumentActionRow> {
  final Value<String> documentId;
  final Value<int> position;
  final Value<String> description;
  final Value<String> basis;
  final Value<String> priority;
  final Value<int> rowid;
  const DocumentActionsCompanion({
    this.documentId = const Value.absent(),
    this.position = const Value.absent(),
    this.description = const Value.absent(),
    this.basis = const Value.absent(),
    this.priority = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DocumentActionsCompanion.insert({
    required String documentId,
    required int position,
    required String description,
    required String basis,
    required String priority,
    this.rowid = const Value.absent(),
  }) : documentId = Value(documentId),
       position = Value(position),
       description = Value(description),
       basis = Value(basis),
       priority = Value(priority);
  static Insertable<DocumentActionRow> custom({
    Expression<String>? documentId,
    Expression<int>? position,
    Expression<String>? description,
    Expression<String>? basis,
    Expression<String>? priority,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (documentId != null) 'document_id': documentId,
      if (position != null) 'position': position,
      if (description != null) 'description': description,
      if (basis != null) 'basis': basis,
      if (priority != null) 'priority': priority,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DocumentActionsCompanion copyWith({
    Value<String>? documentId,
    Value<int>? position,
    Value<String>? description,
    Value<String>? basis,
    Value<String>? priority,
    Value<int>? rowid,
  }) {
    return DocumentActionsCompanion(
      documentId: documentId ?? this.documentId,
      position: position ?? this.position,
      description: description ?? this.description,
      basis: basis ?? this.basis,
      priority: priority ?? this.priority,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (basis.present) {
      map['basis'] = Variable<String>(basis.value);
    }
    if (priority.present) {
      map['priority'] = Variable<String>(priority.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentActionsCompanion(')
          ..write('documentId: $documentId, ')
          ..write('position: $position, ')
          ..write('description: $description, ')
          ..write('basis: $basis, ')
          ..write('priority: $priority, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DocumentWarningsTable extends DocumentWarnings
    with TableInfo<$DocumentWarningsTable, DocumentWarningRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentWarningsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES documents (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageMeta = const VerificationMeta(
    'message',
  );
  @override
  late final GeneratedColumn<String> message = GeneratedColumn<String>(
    'message',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [documentId, position, message, kind];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'document_warnings';
  @override
  VerificationContext validateIntegrity(
    Insertable<DocumentWarningRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('message')) {
      context.handle(
        _messageMeta,
        message.isAcceptableOrUnknown(data['message']!, _messageMeta),
      );
    } else if (isInserting) {
      context.missing(_messageMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {documentId, position};
  @override
  DocumentWarningRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DocumentWarningRow(
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      message: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
    );
  }

  @override
  $DocumentWarningsTable createAlias(String alias) {
    return $DocumentWarningsTable(attachedDatabase, alias);
  }
}

class DocumentWarningRow extends DataClass
    implements Insertable<DocumentWarningRow> {
  final String documentId;
  final int position;

  /// Arabic warning copy, ready to display. Named `message` rather than
  /// `text` because `text` is [Table]'s own column builder.
  final String message;

  /// `WarningKind` name — drives the icon and tone.
  final String kind;
  const DocumentWarningRow({
    required this.documentId,
    required this.position,
    required this.message,
    required this.kind,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['document_id'] = Variable<String>(documentId);
    map['position'] = Variable<int>(position);
    map['message'] = Variable<String>(message);
    map['kind'] = Variable<String>(kind);
    return map;
  }

  DocumentWarningsCompanion toCompanion(bool nullToAbsent) {
    return DocumentWarningsCompanion(
      documentId: Value(documentId),
      position: Value(position),
      message: Value(message),
      kind: Value(kind),
    );
  }

  factory DocumentWarningRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DocumentWarningRow(
      documentId: serializer.fromJson<String>(json['documentId']),
      position: serializer.fromJson<int>(json['position']),
      message: serializer.fromJson<String>(json['message']),
      kind: serializer.fromJson<String>(json['kind']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'documentId': serializer.toJson<String>(documentId),
      'position': serializer.toJson<int>(position),
      'message': serializer.toJson<String>(message),
      'kind': serializer.toJson<String>(kind),
    };
  }

  DocumentWarningRow copyWith({
    String? documentId,
    int? position,
    String? message,
    String? kind,
  }) => DocumentWarningRow(
    documentId: documentId ?? this.documentId,
    position: position ?? this.position,
    message: message ?? this.message,
    kind: kind ?? this.kind,
  );
  DocumentWarningRow copyWithCompanion(DocumentWarningsCompanion data) {
    return DocumentWarningRow(
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      position: data.position.present ? data.position.value : this.position,
      message: data.message.present ? data.message.value : this.message,
      kind: data.kind.present ? data.kind.value : this.kind,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DocumentWarningRow(')
          ..write('documentId: $documentId, ')
          ..write('position: $position, ')
          ..write('message: $message, ')
          ..write('kind: $kind')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(documentId, position, message, kind);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DocumentWarningRow &&
          other.documentId == this.documentId &&
          other.position == this.position &&
          other.message == this.message &&
          other.kind == this.kind);
}

class DocumentWarningsCompanion extends UpdateCompanion<DocumentWarningRow> {
  final Value<String> documentId;
  final Value<int> position;
  final Value<String> message;
  final Value<String> kind;
  final Value<int> rowid;
  const DocumentWarningsCompanion({
    this.documentId = const Value.absent(),
    this.position = const Value.absent(),
    this.message = const Value.absent(),
    this.kind = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DocumentWarningsCompanion.insert({
    required String documentId,
    required int position,
    required String message,
    required String kind,
    this.rowid = const Value.absent(),
  }) : documentId = Value(documentId),
       position = Value(position),
       message = Value(message),
       kind = Value(kind);
  static Insertable<DocumentWarningRow> custom({
    Expression<String>? documentId,
    Expression<int>? position,
    Expression<String>? message,
    Expression<String>? kind,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (documentId != null) 'document_id': documentId,
      if (position != null) 'position': position,
      if (message != null) 'message': message,
      if (kind != null) 'kind': kind,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DocumentWarningsCompanion copyWith({
    Value<String>? documentId,
    Value<int>? position,
    Value<String>? message,
    Value<String>? kind,
    Value<int>? rowid,
  }) {
    return DocumentWarningsCompanion(
      documentId: documentId ?? this.documentId,
      position: position ?? this.position,
      message: message ?? this.message,
      kind: kind ?? this.kind,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (message.present) {
      map['message'] = Variable<String>(message.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentWarningsCompanion(')
          ..write('documentId: $documentId, ')
          ..write('position: $position, ')
          ..write('message: $message, ')
          ..write('kind: $kind, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DocumentTextItemsTable extends DocumentTextItems
    with TableInfo<$DocumentTextItemsTable, DocumentTextItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentTextItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES documents (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DocumentTextItemKind, String>
  kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<DocumentTextItemKind>($DocumentTextItemsTable.$converterkind);
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  List<GeneratedColumn> get $columns => [documentId, kind, position, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'document_text_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<DocumentTextItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
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
  Set<GeneratedColumn> get $primaryKey => {documentId, kind, position};
  @override
  DocumentTextItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DocumentTextItemRow(
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      )!,
      kind: $DocumentTextItemsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $DocumentTextItemsTable createAlias(String alias) {
    return $DocumentTextItemsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DocumentTextItemKind, String, String>
  $converterkind = const EnumNameConverter<DocumentTextItemKind>(
    DocumentTextItemKind.values,
  );
}

class DocumentTextItemRow extends DataClass
    implements Insertable<DocumentTextItemRow> {
  final String documentId;

  /// Which list this row belongs to.
  final DocumentTextItemKind kind;

  /// Order within that list.
  final int position;
  final String value;
  const DocumentTextItemRow({
    required this.documentId,
    required this.kind,
    required this.position,
    required this.value,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['document_id'] = Variable<String>(documentId);
    {
      map['kind'] = Variable<String>(
        $DocumentTextItemsTable.$converterkind.toSql(kind),
      );
    }
    map['position'] = Variable<int>(position);
    map['value'] = Variable<String>(value);
    return map;
  }

  DocumentTextItemsCompanion toCompanion(bool nullToAbsent) {
    return DocumentTextItemsCompanion(
      documentId: Value(documentId),
      kind: Value(kind),
      position: Value(position),
      value: Value(value),
    );
  }

  factory DocumentTextItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DocumentTextItemRow(
      documentId: serializer.fromJson<String>(json['documentId']),
      kind: $DocumentTextItemsTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      position: serializer.fromJson<int>(json['position']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'documentId': serializer.toJson<String>(documentId),
      'kind': serializer.toJson<String>(
        $DocumentTextItemsTable.$converterkind.toJson(kind),
      ),
      'position': serializer.toJson<int>(position),
      'value': serializer.toJson<String>(value),
    };
  }

  DocumentTextItemRow copyWith({
    String? documentId,
    DocumentTextItemKind? kind,
    int? position,
    String? value,
  }) => DocumentTextItemRow(
    documentId: documentId ?? this.documentId,
    kind: kind ?? this.kind,
    position: position ?? this.position,
    value: value ?? this.value,
  );
  DocumentTextItemRow copyWithCompanion(DocumentTextItemsCompanion data) {
    return DocumentTextItemRow(
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      kind: data.kind.present ? data.kind.value : this.kind,
      position: data.position.present ? data.position.value : this.position,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DocumentTextItemRow(')
          ..write('documentId: $documentId, ')
          ..write('kind: $kind, ')
          ..write('position: $position, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(documentId, kind, position, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DocumentTextItemRow &&
          other.documentId == this.documentId &&
          other.kind == this.kind &&
          other.position == this.position &&
          other.value == this.value);
}

class DocumentTextItemsCompanion extends UpdateCompanion<DocumentTextItemRow> {
  final Value<String> documentId;
  final Value<DocumentTextItemKind> kind;
  final Value<int> position;
  final Value<String> value;
  final Value<int> rowid;
  const DocumentTextItemsCompanion({
    this.documentId = const Value.absent(),
    this.kind = const Value.absent(),
    this.position = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DocumentTextItemsCompanion.insert({
    required String documentId,
    required DocumentTextItemKind kind,
    required int position,
    required String value,
    this.rowid = const Value.absent(),
  }) : documentId = Value(documentId),
       kind = Value(kind),
       position = Value(position),
       value = Value(value);
  static Insertable<DocumentTextItemRow> custom({
    Expression<String>? documentId,
    Expression<String>? kind,
    Expression<int>? position,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (documentId != null) 'document_id': documentId,
      if (kind != null) 'kind': kind,
      if (position != null) 'position': position,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DocumentTextItemsCompanion copyWith({
    Value<String>? documentId,
    Value<DocumentTextItemKind>? kind,
    Value<int>? position,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return DocumentTextItemsCompanion(
      documentId: documentId ?? this.documentId,
      kind: kind ?? this.kind,
      position: position ?? this.position,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $DocumentTextItemsTable.$converterkind.toSql(kind.value),
      );
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
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
    return (StringBuffer('DocumentTextItemsCompanion(')
          ..write('documentId: $documentId, ')
          ..write('kind: $kind, ')
          ..write('position: $position, ')
          ..write('value: $value, ')
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
  late final $DocumentsTable documents = $DocumentsTable(this);
  late final $DocumentKeyInformationTable documentKeyInformation =
      $DocumentKeyInformationTable(this);
  late final $DocumentDatesTable documentDates = $DocumentDatesTable(this);
  late final $DocumentAmountsTable documentAmounts = $DocumentAmountsTable(
    this,
  );
  late final $DocumentActionsTable documentActions = $DocumentActionsTable(
    this,
  );
  late final $DocumentWarningsTable documentWarnings = $DocumentWarningsTable(
    this,
  );
  late final $DocumentTextItemsTable documentTextItems =
      $DocumentTextItemsTable(this);
  late final Index documentsSavedAt = Index(
    'documents_saved_at',
    'CREATE INDEX documents_saved_at ON documents (saved_at)',
  );
  late final Index documentsCategory = Index(
    'documents_category',
    'CREATE INDEX documents_category ON documents (category)',
  );
  late final DocumentsDao documentsDao = DocumentsDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    appSettings,
    usageCache,
    documents,
    documentKeyInformation,
    documentDates,
    documentAmounts,
    documentActions,
    documentWarnings,
    documentTextItems,
    documentsSavedAt,
    documentsCategory,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'documents',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('document_key_information', kind: UpdateKind.delete),
      ],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'documents',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('document_dates', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'documents',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('document_amounts', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'documents',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('document_actions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'documents',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('document_warnings', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'documents',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('document_text_items', kind: UpdateKind.delete)],
    ),
  ]);
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
typedef $$DocumentsTableCreateCompanionBuilder =
    DocumentsCompanion Function({
      required String id,
      required String title,
      required DocumentCategory category,
      required String kind,
      required String status,
      required String kindConfidence,
      required String summaryShort,
      required String summaryDetailed,
      required String extractedText,
      required DocumentStorageMode storageMode,
      Value<String?> encryptedImagePath,
      Value<String?> note,
      required String sessionId,
      required DateTime savedAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$DocumentsTableUpdateCompanionBuilder =
    DocumentsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<DocumentCategory> category,
      Value<String> kind,
      Value<String> status,
      Value<String> kindConfidence,
      Value<String> summaryShort,
      Value<String> summaryDetailed,
      Value<String> extractedText,
      Value<DocumentStorageMode> storageMode,
      Value<String?> encryptedImagePath,
      Value<String?> note,
      Value<String> sessionId,
      Value<DateTime> savedAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$DocumentsTableReferences
    extends BaseReferences<_$AppDatabase, $DocumentsTable, DocumentRow> {
  $$DocumentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<
    $DocumentKeyInformationTable,
    List<DocumentInfoRow>
  >
  _documentKeyInformationRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.documentKeyInformation,
        aliasName: 'documents__id__document_key_information__document_id',
      );

  $$DocumentKeyInformationTableProcessedTableManager
  get documentKeyInformationRefs {
    final manager = $$DocumentKeyInformationTableTableManager(
      $_db,
      $_db.documentKeyInformation,
    ).filter((f) => f.documentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _documentKeyInformationRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DocumentDatesTable, List<DocumentDateRow>>
  _documentDatesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.documentDates,
    aliasName: 'documents__id__document_dates__document_id',
  );

  $$DocumentDatesTableProcessedTableManager get documentDatesRefs {
    final manager = $$DocumentDatesTableTableManager(
      $_db,
      $_db.documentDates,
    ).filter((f) => f.documentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_documentDatesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DocumentAmountsTable, List<DocumentAmountRow>>
  _documentAmountsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.documentAmounts,
    aliasName: 'documents__id__document_amounts__document_id',
  );

  $$DocumentAmountsTableProcessedTableManager get documentAmountsRefs {
    final manager = $$DocumentAmountsTableTableManager(
      $_db,
      $_db.documentAmounts,
    ).filter((f) => f.documentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _documentAmountsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DocumentActionsTable, List<DocumentActionRow>>
  _documentActionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.documentActions,
    aliasName: 'documents__id__document_actions__document_id',
  );

  $$DocumentActionsTableProcessedTableManager get documentActionsRefs {
    final manager = $$DocumentActionsTableTableManager(
      $_db,
      $_db.documentActions,
    ).filter((f) => f.documentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _documentActionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DocumentWarningsTable, List<DocumentWarningRow>>
  _documentWarningsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.documentWarnings,
    aliasName: 'documents__id__document_warnings__document_id',
  );

  $$DocumentWarningsTableProcessedTableManager get documentWarningsRefs {
    final manager = $$DocumentWarningsTableTableManager(
      $_db,
      $_db.documentWarnings,
    ).filter((f) => f.documentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _documentWarningsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DocumentTextItemsTable, List<DocumentTextItemRow>>
  _documentTextItemsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.documentTextItems,
        aliasName: 'documents__id__document_text_items__document_id',
      );

  $$DocumentTextItemsTableProcessedTableManager get documentTextItemsRefs {
    final manager = $$DocumentTextItemsTableTableManager(
      $_db,
      $_db.documentTextItems,
    ).filter((f) => f.documentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _documentTextItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DocumentsTableFilterComposer
    extends Composer<_$AppDatabase, $DocumentsTable> {
  $$DocumentsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DocumentCategory, DocumentCategory, String>
  get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kindConfidence => $composableBuilder(
    column: $table.kindConfidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summaryShort => $composableBuilder(
    column: $table.summaryShort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summaryDetailed => $composableBuilder(
    column: $table.summaryDetailed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extractedText => $composableBuilder(
    column: $table.extractedText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    DocumentStorageMode,
    DocumentStorageMode,
    String
  >
  get storageMode => $composableBuilder(
    column: $table.storageMode,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get encryptedImagePath => $composableBuilder(
    column: $table.encryptedImagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> documentKeyInformationRefs(
    Expression<bool> Function($$DocumentKeyInformationTableFilterComposer f) f,
  ) {
    final $$DocumentKeyInformationTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.documentKeyInformation,
          getReferencedColumn: (t) => t.documentId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DocumentKeyInformationTableFilterComposer(
                $db: $db,
                $table: $db.documentKeyInformation,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> documentDatesRefs(
    Expression<bool> Function($$DocumentDatesTableFilterComposer f) f,
  ) {
    final $$DocumentDatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.documentDates,
      getReferencedColumn: (t) => t.documentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentDatesTableFilterComposer(
            $db: $db,
            $table: $db.documentDates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> documentAmountsRefs(
    Expression<bool> Function($$DocumentAmountsTableFilterComposer f) f,
  ) {
    final $$DocumentAmountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.documentAmounts,
      getReferencedColumn: (t) => t.documentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentAmountsTableFilterComposer(
            $db: $db,
            $table: $db.documentAmounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> documentActionsRefs(
    Expression<bool> Function($$DocumentActionsTableFilterComposer f) f,
  ) {
    final $$DocumentActionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.documentActions,
      getReferencedColumn: (t) => t.documentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentActionsTableFilterComposer(
            $db: $db,
            $table: $db.documentActions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> documentWarningsRefs(
    Expression<bool> Function($$DocumentWarningsTableFilterComposer f) f,
  ) {
    final $$DocumentWarningsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.documentWarnings,
      getReferencedColumn: (t) => t.documentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentWarningsTableFilterComposer(
            $db: $db,
            $table: $db.documentWarnings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> documentTextItemsRefs(
    Expression<bool> Function($$DocumentTextItemsTableFilterComposer f) f,
  ) {
    final $$DocumentTextItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.documentTextItems,
      getReferencedColumn: (t) => t.documentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentTextItemsTableFilterComposer(
            $db: $db,
            $table: $db.documentTextItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DocumentsTableOrderingComposer
    extends Composer<_$AppDatabase, $DocumentsTable> {
  $$DocumentsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kindConfidence => $composableBuilder(
    column: $table.kindConfidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summaryShort => $composableBuilder(
    column: $table.summaryShort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summaryDetailed => $composableBuilder(
    column: $table.summaryDetailed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extractedText => $composableBuilder(
    column: $table.extractedText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storageMode => $composableBuilder(
    column: $table.storageMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedImagePath => $composableBuilder(
    column: $table.encryptedImagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DocumentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DocumentsTable> {
  $$DocumentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DocumentCategory, String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get kindConfidence => $composableBuilder(
    column: $table.kindConfidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get summaryShort => $composableBuilder(
    column: $table.summaryShort,
    builder: (column) => column,
  );

  GeneratedColumn<String> get summaryDetailed => $composableBuilder(
    column: $table.summaryDetailed,
    builder: (column) => column,
  );

  GeneratedColumn<String> get extractedText => $composableBuilder(
    column: $table.extractedText,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DocumentStorageMode, String>
  get storageMode => $composableBuilder(
    column: $table.storageMode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get encryptedImagePath => $composableBuilder(
    column: $table.encryptedImagePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<DateTime> get savedAt =>
      $composableBuilder(column: $table.savedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> documentKeyInformationRefs<T extends Object>(
    Expression<T> Function($$DocumentKeyInformationTableAnnotationComposer a) f,
  ) {
    final $$DocumentKeyInformationTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.documentKeyInformation,
          getReferencedColumn: (t) => t.documentId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DocumentKeyInformationTableAnnotationComposer(
                $db: $db,
                $table: $db.documentKeyInformation,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> documentDatesRefs<T extends Object>(
    Expression<T> Function($$DocumentDatesTableAnnotationComposer a) f,
  ) {
    final $$DocumentDatesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.documentDates,
      getReferencedColumn: (t) => t.documentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentDatesTableAnnotationComposer(
            $db: $db,
            $table: $db.documentDates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> documentAmountsRefs<T extends Object>(
    Expression<T> Function($$DocumentAmountsTableAnnotationComposer a) f,
  ) {
    final $$DocumentAmountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.documentAmounts,
      getReferencedColumn: (t) => t.documentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentAmountsTableAnnotationComposer(
            $db: $db,
            $table: $db.documentAmounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> documentActionsRefs<T extends Object>(
    Expression<T> Function($$DocumentActionsTableAnnotationComposer a) f,
  ) {
    final $$DocumentActionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.documentActions,
      getReferencedColumn: (t) => t.documentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentActionsTableAnnotationComposer(
            $db: $db,
            $table: $db.documentActions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> documentWarningsRefs<T extends Object>(
    Expression<T> Function($$DocumentWarningsTableAnnotationComposer a) f,
  ) {
    final $$DocumentWarningsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.documentWarnings,
      getReferencedColumn: (t) => t.documentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentWarningsTableAnnotationComposer(
            $db: $db,
            $table: $db.documentWarnings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> documentTextItemsRefs<T extends Object>(
    Expression<T> Function($$DocumentTextItemsTableAnnotationComposer a) f,
  ) {
    final $$DocumentTextItemsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.documentTextItems,
          getReferencedColumn: (t) => t.documentId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DocumentTextItemsTableAnnotationComposer(
                $db: $db,
                $table: $db.documentTextItems,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$DocumentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DocumentsTable,
          DocumentRow,
          $$DocumentsTableFilterComposer,
          $$DocumentsTableOrderingComposer,
          $$DocumentsTableAnnotationComposer,
          $$DocumentsTableCreateCompanionBuilder,
          $$DocumentsTableUpdateCompanionBuilder,
          (DocumentRow, $$DocumentsTableReferences),
          DocumentRow,
          PrefetchHooks Function({
            bool documentKeyInformationRefs,
            bool documentDatesRefs,
            bool documentAmountsRefs,
            bool documentActionsRefs,
            bool documentWarningsRefs,
            bool documentTextItemsRefs,
          })
        > {
  $$DocumentsTableTableManager(_$AppDatabase db, $DocumentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocumentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocumentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DocumentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<DocumentCategory> category = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> kindConfidence = const Value.absent(),
                Value<String> summaryShort = const Value.absent(),
                Value<String> summaryDetailed = const Value.absent(),
                Value<String> extractedText = const Value.absent(),
                Value<DocumentStorageMode> storageMode = const Value.absent(),
                Value<String?> encryptedImagePath = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<DateTime> savedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentsCompanion(
                id: id,
                title: title,
                category: category,
                kind: kind,
                status: status,
                kindConfidence: kindConfidence,
                summaryShort: summaryShort,
                summaryDetailed: summaryDetailed,
                extractedText: extractedText,
                storageMode: storageMode,
                encryptedImagePath: encryptedImagePath,
                note: note,
                sessionId: sessionId,
                savedAt: savedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required DocumentCategory category,
                required String kind,
                required String status,
                required String kindConfidence,
                required String summaryShort,
                required String summaryDetailed,
                required String extractedText,
                required DocumentStorageMode storageMode,
                Value<String?> encryptedImagePath = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required String sessionId,
                required DateTime savedAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => DocumentsCompanion.insert(
                id: id,
                title: title,
                category: category,
                kind: kind,
                status: status,
                kindConfidence: kindConfidence,
                summaryShort: summaryShort,
                summaryDetailed: summaryDetailed,
                extractedText: extractedText,
                storageMode: storageMode,
                encryptedImagePath: encryptedImagePath,
                note: note,
                sessionId: sessionId,
                savedAt: savedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DocumentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                documentKeyInformationRefs = false,
                documentDatesRefs = false,
                documentAmountsRefs = false,
                documentActionsRefs = false,
                documentWarningsRefs = false,
                documentTextItemsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (documentKeyInformationRefs) db.documentKeyInformation,
                    if (documentDatesRefs) db.documentDates,
                    if (documentAmountsRefs) db.documentAmounts,
                    if (documentActionsRefs) db.documentActions,
                    if (documentWarningsRefs) db.documentWarnings,
                    if (documentTextItemsRefs) db.documentTextItems,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (documentKeyInformationRefs)
                        await $_getPrefetchedData<
                          DocumentRow,
                          $DocumentsTable,
                          DocumentInfoRow
                        >(
                          currentTable: table,
                          referencedTable: $$DocumentsTableReferences
                              ._documentKeyInformationRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DocumentsTableReferences(
                                db,
                                table,
                                p0,
                              ).documentKeyInformationRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.documentId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (documentDatesRefs)
                        await $_getPrefetchedData<
                          DocumentRow,
                          $DocumentsTable,
                          DocumentDateRow
                        >(
                          currentTable: table,
                          referencedTable: $$DocumentsTableReferences
                              ._documentDatesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DocumentsTableReferences(
                                db,
                                table,
                                p0,
                              ).documentDatesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.documentId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (documentAmountsRefs)
                        await $_getPrefetchedData<
                          DocumentRow,
                          $DocumentsTable,
                          DocumentAmountRow
                        >(
                          currentTable: table,
                          referencedTable: $$DocumentsTableReferences
                              ._documentAmountsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DocumentsTableReferences(
                                db,
                                table,
                                p0,
                              ).documentAmountsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.documentId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (documentActionsRefs)
                        await $_getPrefetchedData<
                          DocumentRow,
                          $DocumentsTable,
                          DocumentActionRow
                        >(
                          currentTable: table,
                          referencedTable: $$DocumentsTableReferences
                              ._documentActionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DocumentsTableReferences(
                                db,
                                table,
                                p0,
                              ).documentActionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.documentId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (documentWarningsRefs)
                        await $_getPrefetchedData<
                          DocumentRow,
                          $DocumentsTable,
                          DocumentWarningRow
                        >(
                          currentTable: table,
                          referencedTable: $$DocumentsTableReferences
                              ._documentWarningsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DocumentsTableReferences(
                                db,
                                table,
                                p0,
                              ).documentWarningsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.documentId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (documentTextItemsRefs)
                        await $_getPrefetchedData<
                          DocumentRow,
                          $DocumentsTable,
                          DocumentTextItemRow
                        >(
                          currentTable: table,
                          referencedTable: $$DocumentsTableReferences
                              ._documentTextItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DocumentsTableReferences(
                                db,
                                table,
                                p0,
                              ).documentTextItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.documentId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$DocumentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DocumentsTable,
      DocumentRow,
      $$DocumentsTableFilterComposer,
      $$DocumentsTableOrderingComposer,
      $$DocumentsTableAnnotationComposer,
      $$DocumentsTableCreateCompanionBuilder,
      $$DocumentsTableUpdateCompanionBuilder,
      (DocumentRow, $$DocumentsTableReferences),
      DocumentRow,
      PrefetchHooks Function({
        bool documentKeyInformationRefs,
        bool documentDatesRefs,
        bool documentAmountsRefs,
        bool documentActionsRefs,
        bool documentWarningsRefs,
        bool documentTextItemsRefs,
      })
    >;
typedef $$DocumentKeyInformationTableCreateCompanionBuilder =
    DocumentKeyInformationCompanion Function({
      required String documentId,
      required int position,
      required String label,
      required String value,
      required String confidence,
      required String source,
      Value<int> rowid,
    });
typedef $$DocumentKeyInformationTableUpdateCompanionBuilder =
    DocumentKeyInformationCompanion Function({
      Value<String> documentId,
      Value<int> position,
      Value<String> label,
      Value<String> value,
      Value<String> confidence,
      Value<String> source,
      Value<int> rowid,
    });

final class $$DocumentKeyInformationTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $DocumentKeyInformationTable,
          DocumentInfoRow
        > {
  $$DocumentKeyInformationTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DocumentsTable _documentIdTable(_$AppDatabase db) => db.documents
      .createAlias('document_key_information__document_id__documents__id');

  $$DocumentsTableProcessedTableManager get documentId {
    final $_column = $_itemColumn<String>('document_id')!;

    final manager = $$DocumentsTableTableManager(
      $_db,
      $_db.documents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_documentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DocumentKeyInformationTableFilterComposer
    extends Composer<_$AppDatabase, $DocumentKeyInformationTable> {
  $$DocumentKeyInformationTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  $$DocumentsTableFilterComposer get documentId {
    final $$DocumentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableFilterComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentKeyInformationTableOrderingComposer
    extends Composer<_$AppDatabase, $DocumentKeyInformationTable> {
  $$DocumentKeyInformationTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  $$DocumentsTableOrderingComposer get documentId {
    final $$DocumentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableOrderingComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentKeyInformationTableAnnotationComposer
    extends Composer<_$AppDatabase, $DocumentKeyInformationTable> {
  $$DocumentKeyInformationTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  $$DocumentsTableAnnotationComposer get documentId {
    final $$DocumentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableAnnotationComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentKeyInformationTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DocumentKeyInformationTable,
          DocumentInfoRow,
          $$DocumentKeyInformationTableFilterComposer,
          $$DocumentKeyInformationTableOrderingComposer,
          $$DocumentKeyInformationTableAnnotationComposer,
          $$DocumentKeyInformationTableCreateCompanionBuilder,
          $$DocumentKeyInformationTableUpdateCompanionBuilder,
          (DocumentInfoRow, $$DocumentKeyInformationTableReferences),
          DocumentInfoRow,
          PrefetchHooks Function({bool documentId})
        > {
  $$DocumentKeyInformationTableTableManager(
    _$AppDatabase db,
    $DocumentKeyInformationTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocumentKeyInformationTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$DocumentKeyInformationTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DocumentKeyInformationTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> documentId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<String> confidence = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentKeyInformationCompanion(
                documentId: documentId,
                position: position,
                label: label,
                value: value,
                confidence: confidence,
                source: source,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String documentId,
                required int position,
                required String label,
                required String value,
                required String confidence,
                required String source,
                Value<int> rowid = const Value.absent(),
              }) => DocumentKeyInformationCompanion.insert(
                documentId: documentId,
                position: position,
                label: label,
                value: value,
                confidence: confidence,
                source: source,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DocumentKeyInformationTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({documentId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (documentId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.documentId,
                                referencedTable:
                                    $$DocumentKeyInformationTableReferences
                                        ._documentIdTable(db),
                                referencedColumn:
                                    $$DocumentKeyInformationTableReferences
                                        ._documentIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DocumentKeyInformationTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DocumentKeyInformationTable,
      DocumentInfoRow,
      $$DocumentKeyInformationTableFilterComposer,
      $$DocumentKeyInformationTableOrderingComposer,
      $$DocumentKeyInformationTableAnnotationComposer,
      $$DocumentKeyInformationTableCreateCompanionBuilder,
      $$DocumentKeyInformationTableUpdateCompanionBuilder,
      (DocumentInfoRow, $$DocumentKeyInformationTableReferences),
      DocumentInfoRow,
      PrefetchHooks Function({bool documentId})
    >;
typedef $$DocumentDatesTableCreateCompanionBuilder =
    DocumentDatesCompanion Function({
      required String documentId,
      required int position,
      required String label,
      required DateTime date,
      Value<int?> minuteOfDay,
      required String role,
      required bool isReminderWorthy,
      required String confidence,
      Value<int> rowid,
    });
typedef $$DocumentDatesTableUpdateCompanionBuilder =
    DocumentDatesCompanion Function({
      Value<String> documentId,
      Value<int> position,
      Value<String> label,
      Value<DateTime> date,
      Value<int?> minuteOfDay,
      Value<String> role,
      Value<bool> isReminderWorthy,
      Value<String> confidence,
      Value<int> rowid,
    });

final class $$DocumentDatesTableReferences
    extends
        BaseReferences<_$AppDatabase, $DocumentDatesTable, DocumentDateRow> {
  $$DocumentDatesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DocumentsTable _documentIdTable(_$AppDatabase db) =>
      db.documents.createAlias('document_dates__document_id__documents__id');

  $$DocumentsTableProcessedTableManager get documentId {
    final $_column = $_itemColumn<String>('document_id')!;

    final manager = $$DocumentsTableTableManager(
      $_db,
      $_db.documents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_documentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DocumentDatesTableFilterComposer
    extends Composer<_$AppDatabase, $DocumentDatesTable> {
  $$DocumentDatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minuteOfDay => $composableBuilder(
    column: $table.minuteOfDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isReminderWorthy => $composableBuilder(
    column: $table.isReminderWorthy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  $$DocumentsTableFilterComposer get documentId {
    final $$DocumentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableFilterComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentDatesTableOrderingComposer
    extends Composer<_$AppDatabase, $DocumentDatesTable> {
  $$DocumentDatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minuteOfDay => $composableBuilder(
    column: $table.minuteOfDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isReminderWorthy => $composableBuilder(
    column: $table.isReminderWorthy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  $$DocumentsTableOrderingComposer get documentId {
    final $$DocumentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableOrderingComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentDatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DocumentDatesTable> {
  $$DocumentDatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get minuteOfDay => $composableBuilder(
    column: $table.minuteOfDay,
    builder: (column) => column,
  );

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<bool> get isReminderWorthy => $composableBuilder(
    column: $table.isReminderWorthy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  $$DocumentsTableAnnotationComposer get documentId {
    final $$DocumentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableAnnotationComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentDatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DocumentDatesTable,
          DocumentDateRow,
          $$DocumentDatesTableFilterComposer,
          $$DocumentDatesTableOrderingComposer,
          $$DocumentDatesTableAnnotationComposer,
          $$DocumentDatesTableCreateCompanionBuilder,
          $$DocumentDatesTableUpdateCompanionBuilder,
          (DocumentDateRow, $$DocumentDatesTableReferences),
          DocumentDateRow,
          PrefetchHooks Function({bool documentId})
        > {
  $$DocumentDatesTableTableManager(_$AppDatabase db, $DocumentDatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocumentDatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocumentDatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DocumentDatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> documentId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<int?> minuteOfDay = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<bool> isReminderWorthy = const Value.absent(),
                Value<String> confidence = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentDatesCompanion(
                documentId: documentId,
                position: position,
                label: label,
                date: date,
                minuteOfDay: minuteOfDay,
                role: role,
                isReminderWorthy: isReminderWorthy,
                confidence: confidence,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String documentId,
                required int position,
                required String label,
                required DateTime date,
                Value<int?> minuteOfDay = const Value.absent(),
                required String role,
                required bool isReminderWorthy,
                required String confidence,
                Value<int> rowid = const Value.absent(),
              }) => DocumentDatesCompanion.insert(
                documentId: documentId,
                position: position,
                label: label,
                date: date,
                minuteOfDay: minuteOfDay,
                role: role,
                isReminderWorthy: isReminderWorthy,
                confidence: confidence,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DocumentDatesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({documentId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (documentId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.documentId,
                                referencedTable: $$DocumentDatesTableReferences
                                    ._documentIdTable(db),
                                referencedColumn: $$DocumentDatesTableReferences
                                    ._documentIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DocumentDatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DocumentDatesTable,
      DocumentDateRow,
      $$DocumentDatesTableFilterComposer,
      $$DocumentDatesTableOrderingComposer,
      $$DocumentDatesTableAnnotationComposer,
      $$DocumentDatesTableCreateCompanionBuilder,
      $$DocumentDatesTableUpdateCompanionBuilder,
      (DocumentDateRow, $$DocumentDatesTableReferences),
      DocumentDateRow,
      PrefetchHooks Function({bool documentId})
    >;
typedef $$DocumentAmountsTableCreateCompanionBuilder =
    DocumentAmountsCompanion Function({
      required String documentId,
      required int position,
      required String label,
      required double value,
      required String currency,
      required String confidence,
      Value<int> rowid,
    });
typedef $$DocumentAmountsTableUpdateCompanionBuilder =
    DocumentAmountsCompanion Function({
      Value<String> documentId,
      Value<int> position,
      Value<String> label,
      Value<double> value,
      Value<String> currency,
      Value<String> confidence,
      Value<int> rowid,
    });

final class $$DocumentAmountsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $DocumentAmountsTable,
          DocumentAmountRow
        > {
  $$DocumentAmountsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DocumentsTable _documentIdTable(_$AppDatabase db) =>
      db.documents.createAlias('document_amounts__document_id__documents__id');

  $$DocumentsTableProcessedTableManager get documentId {
    final $_column = $_itemColumn<String>('document_id')!;

    final manager = $$DocumentsTableTableManager(
      $_db,
      $_db.documents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_documentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DocumentAmountsTableFilterComposer
    extends Composer<_$AppDatabase, $DocumentAmountsTable> {
  $$DocumentAmountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  $$DocumentsTableFilterComposer get documentId {
    final $$DocumentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableFilterComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentAmountsTableOrderingComposer
    extends Composer<_$AppDatabase, $DocumentAmountsTable> {
  $$DocumentAmountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  $$DocumentsTableOrderingComposer get documentId {
    final $$DocumentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableOrderingComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentAmountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DocumentAmountsTable> {
  $$DocumentAmountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<double> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  $$DocumentsTableAnnotationComposer get documentId {
    final $$DocumentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableAnnotationComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentAmountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DocumentAmountsTable,
          DocumentAmountRow,
          $$DocumentAmountsTableFilterComposer,
          $$DocumentAmountsTableOrderingComposer,
          $$DocumentAmountsTableAnnotationComposer,
          $$DocumentAmountsTableCreateCompanionBuilder,
          $$DocumentAmountsTableUpdateCompanionBuilder,
          (DocumentAmountRow, $$DocumentAmountsTableReferences),
          DocumentAmountRow,
          PrefetchHooks Function({bool documentId})
        > {
  $$DocumentAmountsTableTableManager(
    _$AppDatabase db,
    $DocumentAmountsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocumentAmountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocumentAmountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DocumentAmountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> documentId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<double> value = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> confidence = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentAmountsCompanion(
                documentId: documentId,
                position: position,
                label: label,
                value: value,
                currency: currency,
                confidence: confidence,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String documentId,
                required int position,
                required String label,
                required double value,
                required String currency,
                required String confidence,
                Value<int> rowid = const Value.absent(),
              }) => DocumentAmountsCompanion.insert(
                documentId: documentId,
                position: position,
                label: label,
                value: value,
                currency: currency,
                confidence: confidence,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DocumentAmountsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({documentId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (documentId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.documentId,
                                referencedTable:
                                    $$DocumentAmountsTableReferences
                                        ._documentIdTable(db),
                                referencedColumn:
                                    $$DocumentAmountsTableReferences
                                        ._documentIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DocumentAmountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DocumentAmountsTable,
      DocumentAmountRow,
      $$DocumentAmountsTableFilterComposer,
      $$DocumentAmountsTableOrderingComposer,
      $$DocumentAmountsTableAnnotationComposer,
      $$DocumentAmountsTableCreateCompanionBuilder,
      $$DocumentAmountsTableUpdateCompanionBuilder,
      (DocumentAmountRow, $$DocumentAmountsTableReferences),
      DocumentAmountRow,
      PrefetchHooks Function({bool documentId})
    >;
typedef $$DocumentActionsTableCreateCompanionBuilder =
    DocumentActionsCompanion Function({
      required String documentId,
      required int position,
      required String description,
      required String basis,
      required String priority,
      Value<int> rowid,
    });
typedef $$DocumentActionsTableUpdateCompanionBuilder =
    DocumentActionsCompanion Function({
      Value<String> documentId,
      Value<int> position,
      Value<String> description,
      Value<String> basis,
      Value<String> priority,
      Value<int> rowid,
    });

final class $$DocumentActionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $DocumentActionsTable,
          DocumentActionRow
        > {
  $$DocumentActionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DocumentsTable _documentIdTable(_$AppDatabase db) =>
      db.documents.createAlias('document_actions__document_id__documents__id');

  $$DocumentsTableProcessedTableManager get documentId {
    final $_column = $_itemColumn<String>('document_id')!;

    final manager = $$DocumentsTableTableManager(
      $_db,
      $_db.documents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_documentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DocumentActionsTableFilterComposer
    extends Composer<_$AppDatabase, $DocumentActionsTable> {
  $$DocumentActionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get basis => $composableBuilder(
    column: $table.basis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  $$DocumentsTableFilterComposer get documentId {
    final $$DocumentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableFilterComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentActionsTableOrderingComposer
    extends Composer<_$AppDatabase, $DocumentActionsTable> {
  $$DocumentActionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get basis => $composableBuilder(
    column: $table.basis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  $$DocumentsTableOrderingComposer get documentId {
    final $$DocumentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableOrderingComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentActionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DocumentActionsTable> {
  $$DocumentActionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get basis =>
      $composableBuilder(column: $table.basis, builder: (column) => column);

  GeneratedColumn<String> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  $$DocumentsTableAnnotationComposer get documentId {
    final $$DocumentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableAnnotationComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentActionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DocumentActionsTable,
          DocumentActionRow,
          $$DocumentActionsTableFilterComposer,
          $$DocumentActionsTableOrderingComposer,
          $$DocumentActionsTableAnnotationComposer,
          $$DocumentActionsTableCreateCompanionBuilder,
          $$DocumentActionsTableUpdateCompanionBuilder,
          (DocumentActionRow, $$DocumentActionsTableReferences),
          DocumentActionRow,
          PrefetchHooks Function({bool documentId})
        > {
  $$DocumentActionsTableTableManager(
    _$AppDatabase db,
    $DocumentActionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocumentActionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocumentActionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DocumentActionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> documentId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> basis = const Value.absent(),
                Value<String> priority = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentActionsCompanion(
                documentId: documentId,
                position: position,
                description: description,
                basis: basis,
                priority: priority,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String documentId,
                required int position,
                required String description,
                required String basis,
                required String priority,
                Value<int> rowid = const Value.absent(),
              }) => DocumentActionsCompanion.insert(
                documentId: documentId,
                position: position,
                description: description,
                basis: basis,
                priority: priority,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DocumentActionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({documentId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (documentId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.documentId,
                                referencedTable:
                                    $$DocumentActionsTableReferences
                                        ._documentIdTable(db),
                                referencedColumn:
                                    $$DocumentActionsTableReferences
                                        ._documentIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DocumentActionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DocumentActionsTable,
      DocumentActionRow,
      $$DocumentActionsTableFilterComposer,
      $$DocumentActionsTableOrderingComposer,
      $$DocumentActionsTableAnnotationComposer,
      $$DocumentActionsTableCreateCompanionBuilder,
      $$DocumentActionsTableUpdateCompanionBuilder,
      (DocumentActionRow, $$DocumentActionsTableReferences),
      DocumentActionRow,
      PrefetchHooks Function({bool documentId})
    >;
typedef $$DocumentWarningsTableCreateCompanionBuilder =
    DocumentWarningsCompanion Function({
      required String documentId,
      required int position,
      required String message,
      required String kind,
      Value<int> rowid,
    });
typedef $$DocumentWarningsTableUpdateCompanionBuilder =
    DocumentWarningsCompanion Function({
      Value<String> documentId,
      Value<int> position,
      Value<String> message,
      Value<String> kind,
      Value<int> rowid,
    });

final class $$DocumentWarningsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $DocumentWarningsTable,
          DocumentWarningRow
        > {
  $$DocumentWarningsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DocumentsTable _documentIdTable(_$AppDatabase db) =>
      db.documents.createAlias('document_warnings__document_id__documents__id');

  $$DocumentsTableProcessedTableManager get documentId {
    final $_column = $_itemColumn<String>('document_id')!;

    final manager = $$DocumentsTableTableManager(
      $_db,
      $_db.documents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_documentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DocumentWarningsTableFilterComposer
    extends Composer<_$AppDatabase, $DocumentWarningsTable> {
  $$DocumentWarningsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  $$DocumentsTableFilterComposer get documentId {
    final $$DocumentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableFilterComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentWarningsTableOrderingComposer
    extends Composer<_$AppDatabase, $DocumentWarningsTable> {
  $$DocumentWarningsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  $$DocumentsTableOrderingComposer get documentId {
    final $$DocumentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableOrderingComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentWarningsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DocumentWarningsTable> {
  $$DocumentWarningsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get message =>
      $composableBuilder(column: $table.message, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  $$DocumentsTableAnnotationComposer get documentId {
    final $$DocumentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableAnnotationComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentWarningsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DocumentWarningsTable,
          DocumentWarningRow,
          $$DocumentWarningsTableFilterComposer,
          $$DocumentWarningsTableOrderingComposer,
          $$DocumentWarningsTableAnnotationComposer,
          $$DocumentWarningsTableCreateCompanionBuilder,
          $$DocumentWarningsTableUpdateCompanionBuilder,
          (DocumentWarningRow, $$DocumentWarningsTableReferences),
          DocumentWarningRow,
          PrefetchHooks Function({bool documentId})
        > {
  $$DocumentWarningsTableTableManager(
    _$AppDatabase db,
    $DocumentWarningsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocumentWarningsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocumentWarningsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DocumentWarningsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> documentId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> message = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentWarningsCompanion(
                documentId: documentId,
                position: position,
                message: message,
                kind: kind,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String documentId,
                required int position,
                required String message,
                required String kind,
                Value<int> rowid = const Value.absent(),
              }) => DocumentWarningsCompanion.insert(
                documentId: documentId,
                position: position,
                message: message,
                kind: kind,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DocumentWarningsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({documentId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (documentId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.documentId,
                                referencedTable:
                                    $$DocumentWarningsTableReferences
                                        ._documentIdTable(db),
                                referencedColumn:
                                    $$DocumentWarningsTableReferences
                                        ._documentIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DocumentWarningsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DocumentWarningsTable,
      DocumentWarningRow,
      $$DocumentWarningsTableFilterComposer,
      $$DocumentWarningsTableOrderingComposer,
      $$DocumentWarningsTableAnnotationComposer,
      $$DocumentWarningsTableCreateCompanionBuilder,
      $$DocumentWarningsTableUpdateCompanionBuilder,
      (DocumentWarningRow, $$DocumentWarningsTableReferences),
      DocumentWarningRow,
      PrefetchHooks Function({bool documentId})
    >;
typedef $$DocumentTextItemsTableCreateCompanionBuilder =
    DocumentTextItemsCompanion Function({
      required String documentId,
      required DocumentTextItemKind kind,
      required int position,
      required String value,
      Value<int> rowid,
    });
typedef $$DocumentTextItemsTableUpdateCompanionBuilder =
    DocumentTextItemsCompanion Function({
      Value<String> documentId,
      Value<DocumentTextItemKind> kind,
      Value<int> position,
      Value<String> value,
      Value<int> rowid,
    });

final class $$DocumentTextItemsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $DocumentTextItemsTable,
          DocumentTextItemRow
        > {
  $$DocumentTextItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DocumentsTable _documentIdTable(_$AppDatabase db) => db.documents
      .createAlias('document_text_items__document_id__documents__id');

  $$DocumentsTableProcessedTableManager get documentId {
    final $_column = $_itemColumn<String>('document_id')!;

    final manager = $$DocumentsTableTableManager(
      $_db,
      $_db.documents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_documentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DocumentTextItemsTableFilterComposer
    extends Composer<_$AppDatabase, $DocumentTextItemsTable> {
  $$DocumentTextItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<
    DocumentTextItemKind,
    DocumentTextItemKind,
    String
  >
  get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  $$DocumentsTableFilterComposer get documentId {
    final $$DocumentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableFilterComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentTextItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $DocumentTextItemsTable> {
  $$DocumentTextItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  $$DocumentsTableOrderingComposer get documentId {
    final $$DocumentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableOrderingComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentTextItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DocumentTextItemsTable> {
  $$DocumentTextItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<DocumentTextItemKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  $$DocumentsTableAnnotationComposer get documentId {
    final $$DocumentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableAnnotationComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentTextItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DocumentTextItemsTable,
          DocumentTextItemRow,
          $$DocumentTextItemsTableFilterComposer,
          $$DocumentTextItemsTableOrderingComposer,
          $$DocumentTextItemsTableAnnotationComposer,
          $$DocumentTextItemsTableCreateCompanionBuilder,
          $$DocumentTextItemsTableUpdateCompanionBuilder,
          (DocumentTextItemRow, $$DocumentTextItemsTableReferences),
          DocumentTextItemRow,
          PrefetchHooks Function({bool documentId})
        > {
  $$DocumentTextItemsTableTableManager(
    _$AppDatabase db,
    $DocumentTextItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocumentTextItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocumentTextItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DocumentTextItemsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> documentId = const Value.absent(),
                Value<DocumentTextItemKind> kind = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentTextItemsCompanion(
                documentId: documentId,
                kind: kind,
                position: position,
                value: value,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String documentId,
                required DocumentTextItemKind kind,
                required int position,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => DocumentTextItemsCompanion.insert(
                documentId: documentId,
                kind: kind,
                position: position,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DocumentTextItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({documentId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (documentId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.documentId,
                                referencedTable:
                                    $$DocumentTextItemsTableReferences
                                        ._documentIdTable(db),
                                referencedColumn:
                                    $$DocumentTextItemsTableReferences
                                        ._documentIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DocumentTextItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DocumentTextItemsTable,
      DocumentTextItemRow,
      $$DocumentTextItemsTableFilterComposer,
      $$DocumentTextItemsTableOrderingComposer,
      $$DocumentTextItemsTableAnnotationComposer,
      $$DocumentTextItemsTableCreateCompanionBuilder,
      $$DocumentTextItemsTableUpdateCompanionBuilder,
      (DocumentTextItemRow, $$DocumentTextItemsTableReferences),
      DocumentTextItemRow,
      PrefetchHooks Function({bool documentId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$UsageCacheTableTableManager get usageCache =>
      $$UsageCacheTableTableManager(_db, _db.usageCache);
  $$DocumentsTableTableManager get documents =>
      $$DocumentsTableTableManager(_db, _db.documents);
  $$DocumentKeyInformationTableTableManager get documentKeyInformation =>
      $$DocumentKeyInformationTableTableManager(
        _db,
        _db.documentKeyInformation,
      );
  $$DocumentDatesTableTableManager get documentDates =>
      $$DocumentDatesTableTableManager(_db, _db.documentDates);
  $$DocumentAmountsTableTableManager get documentAmounts =>
      $$DocumentAmountsTableTableManager(_db, _db.documentAmounts);
  $$DocumentActionsTableTableManager get documentActions =>
      $$DocumentActionsTableTableManager(_db, _db.documentActions);
  $$DocumentWarningsTableTableManager get documentWarnings =>
      $$DocumentWarningsTableTableManager(_db, _db.documentWarnings);
  $$DocumentTextItemsTableTableManager get documentTextItems =>
      $$DocumentTextItemsTableTableManager(_db, _db.documentTextItems);
}
