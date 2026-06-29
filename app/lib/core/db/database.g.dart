// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $AthletesTable extends Athletes with TableInfo<$AthletesTable, Athlete> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AthletesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _restingHeartrateMeta = const VerificationMeta(
    'restingHeartrate',
  );
  @override
  late final GeneratedColumn<int> restingHeartrate = GeneratedColumn<int>(
    'resting_heartrate',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _maxHeartrateMeta = const VerificationMeta(
    'maxHeartrate',
  );
  @override
  late final GeneratedColumn<int> maxHeartrate = GeneratedColumn<int>(
    'max_heartrate',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    restingHeartrate,
    maxHeartrate,
    createdAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'athletes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Athlete> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('resting_heartrate')) {
      context.handle(
        _restingHeartrateMeta,
        restingHeartrate.isAcceptableOrUnknown(
          data['resting_heartrate']!,
          _restingHeartrateMeta,
        ),
      );
    }
    if (data.containsKey('max_heartrate')) {
      context.handle(
        _maxHeartrateMeta,
        maxHeartrate.isAcceptableOrUnknown(
          data['max_heartrate']!,
          _maxHeartrateMeta,
        ),
      );
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Athlete map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Athlete(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      restingHeartrate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}resting_heartrate'],
      ),
      maxHeartrate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_heartrate'],
      ),
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
    );
  }

  @override
  $AthletesTable createAlias(String alias) {
    return $AthletesTable(attachedDatabase, alias);
  }
}

class Athlete extends DataClass implements Insertable<Athlete> {
  final int id;
  final String name;
  final int? restingHeartrate;
  final int? maxHeartrate;
  final int createdAtMs;
  const Athlete({
    required this.id,
    required this.name,
    this.restingHeartrate,
    this.maxHeartrate,
    required this.createdAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || restingHeartrate != null) {
      map['resting_heartrate'] = Variable<int>(restingHeartrate);
    }
    if (!nullToAbsent || maxHeartrate != null) {
      map['max_heartrate'] = Variable<int>(maxHeartrate);
    }
    map['created_at_ms'] = Variable<int>(createdAtMs);
    return map;
  }

  AthletesCompanion toCompanion(bool nullToAbsent) {
    return AthletesCompanion(
      id: Value(id),
      name: Value(name),
      restingHeartrate: restingHeartrate == null && nullToAbsent
          ? const Value.absent()
          : Value(restingHeartrate),
      maxHeartrate: maxHeartrate == null && nullToAbsent
          ? const Value.absent()
          : Value(maxHeartrate),
      createdAtMs: Value(createdAtMs),
    );
  }

  factory Athlete.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Athlete(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      restingHeartrate: serializer.fromJson<int?>(json['restingHeartrate']),
      maxHeartrate: serializer.fromJson<int?>(json['maxHeartrate']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'restingHeartrate': serializer.toJson<int?>(restingHeartrate),
      'maxHeartrate': serializer.toJson<int?>(maxHeartrate),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
    };
  }

  Athlete copyWith({
    int? id,
    String? name,
    Value<int?> restingHeartrate = const Value.absent(),
    Value<int?> maxHeartrate = const Value.absent(),
    int? createdAtMs,
  }) => Athlete(
    id: id ?? this.id,
    name: name ?? this.name,
    restingHeartrate: restingHeartrate.present
        ? restingHeartrate.value
        : this.restingHeartrate,
    maxHeartrate: maxHeartrate.present ? maxHeartrate.value : this.maxHeartrate,
    createdAtMs: createdAtMs ?? this.createdAtMs,
  );
  Athlete copyWithCompanion(AthletesCompanion data) {
    return Athlete(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      restingHeartrate: data.restingHeartrate.present
          ? data.restingHeartrate.value
          : this.restingHeartrate,
      maxHeartrate: data.maxHeartrate.present
          ? data.maxHeartrate.value
          : this.maxHeartrate,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Athlete(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('restingHeartrate: $restingHeartrate, ')
          ..write('maxHeartrate: $maxHeartrate, ')
          ..write('createdAtMs: $createdAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, restingHeartrate, maxHeartrate, createdAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Athlete &&
          other.id == this.id &&
          other.name == this.name &&
          other.restingHeartrate == this.restingHeartrate &&
          other.maxHeartrate == this.maxHeartrate &&
          other.createdAtMs == this.createdAtMs);
}

class AthletesCompanion extends UpdateCompanion<Athlete> {
  final Value<int> id;
  final Value<String> name;
  final Value<int?> restingHeartrate;
  final Value<int?> maxHeartrate;
  final Value<int> createdAtMs;
  const AthletesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.restingHeartrate = const Value.absent(),
    this.maxHeartrate = const Value.absent(),
    this.createdAtMs = const Value.absent(),
  });
  AthletesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.restingHeartrate = const Value.absent(),
    this.maxHeartrate = const Value.absent(),
    required int createdAtMs,
  }) : name = Value(name),
       createdAtMs = Value(createdAtMs);
  static Insertable<Athlete> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? restingHeartrate,
    Expression<int>? maxHeartrate,
    Expression<int>? createdAtMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (restingHeartrate != null) 'resting_heartrate': restingHeartrate,
      if (maxHeartrate != null) 'max_heartrate': maxHeartrate,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
    });
  }

  AthletesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int?>? restingHeartrate,
    Value<int?>? maxHeartrate,
    Value<int>? createdAtMs,
  }) {
    return AthletesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      restingHeartrate: restingHeartrate ?? this.restingHeartrate,
      maxHeartrate: maxHeartrate ?? this.maxHeartrate,
      createdAtMs: createdAtMs ?? this.createdAtMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (restingHeartrate.present) {
      map['resting_heartrate'] = Variable<int>(restingHeartrate.value);
    }
    if (maxHeartrate.present) {
      map['max_heartrate'] = Variable<int>(maxHeartrate.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AthletesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('restingHeartrate: $restingHeartrate, ')
          ..write('maxHeartrate: $maxHeartrate, ')
          ..write('createdAtMs: $createdAtMs')
          ..write(')'))
        .toString();
  }
}

class $DevicesTable extends Devices with TableInfo<$DevicesTable, Device> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DevicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _platformIdMeta = const VerificationMeta(
    'platformId',
  );
  @override
  late final GeneratedColumn<String> platformId = GeneratedColumn<String>(
    'platform_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastConnectedAtMsMeta = const VerificationMeta(
    'lastConnectedAtMs',
  );
  @override
  late final GeneratedColumn<int> lastConnectedAtMs = GeneratedColumn<int>(
    'last_connected_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    platformId,
    name,
    lastConnectedAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'devices';
  @override
  VerificationContext validateIntegrity(
    Insertable<Device> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('platform_id')) {
      context.handle(
        _platformIdMeta,
        platformId.isAcceptableOrUnknown(data['platform_id']!, _platformIdMeta),
      );
    } else if (isInserting) {
      context.missing(_platformIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('last_connected_at_ms')) {
      context.handle(
        _lastConnectedAtMsMeta,
        lastConnectedAtMs.isAcceptableOrUnknown(
          data['last_connected_at_ms']!,
          _lastConnectedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastConnectedAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Device map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Device(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      platformId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}platform_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      lastConnectedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_connected_at_ms'],
      )!,
    );
  }

  @override
  $DevicesTable createAlias(String alias) {
    return $DevicesTable(attachedDatabase, alias);
  }
}

class Device extends DataClass implements Insertable<Device> {
  final int id;
  final String platformId;
  final String name;
  final int lastConnectedAtMs;
  const Device({
    required this.id,
    required this.platformId,
    required this.name,
    required this.lastConnectedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['platform_id'] = Variable<String>(platformId);
    map['name'] = Variable<String>(name);
    map['last_connected_at_ms'] = Variable<int>(lastConnectedAtMs);
    return map;
  }

  DevicesCompanion toCompanion(bool nullToAbsent) {
    return DevicesCompanion(
      id: Value(id),
      platformId: Value(platformId),
      name: Value(name),
      lastConnectedAtMs: Value(lastConnectedAtMs),
    );
  }

  factory Device.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Device(
      id: serializer.fromJson<int>(json['id']),
      platformId: serializer.fromJson<String>(json['platformId']),
      name: serializer.fromJson<String>(json['name']),
      lastConnectedAtMs: serializer.fromJson<int>(json['lastConnectedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'platformId': serializer.toJson<String>(platformId),
      'name': serializer.toJson<String>(name),
      'lastConnectedAtMs': serializer.toJson<int>(lastConnectedAtMs),
    };
  }

  Device copyWith({
    int? id,
    String? platformId,
    String? name,
    int? lastConnectedAtMs,
  }) => Device(
    id: id ?? this.id,
    platformId: platformId ?? this.platformId,
    name: name ?? this.name,
    lastConnectedAtMs: lastConnectedAtMs ?? this.lastConnectedAtMs,
  );
  Device copyWithCompanion(DevicesCompanion data) {
    return Device(
      id: data.id.present ? data.id.value : this.id,
      platformId: data.platformId.present
          ? data.platformId.value
          : this.platformId,
      name: data.name.present ? data.name.value : this.name,
      lastConnectedAtMs: data.lastConnectedAtMs.present
          ? data.lastConnectedAtMs.value
          : this.lastConnectedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Device(')
          ..write('id: $id, ')
          ..write('platformId: $platformId, ')
          ..write('name: $name, ')
          ..write('lastConnectedAtMs: $lastConnectedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, platformId, name, lastConnectedAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Device &&
          other.id == this.id &&
          other.platformId == this.platformId &&
          other.name == this.name &&
          other.lastConnectedAtMs == this.lastConnectedAtMs);
}

class DevicesCompanion extends UpdateCompanion<Device> {
  final Value<int> id;
  final Value<String> platformId;
  final Value<String> name;
  final Value<int> lastConnectedAtMs;
  const DevicesCompanion({
    this.id = const Value.absent(),
    this.platformId = const Value.absent(),
    this.name = const Value.absent(),
    this.lastConnectedAtMs = const Value.absent(),
  });
  DevicesCompanion.insert({
    this.id = const Value.absent(),
    required String platformId,
    required String name,
    required int lastConnectedAtMs,
  }) : platformId = Value(platformId),
       name = Value(name),
       lastConnectedAtMs = Value(lastConnectedAtMs);
  static Insertable<Device> custom({
    Expression<int>? id,
    Expression<String>? platformId,
    Expression<String>? name,
    Expression<int>? lastConnectedAtMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (platformId != null) 'platform_id': platformId,
      if (name != null) 'name': name,
      if (lastConnectedAtMs != null) 'last_connected_at_ms': lastConnectedAtMs,
    });
  }

  DevicesCompanion copyWith({
    Value<int>? id,
    Value<String>? platformId,
    Value<String>? name,
    Value<int>? lastConnectedAtMs,
  }) {
    return DevicesCompanion(
      id: id ?? this.id,
      platformId: platformId ?? this.platformId,
      name: name ?? this.name,
      lastConnectedAtMs: lastConnectedAtMs ?? this.lastConnectedAtMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (platformId.present) {
      map['platform_id'] = Variable<String>(platformId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (lastConnectedAtMs.present) {
      map['last_connected_at_ms'] = Variable<int>(lastConnectedAtMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DevicesCompanion(')
          ..write('id: $id, ')
          ..write('platformId: $platformId, ')
          ..write('name: $name, ')
          ..write('lastConnectedAtMs: $lastConnectedAtMs')
          ..write(')'))
        .toString();
  }
}

class $ActivitiesTable extends Activities
    with TableInfo<$ActivitiesTable, Activity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActivitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _athleteIdMeta = const VerificationMeta(
    'athleteId',
  );
  @override
  late final GeneratedColumn<int> athleteId = GeneratedColumn<int>(
    'athlete_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMsMeta = const VerificationMeta(
    'startedAtMs',
  );
  @override
  late final GeneratedColumn<int> startedAtMs = GeneratedColumn<int>(
    'started_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
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
  static const VerificationMeta _sportTypeMeta = const VerificationMeta(
    'sportType',
  );
  @override
  late final GeneratedColumn<String> sportType = GeneratedColumn<String>(
    'sport_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shapeStartMeta = const VerificationMeta(
    'shapeStart',
  );
  @override
  late final GeneratedColumn<int> shapeStart = GeneratedColumn<int>(
    'shape_start',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shapeMidMeta = const VerificationMeta(
    'shapeMid',
  );
  @override
  late final GeneratedColumn<int> shapeMid = GeneratedColumn<int>(
    'shape_mid',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shapeEndMeta = const VerificationMeta(
    'shapeEnd',
  );
  @override
  late final GeneratedColumn<int> shapeEnd = GeneratedColumn<int>(
    'shape_end',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMsMeta = const VerificationMeta(
    'updatedAtMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtMs = GeneratedColumn<int>(
    'updated_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    athleteId,
    startedAtMs,
    durationMs,
    name,
    note,
    sportType,
    shapeStart,
    shapeMid,
    shapeEnd,
    createdAtMs,
    updatedAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'activities';
  @override
  VerificationContext validateIntegrity(
    Insertable<Activity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('athlete_id')) {
      context.handle(
        _athleteIdMeta,
        athleteId.isAcceptableOrUnknown(data['athlete_id']!, _athleteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_athleteIdMeta);
    }
    if (data.containsKey('started_at_ms')) {
      context.handle(
        _startedAtMsMeta,
        startedAtMs.isAcceptableOrUnknown(
          data['started_at_ms']!,
          _startedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startedAtMsMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('sport_type')) {
      context.handle(
        _sportTypeMeta,
        sportType.isAcceptableOrUnknown(data['sport_type']!, _sportTypeMeta),
      );
    }
    if (data.containsKey('shape_start')) {
      context.handle(
        _shapeStartMeta,
        shapeStart.isAcceptableOrUnknown(data['shape_start']!, _shapeStartMeta),
      );
    }
    if (data.containsKey('shape_mid')) {
      context.handle(
        _shapeMidMeta,
        shapeMid.isAcceptableOrUnknown(data['shape_mid']!, _shapeMidMeta),
      );
    }
    if (data.containsKey('shape_end')) {
      context.handle(
        _shapeEndMeta,
        shapeEnd.isAcceptableOrUnknown(data['shape_end']!, _shapeEndMeta),
      );
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    if (data.containsKey('updated_at_ms')) {
      context.handle(
        _updatedAtMsMeta,
        updatedAtMs.isAcceptableOrUnknown(
          data['updated_at_ms']!,
          _updatedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Activity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Activity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      athleteId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}athlete_id'],
      )!,
      startedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at_ms'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      sportType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sport_type'],
      ),
      shapeStart: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}shape_start'],
      ),
      shapeMid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}shape_mid'],
      ),
      shapeEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}shape_end'],
      ),
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
      updatedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_ms'],
      )!,
    );
  }

  @override
  $ActivitiesTable createAlias(String alias) {
    return $ActivitiesTable(attachedDatabase, alias);
  }
}

class Activity extends DataClass implements Insertable<Activity> {
  final int id;
  final int athleteId;
  final int startedAtMs;
  final int durationMs;
  final String? name;
  final String? note;
  final String? sportType;
  final int? shapeStart;
  final int? shapeMid;
  final int? shapeEnd;
  final int createdAtMs;
  final int updatedAtMs;
  const Activity({
    required this.id,
    required this.athleteId,
    required this.startedAtMs,
    required this.durationMs,
    this.name,
    this.note,
    this.sportType,
    this.shapeStart,
    this.shapeMid,
    this.shapeEnd,
    required this.createdAtMs,
    required this.updatedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['athlete_id'] = Variable<int>(athleteId);
    map['started_at_ms'] = Variable<int>(startedAtMs);
    map['duration_ms'] = Variable<int>(durationMs);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || sportType != null) {
      map['sport_type'] = Variable<String>(sportType);
    }
    if (!nullToAbsent || shapeStart != null) {
      map['shape_start'] = Variable<int>(shapeStart);
    }
    if (!nullToAbsent || shapeMid != null) {
      map['shape_mid'] = Variable<int>(shapeMid);
    }
    if (!nullToAbsent || shapeEnd != null) {
      map['shape_end'] = Variable<int>(shapeEnd);
    }
    map['created_at_ms'] = Variable<int>(createdAtMs);
    map['updated_at_ms'] = Variable<int>(updatedAtMs);
    return map;
  }

  ActivitiesCompanion toCompanion(bool nullToAbsent) {
    return ActivitiesCompanion(
      id: Value(id),
      athleteId: Value(athleteId),
      startedAtMs: Value(startedAtMs),
      durationMs: Value(durationMs),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      sportType: sportType == null && nullToAbsent
          ? const Value.absent()
          : Value(sportType),
      shapeStart: shapeStart == null && nullToAbsent
          ? const Value.absent()
          : Value(shapeStart),
      shapeMid: shapeMid == null && nullToAbsent
          ? const Value.absent()
          : Value(shapeMid),
      shapeEnd: shapeEnd == null && nullToAbsent
          ? const Value.absent()
          : Value(shapeEnd),
      createdAtMs: Value(createdAtMs),
      updatedAtMs: Value(updatedAtMs),
    );
  }

  factory Activity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Activity(
      id: serializer.fromJson<int>(json['id']),
      athleteId: serializer.fromJson<int>(json['athleteId']),
      startedAtMs: serializer.fromJson<int>(json['startedAtMs']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      name: serializer.fromJson<String?>(json['name']),
      note: serializer.fromJson<String?>(json['note']),
      sportType: serializer.fromJson<String?>(json['sportType']),
      shapeStart: serializer.fromJson<int?>(json['shapeStart']),
      shapeMid: serializer.fromJson<int?>(json['shapeMid']),
      shapeEnd: serializer.fromJson<int?>(json['shapeEnd']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
      updatedAtMs: serializer.fromJson<int>(json['updatedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'athleteId': serializer.toJson<int>(athleteId),
      'startedAtMs': serializer.toJson<int>(startedAtMs),
      'durationMs': serializer.toJson<int>(durationMs),
      'name': serializer.toJson<String?>(name),
      'note': serializer.toJson<String?>(note),
      'sportType': serializer.toJson<String?>(sportType),
      'shapeStart': serializer.toJson<int?>(shapeStart),
      'shapeMid': serializer.toJson<int?>(shapeMid),
      'shapeEnd': serializer.toJson<int?>(shapeEnd),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
      'updatedAtMs': serializer.toJson<int>(updatedAtMs),
    };
  }

  Activity copyWith({
    int? id,
    int? athleteId,
    int? startedAtMs,
    int? durationMs,
    Value<String?> name = const Value.absent(),
    Value<String?> note = const Value.absent(),
    Value<String?> sportType = const Value.absent(),
    Value<int?> shapeStart = const Value.absent(),
    Value<int?> shapeMid = const Value.absent(),
    Value<int?> shapeEnd = const Value.absent(),
    int? createdAtMs,
    int? updatedAtMs,
  }) => Activity(
    id: id ?? this.id,
    athleteId: athleteId ?? this.athleteId,
    startedAtMs: startedAtMs ?? this.startedAtMs,
    durationMs: durationMs ?? this.durationMs,
    name: name.present ? name.value : this.name,
    note: note.present ? note.value : this.note,
    sportType: sportType.present ? sportType.value : this.sportType,
    shapeStart: shapeStart.present ? shapeStart.value : this.shapeStart,
    shapeMid: shapeMid.present ? shapeMid.value : this.shapeMid,
    shapeEnd: shapeEnd.present ? shapeEnd.value : this.shapeEnd,
    createdAtMs: createdAtMs ?? this.createdAtMs,
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
  );
  Activity copyWithCompanion(ActivitiesCompanion data) {
    return Activity(
      id: data.id.present ? data.id.value : this.id,
      athleteId: data.athleteId.present ? data.athleteId.value : this.athleteId,
      startedAtMs: data.startedAtMs.present
          ? data.startedAtMs.value
          : this.startedAtMs,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      name: data.name.present ? data.name.value : this.name,
      note: data.note.present ? data.note.value : this.note,
      sportType: data.sportType.present ? data.sportType.value : this.sportType,
      shapeStart: data.shapeStart.present
          ? data.shapeStart.value
          : this.shapeStart,
      shapeMid: data.shapeMid.present ? data.shapeMid.value : this.shapeMid,
      shapeEnd: data.shapeEnd.present ? data.shapeEnd.value : this.shapeEnd,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
      updatedAtMs: data.updatedAtMs.present
          ? data.updatedAtMs.value
          : this.updatedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Activity(')
          ..write('id: $id, ')
          ..write('athleteId: $athleteId, ')
          ..write('startedAtMs: $startedAtMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('name: $name, ')
          ..write('note: $note, ')
          ..write('sportType: $sportType, ')
          ..write('shapeStart: $shapeStart, ')
          ..write('shapeMid: $shapeMid, ')
          ..write('shapeEnd: $shapeEnd, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('updatedAtMs: $updatedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    athleteId,
    startedAtMs,
    durationMs,
    name,
    note,
    sportType,
    shapeStart,
    shapeMid,
    shapeEnd,
    createdAtMs,
    updatedAtMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Activity &&
          other.id == this.id &&
          other.athleteId == this.athleteId &&
          other.startedAtMs == this.startedAtMs &&
          other.durationMs == this.durationMs &&
          other.name == this.name &&
          other.note == this.note &&
          other.sportType == this.sportType &&
          other.shapeStart == this.shapeStart &&
          other.shapeMid == this.shapeMid &&
          other.shapeEnd == this.shapeEnd &&
          other.createdAtMs == this.createdAtMs &&
          other.updatedAtMs == this.updatedAtMs);
}

class ActivitiesCompanion extends UpdateCompanion<Activity> {
  final Value<int> id;
  final Value<int> athleteId;
  final Value<int> startedAtMs;
  final Value<int> durationMs;
  final Value<String?> name;
  final Value<String?> note;
  final Value<String?> sportType;
  final Value<int?> shapeStart;
  final Value<int?> shapeMid;
  final Value<int?> shapeEnd;
  final Value<int> createdAtMs;
  final Value<int> updatedAtMs;
  const ActivitiesCompanion({
    this.id = const Value.absent(),
    this.athleteId = const Value.absent(),
    this.startedAtMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.name = const Value.absent(),
    this.note = const Value.absent(),
    this.sportType = const Value.absent(),
    this.shapeStart = const Value.absent(),
    this.shapeMid = const Value.absent(),
    this.shapeEnd = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.updatedAtMs = const Value.absent(),
  });
  ActivitiesCompanion.insert({
    this.id = const Value.absent(),
    required int athleteId,
    required int startedAtMs,
    required int durationMs,
    this.name = const Value.absent(),
    this.note = const Value.absent(),
    this.sportType = const Value.absent(),
    this.shapeStart = const Value.absent(),
    this.shapeMid = const Value.absent(),
    this.shapeEnd = const Value.absent(),
    required int createdAtMs,
    required int updatedAtMs,
  }) : athleteId = Value(athleteId),
       startedAtMs = Value(startedAtMs),
       durationMs = Value(durationMs),
       createdAtMs = Value(createdAtMs),
       updatedAtMs = Value(updatedAtMs);
  static Insertable<Activity> custom({
    Expression<int>? id,
    Expression<int>? athleteId,
    Expression<int>? startedAtMs,
    Expression<int>? durationMs,
    Expression<String>? name,
    Expression<String>? note,
    Expression<String>? sportType,
    Expression<int>? shapeStart,
    Expression<int>? shapeMid,
    Expression<int>? shapeEnd,
    Expression<int>? createdAtMs,
    Expression<int>? updatedAtMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (athleteId != null) 'athlete_id': athleteId,
      if (startedAtMs != null) 'started_at_ms': startedAtMs,
      if (durationMs != null) 'duration_ms': durationMs,
      if (name != null) 'name': name,
      if (note != null) 'note': note,
      if (sportType != null) 'sport_type': sportType,
      if (shapeStart != null) 'shape_start': shapeStart,
      if (shapeMid != null) 'shape_mid': shapeMid,
      if (shapeEnd != null) 'shape_end': shapeEnd,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (updatedAtMs != null) 'updated_at_ms': updatedAtMs,
    });
  }

  ActivitiesCompanion copyWith({
    Value<int>? id,
    Value<int>? athleteId,
    Value<int>? startedAtMs,
    Value<int>? durationMs,
    Value<String?>? name,
    Value<String?>? note,
    Value<String?>? sportType,
    Value<int?>? shapeStart,
    Value<int?>? shapeMid,
    Value<int?>? shapeEnd,
    Value<int>? createdAtMs,
    Value<int>? updatedAtMs,
  }) {
    return ActivitiesCompanion(
      id: id ?? this.id,
      athleteId: athleteId ?? this.athleteId,
      startedAtMs: startedAtMs ?? this.startedAtMs,
      durationMs: durationMs ?? this.durationMs,
      name: name ?? this.name,
      note: note ?? this.note,
      sportType: sportType ?? this.sportType,
      shapeStart: shapeStart ?? this.shapeStart,
      shapeMid: shapeMid ?? this.shapeMid,
      shapeEnd: shapeEnd ?? this.shapeEnd,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (athleteId.present) {
      map['athlete_id'] = Variable<int>(athleteId.value);
    }
    if (startedAtMs.present) {
      map['started_at_ms'] = Variable<int>(startedAtMs.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (sportType.present) {
      map['sport_type'] = Variable<String>(sportType.value);
    }
    if (shapeStart.present) {
      map['shape_start'] = Variable<int>(shapeStart.value);
    }
    if (shapeMid.present) {
      map['shape_mid'] = Variable<int>(shapeMid.value);
    }
    if (shapeEnd.present) {
      map['shape_end'] = Variable<int>(shapeEnd.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (updatedAtMs.present) {
      map['updated_at_ms'] = Variable<int>(updatedAtMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActivitiesCompanion(')
          ..write('id: $id, ')
          ..write('athleteId: $athleteId, ')
          ..write('startedAtMs: $startedAtMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('name: $name, ')
          ..write('note: $note, ')
          ..write('sportType: $sportType, ')
          ..write('shapeStart: $shapeStart, ')
          ..write('shapeMid: $shapeMid, ')
          ..write('shapeEnd: $shapeEnd, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('updatedAtMs: $updatedAtMs')
          ..write(')'))
        .toString();
  }
}

class $SampleSetsTable extends SampleSets
    with TableInfo<$SampleSetsTable, SampleSet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SampleSetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _activityIdMeta = const VerificationMeta(
    'activityId',
  );
  @override
  late final GeneratedColumn<int> activityId = GeneratedColumn<int>(
    'activity_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES activities (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<int> deviceId = GeneratedColumn<int>(
    'device_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES devices (id) ON DELETE SET NULL',
    ),
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
  List<GeneratedColumn> get $columns => [id, activityId, deviceId, kind];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sample_sets';
  @override
  VerificationContext validateIntegrity(
    Insertable<SampleSet> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('activity_id')) {
      context.handle(
        _activityIdMeta,
        activityId.isAcceptableOrUnknown(data['activity_id']!, _activityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_activityIdMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SampleSet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SampleSet(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      activityId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}activity_id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}device_id'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
    );
  }

  @override
  $SampleSetsTable createAlias(String alias) {
    return $SampleSetsTable(attachedDatabase, alias);
  }
}

class SampleSet extends DataClass implements Insertable<SampleSet> {
  final int id;
  final int activityId;
  final int? deviceId;
  final String kind;
  const SampleSet({
    required this.id,
    required this.activityId,
    this.deviceId,
    required this.kind,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['activity_id'] = Variable<int>(activityId);
    if (!nullToAbsent || deviceId != null) {
      map['device_id'] = Variable<int>(deviceId);
    }
    map['kind'] = Variable<String>(kind);
    return map;
  }

  SampleSetsCompanion toCompanion(bool nullToAbsent) {
    return SampleSetsCompanion(
      id: Value(id),
      activityId: Value(activityId),
      deviceId: deviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceId),
      kind: Value(kind),
    );
  }

  factory SampleSet.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SampleSet(
      id: serializer.fromJson<int>(json['id']),
      activityId: serializer.fromJson<int>(json['activityId']),
      deviceId: serializer.fromJson<int?>(json['deviceId']),
      kind: serializer.fromJson<String>(json['kind']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'activityId': serializer.toJson<int>(activityId),
      'deviceId': serializer.toJson<int?>(deviceId),
      'kind': serializer.toJson<String>(kind),
    };
  }

  SampleSet copyWith({
    int? id,
    int? activityId,
    Value<int?> deviceId = const Value.absent(),
    String? kind,
  }) => SampleSet(
    id: id ?? this.id,
    activityId: activityId ?? this.activityId,
    deviceId: deviceId.present ? deviceId.value : this.deviceId,
    kind: kind ?? this.kind,
  );
  SampleSet copyWithCompanion(SampleSetsCompanion data) {
    return SampleSet(
      id: data.id.present ? data.id.value : this.id,
      activityId: data.activityId.present
          ? data.activityId.value
          : this.activityId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      kind: data.kind.present ? data.kind.value : this.kind,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SampleSet(')
          ..write('id: $id, ')
          ..write('activityId: $activityId, ')
          ..write('deviceId: $deviceId, ')
          ..write('kind: $kind')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, activityId, deviceId, kind);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SampleSet &&
          other.id == this.id &&
          other.activityId == this.activityId &&
          other.deviceId == this.deviceId &&
          other.kind == this.kind);
}

class SampleSetsCompanion extends UpdateCompanion<SampleSet> {
  final Value<int> id;
  final Value<int> activityId;
  final Value<int?> deviceId;
  final Value<String> kind;
  const SampleSetsCompanion({
    this.id = const Value.absent(),
    this.activityId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.kind = const Value.absent(),
  });
  SampleSetsCompanion.insert({
    this.id = const Value.absent(),
    required int activityId,
    this.deviceId = const Value.absent(),
    required String kind,
  }) : activityId = Value(activityId),
       kind = Value(kind);
  static Insertable<SampleSet> custom({
    Expression<int>? id,
    Expression<int>? activityId,
    Expression<int>? deviceId,
    Expression<String>? kind,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (activityId != null) 'activity_id': activityId,
      if (deviceId != null) 'device_id': deviceId,
      if (kind != null) 'kind': kind,
    });
  }

  SampleSetsCompanion copyWith({
    Value<int>? id,
    Value<int>? activityId,
    Value<int?>? deviceId,
    Value<String>? kind,
  }) {
    return SampleSetsCompanion(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      deviceId: deviceId ?? this.deviceId,
      kind: kind ?? this.kind,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (activityId.present) {
      map['activity_id'] = Variable<int>(activityId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<int>(deviceId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SampleSetsCompanion(')
          ..write('id: $id, ')
          ..write('activityId: $activityId, ')
          ..write('deviceId: $deviceId, ')
          ..write('kind: $kind')
          ..write(')'))
        .toString();
  }
}

class $HrSamplesTable extends HrSamples
    with TableInfo<$HrSamplesTable, HrSampleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HrSamplesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _setIdMeta = const VerificationMeta('setId');
  @override
  late final GeneratedColumn<int> setId = GeneratedColumn<int>(
    'set_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sample_sets (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _tMsMeta = const VerificationMeta('tMs');
  @override
  late final GeneratedColumn<int> tMs = GeneratedColumn<int>(
    't_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hrMeta = const VerificationMeta('hr');
  @override
  late final GeneratedColumn<int> hr = GeneratedColumn<int>(
    'hr',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [setId, tMs, hr];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'hr_samples';
  @override
  VerificationContext validateIntegrity(
    Insertable<HrSampleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('set_id')) {
      context.handle(
        _setIdMeta,
        setId.isAcceptableOrUnknown(data['set_id']!, _setIdMeta),
      );
    } else if (isInserting) {
      context.missing(_setIdMeta);
    }
    if (data.containsKey('t_ms')) {
      context.handle(
        _tMsMeta,
        tMs.isAcceptableOrUnknown(data['t_ms']!, _tMsMeta),
      );
    } else if (isInserting) {
      context.missing(_tMsMeta);
    }
    if (data.containsKey('hr')) {
      context.handle(_hrMeta, hr.isAcceptableOrUnknown(data['hr']!, _hrMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {setId, tMs};
  @override
  HrSampleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HrSampleRow(
      setId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}set_id'],
      )!,
      tMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}t_ms'],
      )!,
      hr: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hr'],
      ),
    );
  }

  @override
  $HrSamplesTable createAlias(String alias) {
    return $HrSamplesTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class HrSampleRow extends DataClass implements Insertable<HrSampleRow> {
  final int setId;
  final int tMs;
  final int? hr;
  const HrSampleRow({required this.setId, required this.tMs, this.hr});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['set_id'] = Variable<int>(setId);
    map['t_ms'] = Variable<int>(tMs);
    if (!nullToAbsent || hr != null) {
      map['hr'] = Variable<int>(hr);
    }
    return map;
  }

  HrSamplesCompanion toCompanion(bool nullToAbsent) {
    return HrSamplesCompanion(
      setId: Value(setId),
      tMs: Value(tMs),
      hr: hr == null && nullToAbsent ? const Value.absent() : Value(hr),
    );
  }

  factory HrSampleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HrSampleRow(
      setId: serializer.fromJson<int>(json['setId']),
      tMs: serializer.fromJson<int>(json['tMs']),
      hr: serializer.fromJson<int?>(json['hr']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'setId': serializer.toJson<int>(setId),
      'tMs': serializer.toJson<int>(tMs),
      'hr': serializer.toJson<int?>(hr),
    };
  }

  HrSampleRow copyWith({
    int? setId,
    int? tMs,
    Value<int?> hr = const Value.absent(),
  }) => HrSampleRow(
    setId: setId ?? this.setId,
    tMs: tMs ?? this.tMs,
    hr: hr.present ? hr.value : this.hr,
  );
  HrSampleRow copyWithCompanion(HrSamplesCompanion data) {
    return HrSampleRow(
      setId: data.setId.present ? data.setId.value : this.setId,
      tMs: data.tMs.present ? data.tMs.value : this.tMs,
      hr: data.hr.present ? data.hr.value : this.hr,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HrSampleRow(')
          ..write('setId: $setId, ')
          ..write('tMs: $tMs, ')
          ..write('hr: $hr')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(setId, tMs, hr);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HrSampleRow &&
          other.setId == this.setId &&
          other.tMs == this.tMs &&
          other.hr == this.hr);
}

class HrSamplesCompanion extends UpdateCompanion<HrSampleRow> {
  final Value<int> setId;
  final Value<int> tMs;
  final Value<int?> hr;
  const HrSamplesCompanion({
    this.setId = const Value.absent(),
    this.tMs = const Value.absent(),
    this.hr = const Value.absent(),
  });
  HrSamplesCompanion.insert({
    required int setId,
    required int tMs,
    this.hr = const Value.absent(),
  }) : setId = Value(setId),
       tMs = Value(tMs);
  static Insertable<HrSampleRow> custom({
    Expression<int>? setId,
    Expression<int>? tMs,
    Expression<int>? hr,
  }) {
    return RawValuesInsertable({
      if (setId != null) 'set_id': setId,
      if (tMs != null) 't_ms': tMs,
      if (hr != null) 'hr': hr,
    });
  }

  HrSamplesCompanion copyWith({
    Value<int>? setId,
    Value<int>? tMs,
    Value<int?>? hr,
  }) {
    return HrSamplesCompanion(
      setId: setId ?? this.setId,
      tMs: tMs ?? this.tMs,
      hr: hr ?? this.hr,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (setId.present) {
      map['set_id'] = Variable<int>(setId.value);
    }
    if (tMs.present) {
      map['t_ms'] = Variable<int>(tMs.value);
    }
    if (hr.present) {
      map['hr'] = Variable<int>(hr.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HrSamplesCompanion(')
          ..write('setId: $setId, ')
          ..write('tMs: $tMs, ')
          ..write('hr: $hr')
          ..write(')'))
        .toString();
  }
}

class $MarkersTable extends Markers with TableInfo<$MarkersTable, Marker> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MarkersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _activityIdMeta = const VerificationMeta(
    'activityId',
  );
  @override
  late final GeneratedColumn<int> activityId = GeneratedColumn<int>(
    'activity_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES activities (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _tMsMeta = const VerificationMeta('tMs');
  @override
  late final GeneratedColumn<int> tMs = GeneratedColumn<int>(
    't_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    activityId,
    tMs,
    durationMs,
    kind,
    name,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'markers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Marker> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('activity_id')) {
      context.handle(
        _activityIdMeta,
        activityId.isAcceptableOrUnknown(data['activity_id']!, _activityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_activityIdMeta);
    }
    if (data.containsKey('t_ms')) {
      context.handle(
        _tMsMeta,
        tMs.isAcceptableOrUnknown(data['t_ms']!, _tMsMeta),
      );
    } else if (isInserting) {
      context.missing(_tMsMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Marker map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Marker(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      activityId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}activity_id'],
      )!,
      tMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}t_ms'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
    );
  }

  @override
  $MarkersTable createAlias(String alias) {
    return $MarkersTable(attachedDatabase, alias);
  }
}

class Marker extends DataClass implements Insertable<Marker> {
  final int id;
  final int activityId;
  final int tMs;
  final int? durationMs;
  final String kind;
  final String? name;
  const Marker({
    required this.id,
    required this.activityId,
    required this.tMs,
    this.durationMs,
    required this.kind,
    this.name,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['activity_id'] = Variable<int>(activityId);
    map['t_ms'] = Variable<int>(tMs);
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    return map;
  }

  MarkersCompanion toCompanion(bool nullToAbsent) {
    return MarkersCompanion(
      id: Value(id),
      activityId: Value(activityId),
      tMs: Value(tMs),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      kind: Value(kind),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
    );
  }

  factory Marker.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Marker(
      id: serializer.fromJson<int>(json['id']),
      activityId: serializer.fromJson<int>(json['activityId']),
      tMs: serializer.fromJson<int>(json['tMs']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      kind: serializer.fromJson<String>(json['kind']),
      name: serializer.fromJson<String?>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'activityId': serializer.toJson<int>(activityId),
      'tMs': serializer.toJson<int>(tMs),
      'durationMs': serializer.toJson<int?>(durationMs),
      'kind': serializer.toJson<String>(kind),
      'name': serializer.toJson<String?>(name),
    };
  }

  Marker copyWith({
    int? id,
    int? activityId,
    int? tMs,
    Value<int?> durationMs = const Value.absent(),
    String? kind,
    Value<String?> name = const Value.absent(),
  }) => Marker(
    id: id ?? this.id,
    activityId: activityId ?? this.activityId,
    tMs: tMs ?? this.tMs,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    kind: kind ?? this.kind,
    name: name.present ? name.value : this.name,
  );
  Marker copyWithCompanion(MarkersCompanion data) {
    return Marker(
      id: data.id.present ? data.id.value : this.id,
      activityId: data.activityId.present
          ? data.activityId.value
          : this.activityId,
      tMs: data.tMs.present ? data.tMs.value : this.tMs,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      kind: data.kind.present ? data.kind.value : this.kind,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Marker(')
          ..write('id: $id, ')
          ..write('activityId: $activityId, ')
          ..write('tMs: $tMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('kind: $kind, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, activityId, tMs, durationMs, kind, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Marker &&
          other.id == this.id &&
          other.activityId == this.activityId &&
          other.tMs == this.tMs &&
          other.durationMs == this.durationMs &&
          other.kind == this.kind &&
          other.name == this.name);
}

class MarkersCompanion extends UpdateCompanion<Marker> {
  final Value<int> id;
  final Value<int> activityId;
  final Value<int> tMs;
  final Value<int?> durationMs;
  final Value<String> kind;
  final Value<String?> name;
  const MarkersCompanion({
    this.id = const Value.absent(),
    this.activityId = const Value.absent(),
    this.tMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
  });
  MarkersCompanion.insert({
    this.id = const Value.absent(),
    required int activityId,
    required int tMs,
    this.durationMs = const Value.absent(),
    required String kind,
    this.name = const Value.absent(),
  }) : activityId = Value(activityId),
       tMs = Value(tMs),
       kind = Value(kind);
  static Insertable<Marker> custom({
    Expression<int>? id,
    Expression<int>? activityId,
    Expression<int>? tMs,
    Expression<int>? durationMs,
    Expression<String>? kind,
    Expression<String>? name,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (activityId != null) 'activity_id': activityId,
      if (tMs != null) 't_ms': tMs,
      if (durationMs != null) 'duration_ms': durationMs,
      if (kind != null) 'kind': kind,
      if (name != null) 'name': name,
    });
  }

  MarkersCompanion copyWith({
    Value<int>? id,
    Value<int>? activityId,
    Value<int>? tMs,
    Value<int?>? durationMs,
    Value<String>? kind,
    Value<String?>? name,
  }) {
    return MarkersCompanion(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      tMs: tMs ?? this.tMs,
      durationMs: durationMs ?? this.durationMs,
      kind: kind ?? this.kind,
      name: name ?? this.name,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (activityId.present) {
      map['activity_id'] = Variable<int>(activityId.value);
    }
    if (tMs.present) {
      map['t_ms'] = Variable<int>(tMs.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MarkersCompanion(')
          ..write('id: $id, ')
          ..write('activityId: $activityId, ')
          ..write('tMs: $tMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('kind: $kind, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AthletesTable athletes = $AthletesTable(this);
  late final $DevicesTable devices = $DevicesTable(this);
  late final $ActivitiesTable activities = $ActivitiesTable(this);
  late final $SampleSetsTable sampleSets = $SampleSetsTable(this);
  late final $HrSamplesTable hrSamples = $HrSamplesTable(this);
  late final $MarkersTable markers = $MarkersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    athletes,
    devices,
    activities,
    sampleSets,
    hrSamples,
    markers,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'activities',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('sample_sets', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'devices',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('sample_sets', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sample_sets',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('hr_samples', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'activities',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('markers', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$AthletesTableCreateCompanionBuilder =
    AthletesCompanion Function({
      Value<int> id,
      required String name,
      Value<int?> restingHeartrate,
      Value<int?> maxHeartrate,
      required int createdAtMs,
    });
typedef $$AthletesTableUpdateCompanionBuilder =
    AthletesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int?> restingHeartrate,
      Value<int?> maxHeartrate,
      Value<int> createdAtMs,
    });

class $$AthletesTableFilterComposer
    extends Composer<_$AppDatabase, $AthletesTable> {
  $$AthletesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get restingHeartrate => $composableBuilder(
    column: $table.restingHeartrate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxHeartrate => $composableBuilder(
    column: $table.maxHeartrate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AthletesTableOrderingComposer
    extends Composer<_$AppDatabase, $AthletesTable> {
  $$AthletesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get restingHeartrate => $composableBuilder(
    column: $table.restingHeartrate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxHeartrate => $composableBuilder(
    column: $table.maxHeartrate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AthletesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AthletesTable> {
  $$AthletesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get restingHeartrate => $composableBuilder(
    column: $table.restingHeartrate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxHeartrate => $composableBuilder(
    column: $table.maxHeartrate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );
}

class $$AthletesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AthletesTable,
          Athlete,
          $$AthletesTableFilterComposer,
          $$AthletesTableOrderingComposer,
          $$AthletesTableAnnotationComposer,
          $$AthletesTableCreateCompanionBuilder,
          $$AthletesTableUpdateCompanionBuilder,
          (Athlete, BaseReferences<_$AppDatabase, $AthletesTable, Athlete>),
          Athlete,
          PrefetchHooks Function()
        > {
  $$AthletesTableTableManager(_$AppDatabase db, $AthletesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AthletesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AthletesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AthletesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int?> restingHeartrate = const Value.absent(),
                Value<int?> maxHeartrate = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
              }) => AthletesCompanion(
                id: id,
                name: name,
                restingHeartrate: restingHeartrate,
                maxHeartrate: maxHeartrate,
                createdAtMs: createdAtMs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<int?> restingHeartrate = const Value.absent(),
                Value<int?> maxHeartrate = const Value.absent(),
                required int createdAtMs,
              }) => AthletesCompanion.insert(
                id: id,
                name: name,
                restingHeartrate: restingHeartrate,
                maxHeartrate: maxHeartrate,
                createdAtMs: createdAtMs,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AthletesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AthletesTable,
      Athlete,
      $$AthletesTableFilterComposer,
      $$AthletesTableOrderingComposer,
      $$AthletesTableAnnotationComposer,
      $$AthletesTableCreateCompanionBuilder,
      $$AthletesTableUpdateCompanionBuilder,
      (Athlete, BaseReferences<_$AppDatabase, $AthletesTable, Athlete>),
      Athlete,
      PrefetchHooks Function()
    >;
typedef $$DevicesTableCreateCompanionBuilder =
    DevicesCompanion Function({
      Value<int> id,
      required String platformId,
      required String name,
      required int lastConnectedAtMs,
    });
typedef $$DevicesTableUpdateCompanionBuilder =
    DevicesCompanion Function({
      Value<int> id,
      Value<String> platformId,
      Value<String> name,
      Value<int> lastConnectedAtMs,
    });

final class $$DevicesTableReferences
    extends BaseReferences<_$AppDatabase, $DevicesTable, Device> {
  $$DevicesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SampleSetsTable, List<SampleSet>>
  _sampleSetsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.sampleSets,
    aliasName: $_aliasNameGenerator(db.devices.id, db.sampleSets.deviceId),
  );

  $$SampleSetsTableProcessedTableManager get sampleSetsRefs {
    final manager = $$SampleSetsTableTableManager(
      $_db,
      $_db.sampleSets,
    ).filter((f) => f.deviceId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_sampleSetsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DevicesTableFilterComposer
    extends Composer<_$AppDatabase, $DevicesTable> {
  $$DevicesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get platformId => $composableBuilder(
    column: $table.platformId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastConnectedAtMs => $composableBuilder(
    column: $table.lastConnectedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> sampleSetsRefs(
    Expression<bool> Function($$SampleSetsTableFilterComposer f) f,
  ) {
    final $$SampleSetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sampleSets,
      getReferencedColumn: (t) => t.deviceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SampleSetsTableFilterComposer(
            $db: $db,
            $table: $db.sampleSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DevicesTableOrderingComposer
    extends Composer<_$AppDatabase, $DevicesTable> {
  $$DevicesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get platformId => $composableBuilder(
    column: $table.platformId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastConnectedAtMs => $composableBuilder(
    column: $table.lastConnectedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DevicesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DevicesTable> {
  $$DevicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get platformId => $composableBuilder(
    column: $table.platformId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get lastConnectedAtMs => $composableBuilder(
    column: $table.lastConnectedAtMs,
    builder: (column) => column,
  );

  Expression<T> sampleSetsRefs<T extends Object>(
    Expression<T> Function($$SampleSetsTableAnnotationComposer a) f,
  ) {
    final $$SampleSetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sampleSets,
      getReferencedColumn: (t) => t.deviceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SampleSetsTableAnnotationComposer(
            $db: $db,
            $table: $db.sampleSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DevicesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DevicesTable,
          Device,
          $$DevicesTableFilterComposer,
          $$DevicesTableOrderingComposer,
          $$DevicesTableAnnotationComposer,
          $$DevicesTableCreateCompanionBuilder,
          $$DevicesTableUpdateCompanionBuilder,
          (Device, $$DevicesTableReferences),
          Device,
          PrefetchHooks Function({bool sampleSetsRefs})
        > {
  $$DevicesTableTableManager(_$AppDatabase db, $DevicesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DevicesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DevicesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DevicesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> platformId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> lastConnectedAtMs = const Value.absent(),
              }) => DevicesCompanion(
                id: id,
                platformId: platformId,
                name: name,
                lastConnectedAtMs: lastConnectedAtMs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String platformId,
                required String name,
                required int lastConnectedAtMs,
              }) => DevicesCompanion.insert(
                id: id,
                platformId: platformId,
                name: name,
                lastConnectedAtMs: lastConnectedAtMs,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DevicesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sampleSetsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (sampleSetsRefs) db.sampleSets],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (sampleSetsRefs)
                    await $_getPrefetchedData<Device, $DevicesTable, SampleSet>(
                      currentTable: table,
                      referencedTable: $$DevicesTableReferences
                          ._sampleSetsRefsTable(db),
                      managerFromTypedResult: (p0) => $$DevicesTableReferences(
                        db,
                        table,
                        p0,
                      ).sampleSetsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.deviceId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$DevicesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DevicesTable,
      Device,
      $$DevicesTableFilterComposer,
      $$DevicesTableOrderingComposer,
      $$DevicesTableAnnotationComposer,
      $$DevicesTableCreateCompanionBuilder,
      $$DevicesTableUpdateCompanionBuilder,
      (Device, $$DevicesTableReferences),
      Device,
      PrefetchHooks Function({bool sampleSetsRefs})
    >;
typedef $$ActivitiesTableCreateCompanionBuilder =
    ActivitiesCompanion Function({
      Value<int> id,
      required int athleteId,
      required int startedAtMs,
      required int durationMs,
      Value<String?> name,
      Value<String?> note,
      Value<String?> sportType,
      Value<int?> shapeStart,
      Value<int?> shapeMid,
      Value<int?> shapeEnd,
      required int createdAtMs,
      required int updatedAtMs,
    });
typedef $$ActivitiesTableUpdateCompanionBuilder =
    ActivitiesCompanion Function({
      Value<int> id,
      Value<int> athleteId,
      Value<int> startedAtMs,
      Value<int> durationMs,
      Value<String?> name,
      Value<String?> note,
      Value<String?> sportType,
      Value<int?> shapeStart,
      Value<int?> shapeMid,
      Value<int?> shapeEnd,
      Value<int> createdAtMs,
      Value<int> updatedAtMs,
    });

final class $$ActivitiesTableReferences
    extends BaseReferences<_$AppDatabase, $ActivitiesTable, Activity> {
  $$ActivitiesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SampleSetsTable, List<SampleSet>>
  _sampleSetsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.sampleSets,
    aliasName: $_aliasNameGenerator(db.activities.id, db.sampleSets.activityId),
  );

  $$SampleSetsTableProcessedTableManager get sampleSetsRefs {
    final manager = $$SampleSetsTableTableManager(
      $_db,
      $_db.sampleSets,
    ).filter((f) => f.activityId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_sampleSetsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MarkersTable, List<Marker>> _markersRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.markers,
    aliasName: $_aliasNameGenerator(db.activities.id, db.markers.activityId),
  );

  $$MarkersTableProcessedTableManager get markersRefs {
    final manager = $$MarkersTableTableManager(
      $_db,
      $_db.markers,
    ).filter((f) => f.activityId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_markersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ActivitiesTableFilterComposer
    extends Composer<_$AppDatabase, $ActivitiesTable> {
  $$ActivitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get athleteId => $composableBuilder(
    column: $table.athleteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAtMs => $composableBuilder(
    column: $table.startedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sportType => $composableBuilder(
    column: $table.sportType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get shapeStart => $composableBuilder(
    column: $table.shapeStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get shapeMid => $composableBuilder(
    column: $table.shapeMid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get shapeEnd => $composableBuilder(
    column: $table.shapeEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> sampleSetsRefs(
    Expression<bool> Function($$SampleSetsTableFilterComposer f) f,
  ) {
    final $$SampleSetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sampleSets,
      getReferencedColumn: (t) => t.activityId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SampleSetsTableFilterComposer(
            $db: $db,
            $table: $db.sampleSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> markersRefs(
    Expression<bool> Function($$MarkersTableFilterComposer f) f,
  ) {
    final $$MarkersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.markers,
      getReferencedColumn: (t) => t.activityId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MarkersTableFilterComposer(
            $db: $db,
            $table: $db.markers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ActivitiesTableOrderingComposer
    extends Composer<_$AppDatabase, $ActivitiesTable> {
  $$ActivitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get athleteId => $composableBuilder(
    column: $table.athleteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAtMs => $composableBuilder(
    column: $table.startedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sportType => $composableBuilder(
    column: $table.sportType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get shapeStart => $composableBuilder(
    column: $table.shapeStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get shapeMid => $composableBuilder(
    column: $table.shapeMid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get shapeEnd => $composableBuilder(
    column: $table.shapeEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ActivitiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ActivitiesTable> {
  $$ActivitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get athleteId =>
      $composableBuilder(column: $table.athleteId, builder: (column) => column);

  GeneratedColumn<int> get startedAtMs => $composableBuilder(
    column: $table.startedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get sportType =>
      $composableBuilder(column: $table.sportType, builder: (column) => column);

  GeneratedColumn<int> get shapeStart => $composableBuilder(
    column: $table.shapeStart,
    builder: (column) => column,
  );

  GeneratedColumn<int> get shapeMid =>
      $composableBuilder(column: $table.shapeMid, builder: (column) => column);

  GeneratedColumn<int> get shapeEnd =>
      $composableBuilder(column: $table.shapeEnd, builder: (column) => column);

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => column,
  );

  Expression<T> sampleSetsRefs<T extends Object>(
    Expression<T> Function($$SampleSetsTableAnnotationComposer a) f,
  ) {
    final $$SampleSetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sampleSets,
      getReferencedColumn: (t) => t.activityId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SampleSetsTableAnnotationComposer(
            $db: $db,
            $table: $db.sampleSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> markersRefs<T extends Object>(
    Expression<T> Function($$MarkersTableAnnotationComposer a) f,
  ) {
    final $$MarkersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.markers,
      getReferencedColumn: (t) => t.activityId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MarkersTableAnnotationComposer(
            $db: $db,
            $table: $db.markers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ActivitiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ActivitiesTable,
          Activity,
          $$ActivitiesTableFilterComposer,
          $$ActivitiesTableOrderingComposer,
          $$ActivitiesTableAnnotationComposer,
          $$ActivitiesTableCreateCompanionBuilder,
          $$ActivitiesTableUpdateCompanionBuilder,
          (Activity, $$ActivitiesTableReferences),
          Activity,
          PrefetchHooks Function({bool sampleSetsRefs, bool markersRefs})
        > {
  $$ActivitiesTableTableManager(_$AppDatabase db, $ActivitiesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActivitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActivitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActivitiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> athleteId = const Value.absent(),
                Value<int> startedAtMs = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> sportType = const Value.absent(),
                Value<int?> shapeStart = const Value.absent(),
                Value<int?> shapeMid = const Value.absent(),
                Value<int?> shapeEnd = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<int> updatedAtMs = const Value.absent(),
              }) => ActivitiesCompanion(
                id: id,
                athleteId: athleteId,
                startedAtMs: startedAtMs,
                durationMs: durationMs,
                name: name,
                note: note,
                sportType: sportType,
                shapeStart: shapeStart,
                shapeMid: shapeMid,
                shapeEnd: shapeEnd,
                createdAtMs: createdAtMs,
                updatedAtMs: updatedAtMs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int athleteId,
                required int startedAtMs,
                required int durationMs,
                Value<String?> name = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> sportType = const Value.absent(),
                Value<int?> shapeStart = const Value.absent(),
                Value<int?> shapeMid = const Value.absent(),
                Value<int?> shapeEnd = const Value.absent(),
                required int createdAtMs,
                required int updatedAtMs,
              }) => ActivitiesCompanion.insert(
                id: id,
                athleteId: athleteId,
                startedAtMs: startedAtMs,
                durationMs: durationMs,
                name: name,
                note: note,
                sportType: sportType,
                shapeStart: shapeStart,
                shapeMid: shapeMid,
                shapeEnd: shapeEnd,
                createdAtMs: createdAtMs,
                updatedAtMs: updatedAtMs,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ActivitiesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({sampleSetsRefs = false, markersRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (sampleSetsRefs) db.sampleSets,
                    if (markersRefs) db.markers,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (sampleSetsRefs)
                        await $_getPrefetchedData<
                          Activity,
                          $ActivitiesTable,
                          SampleSet
                        >(
                          currentTable: table,
                          referencedTable: $$ActivitiesTableReferences
                              ._sampleSetsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ActivitiesTableReferences(
                                db,
                                table,
                                p0,
                              ).sampleSetsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.activityId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (markersRefs)
                        await $_getPrefetchedData<
                          Activity,
                          $ActivitiesTable,
                          Marker
                        >(
                          currentTable: table,
                          referencedTable: $$ActivitiesTableReferences
                              ._markersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ActivitiesTableReferences(
                                db,
                                table,
                                p0,
                              ).markersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.activityId == item.id,
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

typedef $$ActivitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ActivitiesTable,
      Activity,
      $$ActivitiesTableFilterComposer,
      $$ActivitiesTableOrderingComposer,
      $$ActivitiesTableAnnotationComposer,
      $$ActivitiesTableCreateCompanionBuilder,
      $$ActivitiesTableUpdateCompanionBuilder,
      (Activity, $$ActivitiesTableReferences),
      Activity,
      PrefetchHooks Function({bool sampleSetsRefs, bool markersRefs})
    >;
typedef $$SampleSetsTableCreateCompanionBuilder =
    SampleSetsCompanion Function({
      Value<int> id,
      required int activityId,
      Value<int?> deviceId,
      required String kind,
    });
typedef $$SampleSetsTableUpdateCompanionBuilder =
    SampleSetsCompanion Function({
      Value<int> id,
      Value<int> activityId,
      Value<int?> deviceId,
      Value<String> kind,
    });

final class $$SampleSetsTableReferences
    extends BaseReferences<_$AppDatabase, $SampleSetsTable, SampleSet> {
  $$SampleSetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ActivitiesTable _activityIdTable(_$AppDatabase db) =>
      db.activities.createAlias(
        $_aliasNameGenerator(db.sampleSets.activityId, db.activities.id),
      );

  $$ActivitiesTableProcessedTableManager get activityId {
    final $_column = $_itemColumn<int>('activity_id')!;

    final manager = $$ActivitiesTableTableManager(
      $_db,
      $_db.activities,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_activityIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $DevicesTable _deviceIdTable(_$AppDatabase db) => db.devices
      .createAlias($_aliasNameGenerator(db.sampleSets.deviceId, db.devices.id));

  $$DevicesTableProcessedTableManager? get deviceId {
    final $_column = $_itemColumn<int>('device_id');
    if ($_column == null) return null;
    final manager = $$DevicesTableTableManager(
      $_db,
      $_db.devices,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_deviceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$HrSamplesTable, List<HrSampleRow>>
  _hrSamplesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.hrSamples,
    aliasName: $_aliasNameGenerator(db.sampleSets.id, db.hrSamples.setId),
  );

  $$HrSamplesTableProcessedTableManager get hrSamplesRefs {
    final manager = $$HrSamplesTableTableManager(
      $_db,
      $_db.hrSamples,
    ).filter((f) => f.setId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_hrSamplesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SampleSetsTableFilterComposer
    extends Composer<_$AppDatabase, $SampleSetsTable> {
  $$SampleSetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  $$ActivitiesTableFilterComposer get activityId {
    final $$ActivitiesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.activityId,
      referencedTable: $db.activities,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivitiesTableFilterComposer(
            $db: $db,
            $table: $db.activities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DevicesTableFilterComposer get deviceId {
    final $$DevicesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableFilterComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> hrSamplesRefs(
    Expression<bool> Function($$HrSamplesTableFilterComposer f) f,
  ) {
    final $$HrSamplesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.hrSamples,
      getReferencedColumn: (t) => t.setId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HrSamplesTableFilterComposer(
            $db: $db,
            $table: $db.hrSamples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SampleSetsTableOrderingComposer
    extends Composer<_$AppDatabase, $SampleSetsTable> {
  $$SampleSetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  $$ActivitiesTableOrderingComposer get activityId {
    final $$ActivitiesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.activityId,
      referencedTable: $db.activities,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivitiesTableOrderingComposer(
            $db: $db,
            $table: $db.activities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DevicesTableOrderingComposer get deviceId {
    final $$DevicesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableOrderingComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SampleSetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SampleSetsTable> {
  $$SampleSetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  $$ActivitiesTableAnnotationComposer get activityId {
    final $$ActivitiesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.activityId,
      referencedTable: $db.activities,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivitiesTableAnnotationComposer(
            $db: $db,
            $table: $db.activities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DevicesTableAnnotationComposer get deviceId {
    final $$DevicesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableAnnotationComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> hrSamplesRefs<T extends Object>(
    Expression<T> Function($$HrSamplesTableAnnotationComposer a) f,
  ) {
    final $$HrSamplesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.hrSamples,
      getReferencedColumn: (t) => t.setId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HrSamplesTableAnnotationComposer(
            $db: $db,
            $table: $db.hrSamples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SampleSetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SampleSetsTable,
          SampleSet,
          $$SampleSetsTableFilterComposer,
          $$SampleSetsTableOrderingComposer,
          $$SampleSetsTableAnnotationComposer,
          $$SampleSetsTableCreateCompanionBuilder,
          $$SampleSetsTableUpdateCompanionBuilder,
          (SampleSet, $$SampleSetsTableReferences),
          SampleSet,
          PrefetchHooks Function({
            bool activityId,
            bool deviceId,
            bool hrSamplesRefs,
          })
        > {
  $$SampleSetsTableTableManager(_$AppDatabase db, $SampleSetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SampleSetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SampleSetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SampleSetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> activityId = const Value.absent(),
                Value<int?> deviceId = const Value.absent(),
                Value<String> kind = const Value.absent(),
              }) => SampleSetsCompanion(
                id: id,
                activityId: activityId,
                deviceId: deviceId,
                kind: kind,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int activityId,
                Value<int?> deviceId = const Value.absent(),
                required String kind,
              }) => SampleSetsCompanion.insert(
                id: id,
                activityId: activityId,
                deviceId: deviceId,
                kind: kind,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SampleSetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({activityId = false, deviceId = false, hrSamplesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [if (hrSamplesRefs) db.hrSamples],
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
                        if (activityId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.activityId,
                                    referencedTable: $$SampleSetsTableReferences
                                        ._activityIdTable(db),
                                    referencedColumn:
                                        $$SampleSetsTableReferences
                                            ._activityIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (deviceId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.deviceId,
                                    referencedTable: $$SampleSetsTableReferences
                                        ._deviceIdTable(db),
                                    referencedColumn:
                                        $$SampleSetsTableReferences
                                            ._deviceIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (hrSamplesRefs)
                        await $_getPrefetchedData<
                          SampleSet,
                          $SampleSetsTable,
                          HrSampleRow
                        >(
                          currentTable: table,
                          referencedTable: $$SampleSetsTableReferences
                              ._hrSamplesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SampleSetsTableReferences(
                                db,
                                table,
                                p0,
                              ).hrSamplesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.setId == item.id,
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

typedef $$SampleSetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SampleSetsTable,
      SampleSet,
      $$SampleSetsTableFilterComposer,
      $$SampleSetsTableOrderingComposer,
      $$SampleSetsTableAnnotationComposer,
      $$SampleSetsTableCreateCompanionBuilder,
      $$SampleSetsTableUpdateCompanionBuilder,
      (SampleSet, $$SampleSetsTableReferences),
      SampleSet,
      PrefetchHooks Function({
        bool activityId,
        bool deviceId,
        bool hrSamplesRefs,
      })
    >;
typedef $$HrSamplesTableCreateCompanionBuilder =
    HrSamplesCompanion Function({
      required int setId,
      required int tMs,
      Value<int?> hr,
    });
typedef $$HrSamplesTableUpdateCompanionBuilder =
    HrSamplesCompanion Function({
      Value<int> setId,
      Value<int> tMs,
      Value<int?> hr,
    });

final class $$HrSamplesTableReferences
    extends BaseReferences<_$AppDatabase, $HrSamplesTable, HrSampleRow> {
  $$HrSamplesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SampleSetsTable _setIdTable(_$AppDatabase db) => db.sampleSets
      .createAlias($_aliasNameGenerator(db.hrSamples.setId, db.sampleSets.id));

  $$SampleSetsTableProcessedTableManager get setId {
    final $_column = $_itemColumn<int>('set_id')!;

    final manager = $$SampleSetsTableTableManager(
      $_db,
      $_db.sampleSets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_setIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$HrSamplesTableFilterComposer
    extends Composer<_$AppDatabase, $HrSamplesTable> {
  $$HrSamplesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get tMs => $composableBuilder(
    column: $table.tMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hr => $composableBuilder(
    column: $table.hr,
    builder: (column) => ColumnFilters(column),
  );

  $$SampleSetsTableFilterComposer get setId {
    final $$SampleSetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.sampleSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SampleSetsTableFilterComposer(
            $db: $db,
            $table: $db.sampleSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HrSamplesTableOrderingComposer
    extends Composer<_$AppDatabase, $HrSamplesTable> {
  $$HrSamplesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get tMs => $composableBuilder(
    column: $table.tMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hr => $composableBuilder(
    column: $table.hr,
    builder: (column) => ColumnOrderings(column),
  );

  $$SampleSetsTableOrderingComposer get setId {
    final $$SampleSetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.sampleSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SampleSetsTableOrderingComposer(
            $db: $db,
            $table: $db.sampleSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HrSamplesTableAnnotationComposer
    extends Composer<_$AppDatabase, $HrSamplesTable> {
  $$HrSamplesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get tMs =>
      $composableBuilder(column: $table.tMs, builder: (column) => column);

  GeneratedColumn<int> get hr =>
      $composableBuilder(column: $table.hr, builder: (column) => column);

  $$SampleSetsTableAnnotationComposer get setId {
    final $$SampleSetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.sampleSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SampleSetsTableAnnotationComposer(
            $db: $db,
            $table: $db.sampleSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HrSamplesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HrSamplesTable,
          HrSampleRow,
          $$HrSamplesTableFilterComposer,
          $$HrSamplesTableOrderingComposer,
          $$HrSamplesTableAnnotationComposer,
          $$HrSamplesTableCreateCompanionBuilder,
          $$HrSamplesTableUpdateCompanionBuilder,
          (HrSampleRow, $$HrSamplesTableReferences),
          HrSampleRow,
          PrefetchHooks Function({bool setId})
        > {
  $$HrSamplesTableTableManager(_$AppDatabase db, $HrSamplesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HrSamplesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HrSamplesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HrSamplesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> setId = const Value.absent(),
                Value<int> tMs = const Value.absent(),
                Value<int?> hr = const Value.absent(),
              }) => HrSamplesCompanion(setId: setId, tMs: tMs, hr: hr),
          createCompanionCallback:
              ({
                required int setId,
                required int tMs,
                Value<int?> hr = const Value.absent(),
              }) => HrSamplesCompanion.insert(setId: setId, tMs: tMs, hr: hr),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$HrSamplesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({setId = false}) {
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
                    if (setId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.setId,
                                referencedTable: $$HrSamplesTableReferences
                                    ._setIdTable(db),
                                referencedColumn: $$HrSamplesTableReferences
                                    ._setIdTable(db)
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

typedef $$HrSamplesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HrSamplesTable,
      HrSampleRow,
      $$HrSamplesTableFilterComposer,
      $$HrSamplesTableOrderingComposer,
      $$HrSamplesTableAnnotationComposer,
      $$HrSamplesTableCreateCompanionBuilder,
      $$HrSamplesTableUpdateCompanionBuilder,
      (HrSampleRow, $$HrSamplesTableReferences),
      HrSampleRow,
      PrefetchHooks Function({bool setId})
    >;
typedef $$MarkersTableCreateCompanionBuilder =
    MarkersCompanion Function({
      Value<int> id,
      required int activityId,
      required int tMs,
      Value<int?> durationMs,
      required String kind,
      Value<String?> name,
    });
typedef $$MarkersTableUpdateCompanionBuilder =
    MarkersCompanion Function({
      Value<int> id,
      Value<int> activityId,
      Value<int> tMs,
      Value<int?> durationMs,
      Value<String> kind,
      Value<String?> name,
    });

final class $$MarkersTableReferences
    extends BaseReferences<_$AppDatabase, $MarkersTable, Marker> {
  $$MarkersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ActivitiesTable _activityIdTable(_$AppDatabase db) =>
      db.activities.createAlias(
        $_aliasNameGenerator(db.markers.activityId, db.activities.id),
      );

  $$ActivitiesTableProcessedTableManager get activityId {
    final $_column = $_itemColumn<int>('activity_id')!;

    final manager = $$ActivitiesTableTableManager(
      $_db,
      $_db.activities,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_activityIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MarkersTableFilterComposer
    extends Composer<_$AppDatabase, $MarkersTable> {
  $$MarkersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tMs => $composableBuilder(
    column: $table.tMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  $$ActivitiesTableFilterComposer get activityId {
    final $$ActivitiesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.activityId,
      referencedTable: $db.activities,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivitiesTableFilterComposer(
            $db: $db,
            $table: $db.activities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MarkersTableOrderingComposer
    extends Composer<_$AppDatabase, $MarkersTable> {
  $$MarkersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tMs => $composableBuilder(
    column: $table.tMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  $$ActivitiesTableOrderingComposer get activityId {
    final $$ActivitiesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.activityId,
      referencedTable: $db.activities,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivitiesTableOrderingComposer(
            $db: $db,
            $table: $db.activities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MarkersTableAnnotationComposer
    extends Composer<_$AppDatabase, $MarkersTable> {
  $$MarkersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get tMs =>
      $composableBuilder(column: $table.tMs, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  $$ActivitiesTableAnnotationComposer get activityId {
    final $$ActivitiesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.activityId,
      referencedTable: $db.activities,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivitiesTableAnnotationComposer(
            $db: $db,
            $table: $db.activities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MarkersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MarkersTable,
          Marker,
          $$MarkersTableFilterComposer,
          $$MarkersTableOrderingComposer,
          $$MarkersTableAnnotationComposer,
          $$MarkersTableCreateCompanionBuilder,
          $$MarkersTableUpdateCompanionBuilder,
          (Marker, $$MarkersTableReferences),
          Marker,
          PrefetchHooks Function({bool activityId})
        > {
  $$MarkersTableTableManager(_$AppDatabase db, $MarkersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MarkersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MarkersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MarkersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> activityId = const Value.absent(),
                Value<int> tMs = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> name = const Value.absent(),
              }) => MarkersCompanion(
                id: id,
                activityId: activityId,
                tMs: tMs,
                durationMs: durationMs,
                kind: kind,
                name: name,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int activityId,
                required int tMs,
                Value<int?> durationMs = const Value.absent(),
                required String kind,
                Value<String?> name = const Value.absent(),
              }) => MarkersCompanion.insert(
                id: id,
                activityId: activityId,
                tMs: tMs,
                durationMs: durationMs,
                kind: kind,
                name: name,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MarkersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({activityId = false}) {
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
                    if (activityId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.activityId,
                                referencedTable: $$MarkersTableReferences
                                    ._activityIdTable(db),
                                referencedColumn: $$MarkersTableReferences
                                    ._activityIdTable(db)
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

typedef $$MarkersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MarkersTable,
      Marker,
      $$MarkersTableFilterComposer,
      $$MarkersTableOrderingComposer,
      $$MarkersTableAnnotationComposer,
      $$MarkersTableCreateCompanionBuilder,
      $$MarkersTableUpdateCompanionBuilder,
      (Marker, $$MarkersTableReferences),
      Marker,
      PrefetchHooks Function({bool activityId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AthletesTableTableManager get athletes =>
      $$AthletesTableTableManager(_db, _db.athletes);
  $$DevicesTableTableManager get devices =>
      $$DevicesTableTableManager(_db, _db.devices);
  $$ActivitiesTableTableManager get activities =>
      $$ActivitiesTableTableManager(_db, _db.activities);
  $$SampleSetsTableTableManager get sampleSets =>
      $$SampleSetsTableTableManager(_db, _db.sampleSets);
  $$HrSamplesTableTableManager get hrSamples =>
      $$HrSamplesTableTableManager(_db, _db.hrSamples);
  $$MarkersTableTableManager get markers =>
      $$MarkersTableTableManager(_db, _db.markers);
}
