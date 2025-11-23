// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AddonsTable extends Addons with TableInfo<$AddonsTable, Addon> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AddonsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
      'version', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _manifestUrlMeta =
      const VerificationMeta('manifestUrl');
  @override
  late final GeneratedColumn<String> manifestUrl = GeneratedColumn<String>(
      'manifest_url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _baseUrlMeta =
      const VerificationMeta('baseUrl');
  @override
  late final GeneratedColumn<String> baseUrl = GeneratedColumn<String>(
      'base_url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _enabledMeta =
      const VerificationMeta('enabled');
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
      'enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("enabled" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _manifestDataMeta =
      const VerificationMeta('manifestData');
  @override
  late final GeneratedColumn<String> manifestData = GeneratedColumn<String>(
      'manifest_data', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _resourcesMeta =
      const VerificationMeta('resources');
  @override
  late final GeneratedColumn<String> resources = GeneratedColumn<String>(
      'resources', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typesMeta = const VerificationMeta('types');
  @override
  late final GeneratedColumn<String> types = GeneratedColumn<String>(
      'types', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        version,
        description,
        manifestUrl,
        baseUrl,
        enabled,
        manifestData,
        resources,
        types,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'addons';
  @override
  VerificationContext validateIntegrity(Insertable<Addon> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('manifest_url')) {
      context.handle(
          _manifestUrlMeta,
          manifestUrl.isAcceptableOrUnknown(
              data['manifest_url']!, _manifestUrlMeta));
    } else if (isInserting) {
      context.missing(_manifestUrlMeta);
    }
    if (data.containsKey('base_url')) {
      context.handle(_baseUrlMeta,
          baseUrl.isAcceptableOrUnknown(data['base_url']!, _baseUrlMeta));
    } else if (isInserting) {
      context.missing(_baseUrlMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(_enabledMeta,
          enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta));
    }
    if (data.containsKey('manifest_data')) {
      context.handle(
          _manifestDataMeta,
          manifestData.isAcceptableOrUnknown(
              data['manifest_data']!, _manifestDataMeta));
    } else if (isInserting) {
      context.missing(_manifestDataMeta);
    }
    if (data.containsKey('resources')) {
      context.handle(_resourcesMeta,
          resources.isAcceptableOrUnknown(data['resources']!, _resourcesMeta));
    } else if (isInserting) {
      context.missing(_resourcesMeta);
    }
    if (data.containsKey('types')) {
      context.handle(
          _typesMeta, types.isAcceptableOrUnknown(data['types']!, _typesMeta));
    } else if (isInserting) {
      context.missing(_typesMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Addon map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Addon(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}version'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      manifestUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}manifest_url'])!,
      baseUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}base_url'])!,
      enabled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}enabled'])!,
      manifestData: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}manifest_data'])!,
      resources: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}resources'])!,
      types: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}types'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $AddonsTable createAlias(String alias) {
    return $AddonsTable(attachedDatabase, alias);
  }
}

class Addon extends DataClass implements Insertable<Addon> {
  final String id;
  final String name;
  final String version;
  final String? description;
  final String manifestUrl;
  final String baseUrl;
  final bool enabled;
  final String manifestData;
  final String resources;
  final String types;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Addon(
      {required this.id,
      required this.name,
      required this.version,
      this.description,
      required this.manifestUrl,
      required this.baseUrl,
      required this.enabled,
      required this.manifestData,
      required this.resources,
      required this.types,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['version'] = Variable<String>(version);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['manifest_url'] = Variable<String>(manifestUrl);
    map['base_url'] = Variable<String>(baseUrl);
    map['enabled'] = Variable<bool>(enabled);
    map['manifest_data'] = Variable<String>(manifestData);
    map['resources'] = Variable<String>(resources);
    map['types'] = Variable<String>(types);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AddonsCompanion toCompanion(bool nullToAbsent) {
    return AddonsCompanion(
      id: Value(id),
      name: Value(name),
      version: Value(version),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      manifestUrl: Value(manifestUrl),
      baseUrl: Value(baseUrl),
      enabled: Value(enabled),
      manifestData: Value(manifestData),
      resources: Value(resources),
      types: Value(types),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Addon.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Addon(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      version: serializer.fromJson<String>(json['version']),
      description: serializer.fromJson<String?>(json['description']),
      manifestUrl: serializer.fromJson<String>(json['manifestUrl']),
      baseUrl: serializer.fromJson<String>(json['baseUrl']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      manifestData: serializer.fromJson<String>(json['manifestData']),
      resources: serializer.fromJson<String>(json['resources']),
      types: serializer.fromJson<String>(json['types']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'version': serializer.toJson<String>(version),
      'description': serializer.toJson<String?>(description),
      'manifestUrl': serializer.toJson<String>(manifestUrl),
      'baseUrl': serializer.toJson<String>(baseUrl),
      'enabled': serializer.toJson<bool>(enabled),
      'manifestData': serializer.toJson<String>(manifestData),
      'resources': serializer.toJson<String>(resources),
      'types': serializer.toJson<String>(types),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Addon copyWith(
          {String? id,
          String? name,
          String? version,
          Value<String?> description = const Value.absent(),
          String? manifestUrl,
          String? baseUrl,
          bool? enabled,
          String? manifestData,
          String? resources,
          String? types,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      Addon(
        id: id ?? this.id,
        name: name ?? this.name,
        version: version ?? this.version,
        description: description.present ? description.value : this.description,
        manifestUrl: manifestUrl ?? this.manifestUrl,
        baseUrl: baseUrl ?? this.baseUrl,
        enabled: enabled ?? this.enabled,
        manifestData: manifestData ?? this.manifestData,
        resources: resources ?? this.resources,
        types: types ?? this.types,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Addon copyWithCompanion(AddonsCompanion data) {
    return Addon(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      version: data.version.present ? data.version.value : this.version,
      description:
          data.description.present ? data.description.value : this.description,
      manifestUrl:
          data.manifestUrl.present ? data.manifestUrl.value : this.manifestUrl,
      baseUrl: data.baseUrl.present ? data.baseUrl.value : this.baseUrl,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      manifestData: data.manifestData.present
          ? data.manifestData.value
          : this.manifestData,
      resources: data.resources.present ? data.resources.value : this.resources,
      types: data.types.present ? data.types.value : this.types,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Addon(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('version: $version, ')
          ..write('description: $description, ')
          ..write('manifestUrl: $manifestUrl, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('enabled: $enabled, ')
          ..write('manifestData: $manifestData, ')
          ..write('resources: $resources, ')
          ..write('types: $types, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, version, description, manifestUrl,
      baseUrl, enabled, manifestData, resources, types, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Addon &&
          other.id == this.id &&
          other.name == this.name &&
          other.version == this.version &&
          other.description == this.description &&
          other.manifestUrl == this.manifestUrl &&
          other.baseUrl == this.baseUrl &&
          other.enabled == this.enabled &&
          other.manifestData == this.manifestData &&
          other.resources == this.resources &&
          other.types == this.types &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AddonsCompanion extends UpdateCompanion<Addon> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> version;
  final Value<String?> description;
  final Value<String> manifestUrl;
  final Value<String> baseUrl;
  final Value<bool> enabled;
  final Value<String> manifestData;
  final Value<String> resources;
  final Value<String> types;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AddonsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.version = const Value.absent(),
    this.description = const Value.absent(),
    this.manifestUrl = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.enabled = const Value.absent(),
    this.manifestData = const Value.absent(),
    this.resources = const Value.absent(),
    this.types = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AddonsCompanion.insert({
    required String id,
    required String name,
    required String version,
    this.description = const Value.absent(),
    required String manifestUrl,
    required String baseUrl,
    this.enabled = const Value.absent(),
    required String manifestData,
    required String resources,
    required String types,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        version = Value(version),
        manifestUrl = Value(manifestUrl),
        baseUrl = Value(baseUrl),
        manifestData = Value(manifestData),
        resources = Value(resources),
        types = Value(types),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<Addon> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? version,
    Expression<String>? description,
    Expression<String>? manifestUrl,
    Expression<String>? baseUrl,
    Expression<bool>? enabled,
    Expression<String>? manifestData,
    Expression<String>? resources,
    Expression<String>? types,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (version != null) 'version': version,
      if (description != null) 'description': description,
      if (manifestUrl != null) 'manifest_url': manifestUrl,
      if (baseUrl != null) 'base_url': baseUrl,
      if (enabled != null) 'enabled': enabled,
      if (manifestData != null) 'manifest_data': manifestData,
      if (resources != null) 'resources': resources,
      if (types != null) 'types': types,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AddonsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? version,
      Value<String?>? description,
      Value<String>? manifestUrl,
      Value<String>? baseUrl,
      Value<bool>? enabled,
      Value<String>? manifestData,
      Value<String>? resources,
      Value<String>? types,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return AddonsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      version: version ?? this.version,
      description: description ?? this.description,
      manifestUrl: manifestUrl ?? this.manifestUrl,
      baseUrl: baseUrl ?? this.baseUrl,
      enabled: enabled ?? this.enabled,
      manifestData: manifestData ?? this.manifestData,
      resources: resources ?? this.resources,
      types: types ?? this.types,
      createdAt: createdAt ?? this.createdAt,
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
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (manifestUrl.present) {
      map['manifest_url'] = Variable<String>(manifestUrl.value);
    }
    if (baseUrl.present) {
      map['base_url'] = Variable<String>(baseUrl.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (manifestData.present) {
      map['manifest_data'] = Variable<String>(manifestData.value);
    }
    if (resources.present) {
      map['resources'] = Variable<String>(resources.value);
    }
    if (types.present) {
      map['types'] = Variable<String>(types.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
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
    return (StringBuffer('AddonsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('version: $version, ')
          ..write('description: $description, ')
          ..write('manifestUrl: $manifestUrl, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('enabled: $enabled, ')
          ..write('manifestData: $manifestData, ')
          ..write('resources: $resources, ')
          ..write('types: $types, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CatalogPreferencesTable extends CatalogPreferences
    with TableInfo<$CatalogPreferencesTable, CatalogPreference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatalogPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _addonIdMeta =
      const VerificationMeta('addonId');
  @override
  late final GeneratedColumn<String> addonId = GeneratedColumn<String>(
      'addon_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _catalogTypeMeta =
      const VerificationMeta('catalogType');
  @override
  late final GeneratedColumn<String> catalogType = GeneratedColumn<String>(
      'catalog_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _catalogIdMeta =
      const VerificationMeta('catalogId');
  @override
  late final GeneratedColumn<String> catalogId = GeneratedColumn<String>(
      'catalog_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _enabledMeta =
      const VerificationMeta('enabled');
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
      'enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("enabled" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _isHeroSourceMeta =
      const VerificationMeta('isHeroSource');
  @override
  late final GeneratedColumn<bool> isHeroSource = GeneratedColumn<bool>(
      'is_hero_source', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_hero_source" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        addonId,
        catalogType,
        catalogId,
        enabled,
        isHeroSource,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'catalog_preferences';
  @override
  VerificationContext validateIntegrity(Insertable<CatalogPreference> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('addon_id')) {
      context.handle(_addonIdMeta,
          addonId.isAcceptableOrUnknown(data['addon_id']!, _addonIdMeta));
    } else if (isInserting) {
      context.missing(_addonIdMeta);
    }
    if (data.containsKey('catalog_type')) {
      context.handle(
          _catalogTypeMeta,
          catalogType.isAcceptableOrUnknown(
              data['catalog_type']!, _catalogTypeMeta));
    } else if (isInserting) {
      context.missing(_catalogTypeMeta);
    }
    if (data.containsKey('catalog_id')) {
      context.handle(_catalogIdMeta,
          catalogId.isAcceptableOrUnknown(data['catalog_id']!, _catalogIdMeta));
    }
    if (data.containsKey('enabled')) {
      context.handle(_enabledMeta,
          enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta));
    }
    if (data.containsKey('is_hero_source')) {
      context.handle(
          _isHeroSourceMeta,
          isHeroSource.isAcceptableOrUnknown(
              data['is_hero_source']!, _isHeroSourceMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {addonId, catalogType, catalogId};
  @override
  CatalogPreference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatalogPreference(
      addonId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}addon_id'])!,
      catalogType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}catalog_type'])!,
      catalogId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}catalog_id']),
      enabled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}enabled'])!,
      isHeroSource: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_hero_source'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $CatalogPreferencesTable createAlias(String alias) {
    return $CatalogPreferencesTable(attachedDatabase, alias);
  }
}

class CatalogPreference extends DataClass
    implements Insertable<CatalogPreference> {
  final String addonId;
  final String catalogType;
  final String? catalogId;
  final bool enabled;
  final bool isHeroSource;
  final DateTime createdAt;
  final DateTime updatedAt;
  const CatalogPreference(
      {required this.addonId,
      required this.catalogType,
      this.catalogId,
      required this.enabled,
      required this.isHeroSource,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['addon_id'] = Variable<String>(addonId);
    map['catalog_type'] = Variable<String>(catalogType);
    if (!nullToAbsent || catalogId != null) {
      map['catalog_id'] = Variable<String>(catalogId);
    }
    map['enabled'] = Variable<bool>(enabled);
    map['is_hero_source'] = Variable<bool>(isHeroSource);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CatalogPreferencesCompanion toCompanion(bool nullToAbsent) {
    return CatalogPreferencesCompanion(
      addonId: Value(addonId),
      catalogType: Value(catalogType),
      catalogId: catalogId == null && nullToAbsent
          ? const Value.absent()
          : Value(catalogId),
      enabled: Value(enabled),
      isHeroSource: Value(isHeroSource),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory CatalogPreference.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatalogPreference(
      addonId: serializer.fromJson<String>(json['addonId']),
      catalogType: serializer.fromJson<String>(json['catalogType']),
      catalogId: serializer.fromJson<String?>(json['catalogId']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      isHeroSource: serializer.fromJson<bool>(json['isHeroSource']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'addonId': serializer.toJson<String>(addonId),
      'catalogType': serializer.toJson<String>(catalogType),
      'catalogId': serializer.toJson<String?>(catalogId),
      'enabled': serializer.toJson<bool>(enabled),
      'isHeroSource': serializer.toJson<bool>(isHeroSource),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CatalogPreference copyWith(
          {String? addonId,
          String? catalogType,
          Value<String?> catalogId = const Value.absent(),
          bool? enabled,
          bool? isHeroSource,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      CatalogPreference(
        addonId: addonId ?? this.addonId,
        catalogType: catalogType ?? this.catalogType,
        catalogId: catalogId.present ? catalogId.value : this.catalogId,
        enabled: enabled ?? this.enabled,
        isHeroSource: isHeroSource ?? this.isHeroSource,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  CatalogPreference copyWithCompanion(CatalogPreferencesCompanion data) {
    return CatalogPreference(
      addonId: data.addonId.present ? data.addonId.value : this.addonId,
      catalogType:
          data.catalogType.present ? data.catalogType.value : this.catalogType,
      catalogId: data.catalogId.present ? data.catalogId.value : this.catalogId,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      isHeroSource: data.isHeroSource.present
          ? data.isHeroSource.value
          : this.isHeroSource,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatalogPreference(')
          ..write('addonId: $addonId, ')
          ..write('catalogType: $catalogType, ')
          ..write('catalogId: $catalogId, ')
          ..write('enabled: $enabled, ')
          ..write('isHeroSource: $isHeroSource, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(addonId, catalogType, catalogId, enabled,
      isHeroSource, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatalogPreference &&
          other.addonId == this.addonId &&
          other.catalogType == this.catalogType &&
          other.catalogId == this.catalogId &&
          other.enabled == this.enabled &&
          other.isHeroSource == this.isHeroSource &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CatalogPreferencesCompanion extends UpdateCompanion<CatalogPreference> {
  final Value<String> addonId;
  final Value<String> catalogType;
  final Value<String?> catalogId;
  final Value<bool> enabled;
  final Value<bool> isHeroSource;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CatalogPreferencesCompanion({
    this.addonId = const Value.absent(),
    this.catalogType = const Value.absent(),
    this.catalogId = const Value.absent(),
    this.enabled = const Value.absent(),
    this.isHeroSource = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CatalogPreferencesCompanion.insert({
    required String addonId,
    required String catalogType,
    this.catalogId = const Value.absent(),
    this.enabled = const Value.absent(),
    this.isHeroSource = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : addonId = Value(addonId),
        catalogType = Value(catalogType),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<CatalogPreference> custom({
    Expression<String>? addonId,
    Expression<String>? catalogType,
    Expression<String>? catalogId,
    Expression<bool>? enabled,
    Expression<bool>? isHeroSource,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (addonId != null) 'addon_id': addonId,
      if (catalogType != null) 'catalog_type': catalogType,
      if (catalogId != null) 'catalog_id': catalogId,
      if (enabled != null) 'enabled': enabled,
      if (isHeroSource != null) 'is_hero_source': isHeroSource,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CatalogPreferencesCompanion copyWith(
      {Value<String>? addonId,
      Value<String>? catalogType,
      Value<String?>? catalogId,
      Value<bool>? enabled,
      Value<bool>? isHeroSource,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return CatalogPreferencesCompanion(
      addonId: addonId ?? this.addonId,
      catalogType: catalogType ?? this.catalogType,
      catalogId: catalogId ?? this.catalogId,
      enabled: enabled ?? this.enabled,
      isHeroSource: isHeroSource ?? this.isHeroSource,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (addonId.present) {
      map['addon_id'] = Variable<String>(addonId.value);
    }
    if (catalogType.present) {
      map['catalog_type'] = Variable<String>(catalogType.value);
    }
    if (catalogId.present) {
      map['catalog_id'] = Variable<String>(catalogId.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (isHeroSource.present) {
      map['is_hero_source'] = Variable<bool>(isHeroSource.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
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
    return (StringBuffer('CatalogPreferencesCompanion(')
          ..write('addonId: $addonId, ')
          ..write('catalogType: $catalogType, ')
          ..write('catalogId: $catalogId, ')
          ..write('enabled: $enabled, ')
          ..write('isHeroSource: $isHeroSource, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AddonsTable addons = $AddonsTable(this);
  late final $CatalogPreferencesTable catalogPreferences =
      $CatalogPreferencesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [addons, catalogPreferences];
}

typedef $$AddonsTableCreateCompanionBuilder = AddonsCompanion Function({
  required String id,
  required String name,
  required String version,
  Value<String?> description,
  required String manifestUrl,
  required String baseUrl,
  Value<bool> enabled,
  required String manifestData,
  required String resources,
  required String types,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$AddonsTableUpdateCompanionBuilder = AddonsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> version,
  Value<String?> description,
  Value<String> manifestUrl,
  Value<String> baseUrl,
  Value<bool> enabled,
  Value<String> manifestData,
  Value<String> resources,
  Value<String> types,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$AddonsTableFilterComposer
    extends Composer<_$AppDatabase, $AddonsTable> {
  $$AddonsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get manifestUrl => $composableBuilder(
      column: $table.manifestUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get baseUrl => $composableBuilder(
      column: $table.baseUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get enabled => $composableBuilder(
      column: $table.enabled, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get manifestData => $composableBuilder(
      column: $table.manifestData, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get resources => $composableBuilder(
      column: $table.resources, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get types => $composableBuilder(
      column: $table.types, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$AddonsTableOrderingComposer
    extends Composer<_$AppDatabase, $AddonsTable> {
  $$AddonsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get manifestUrl => $composableBuilder(
      column: $table.manifestUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get baseUrl => $composableBuilder(
      column: $table.baseUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get enabled => $composableBuilder(
      column: $table.enabled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get manifestData => $composableBuilder(
      column: $table.manifestData,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get resources => $composableBuilder(
      column: $table.resources, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get types => $composableBuilder(
      column: $table.types, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$AddonsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AddonsTable> {
  $$AddonsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get manifestUrl => $composableBuilder(
      column: $table.manifestUrl, builder: (column) => column);

  GeneratedColumn<String> get baseUrl =>
      $composableBuilder(column: $table.baseUrl, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<String> get manifestData => $composableBuilder(
      column: $table.manifestData, builder: (column) => column);

  GeneratedColumn<String> get resources =>
      $composableBuilder(column: $table.resources, builder: (column) => column);

  GeneratedColumn<String> get types =>
      $composableBuilder(column: $table.types, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AddonsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AddonsTable,
    Addon,
    $$AddonsTableFilterComposer,
    $$AddonsTableOrderingComposer,
    $$AddonsTableAnnotationComposer,
    $$AddonsTableCreateCompanionBuilder,
    $$AddonsTableUpdateCompanionBuilder,
    (Addon, BaseReferences<_$AppDatabase, $AddonsTable, Addon>),
    Addon,
    PrefetchHooks Function()> {
  $$AddonsTableTableManager(_$AppDatabase db, $AddonsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AddonsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AddonsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AddonsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> version = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String> manifestUrl = const Value.absent(),
            Value<String> baseUrl = const Value.absent(),
            Value<bool> enabled = const Value.absent(),
            Value<String> manifestData = const Value.absent(),
            Value<String> resources = const Value.absent(),
            Value<String> types = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AddonsCompanion(
            id: id,
            name: name,
            version: version,
            description: description,
            manifestUrl: manifestUrl,
            baseUrl: baseUrl,
            enabled: enabled,
            manifestData: manifestData,
            resources: resources,
            types: types,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String version,
            Value<String?> description = const Value.absent(),
            required String manifestUrl,
            required String baseUrl,
            Value<bool> enabled = const Value.absent(),
            required String manifestData,
            required String resources,
            required String types,
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              AddonsCompanion.insert(
            id: id,
            name: name,
            version: version,
            description: description,
            manifestUrl: manifestUrl,
            baseUrl: baseUrl,
            enabled: enabled,
            manifestData: manifestData,
            resources: resources,
            types: types,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AddonsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AddonsTable,
    Addon,
    $$AddonsTableFilterComposer,
    $$AddonsTableOrderingComposer,
    $$AddonsTableAnnotationComposer,
    $$AddonsTableCreateCompanionBuilder,
    $$AddonsTableUpdateCompanionBuilder,
    (Addon, BaseReferences<_$AppDatabase, $AddonsTable, Addon>),
    Addon,
    PrefetchHooks Function()>;
typedef $$CatalogPreferencesTableCreateCompanionBuilder
    = CatalogPreferencesCompanion Function({
  required String addonId,
  required String catalogType,
  Value<String?> catalogId,
  Value<bool> enabled,
  Value<bool> isHeroSource,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$CatalogPreferencesTableUpdateCompanionBuilder
    = CatalogPreferencesCompanion Function({
  Value<String> addonId,
  Value<String> catalogType,
  Value<String?> catalogId,
  Value<bool> enabled,
  Value<bool> isHeroSource,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$CatalogPreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $CatalogPreferencesTable> {
  $$CatalogPreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get addonId => $composableBuilder(
      column: $table.addonId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get catalogType => $composableBuilder(
      column: $table.catalogType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get catalogId => $composableBuilder(
      column: $table.catalogId, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get enabled => $composableBuilder(
      column: $table.enabled, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isHeroSource => $composableBuilder(
      column: $table.isHeroSource, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$CatalogPreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $CatalogPreferencesTable> {
  $$CatalogPreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get addonId => $composableBuilder(
      column: $table.addonId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get catalogType => $composableBuilder(
      column: $table.catalogType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get catalogId => $composableBuilder(
      column: $table.catalogId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get enabled => $composableBuilder(
      column: $table.enabled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isHeroSource => $composableBuilder(
      column: $table.isHeroSource,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$CatalogPreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CatalogPreferencesTable> {
  $$CatalogPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get addonId =>
      $composableBuilder(column: $table.addonId, builder: (column) => column);

  GeneratedColumn<String> get catalogType => $composableBuilder(
      column: $table.catalogType, builder: (column) => column);

  GeneratedColumn<String> get catalogId =>
      $composableBuilder(column: $table.catalogId, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<bool> get isHeroSource => $composableBuilder(
      column: $table.isHeroSource, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CatalogPreferencesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CatalogPreferencesTable,
    CatalogPreference,
    $$CatalogPreferencesTableFilterComposer,
    $$CatalogPreferencesTableOrderingComposer,
    $$CatalogPreferencesTableAnnotationComposer,
    $$CatalogPreferencesTableCreateCompanionBuilder,
    $$CatalogPreferencesTableUpdateCompanionBuilder,
    (
      CatalogPreference,
      BaseReferences<_$AppDatabase, $CatalogPreferencesTable, CatalogPreference>
    ),
    CatalogPreference,
    PrefetchHooks Function()> {
  $$CatalogPreferencesTableTableManager(
      _$AppDatabase db, $CatalogPreferencesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatalogPreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatalogPreferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CatalogPreferencesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> addonId = const Value.absent(),
            Value<String> catalogType = const Value.absent(),
            Value<String?> catalogId = const Value.absent(),
            Value<bool> enabled = const Value.absent(),
            Value<bool> isHeroSource = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CatalogPreferencesCompanion(
            addonId: addonId,
            catalogType: catalogType,
            catalogId: catalogId,
            enabled: enabled,
            isHeroSource: isHeroSource,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String addonId,
            required String catalogType,
            Value<String?> catalogId = const Value.absent(),
            Value<bool> enabled = const Value.absent(),
            Value<bool> isHeroSource = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              CatalogPreferencesCompanion.insert(
            addonId: addonId,
            catalogType: catalogType,
            catalogId: catalogId,
            enabled: enabled,
            isHeroSource: isHeroSource,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CatalogPreferencesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CatalogPreferencesTable,
    CatalogPreference,
    $$CatalogPreferencesTableFilterComposer,
    $$CatalogPreferencesTableOrderingComposer,
    $$CatalogPreferencesTableAnnotationComposer,
    $$CatalogPreferencesTableCreateCompanionBuilder,
    $$CatalogPreferencesTableUpdateCompanionBuilder,
    (
      CatalogPreference,
      BaseReferences<_$AppDatabase, $CatalogPreferencesTable, CatalogPreference>
    ),
    CatalogPreference,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AddonsTableTableManager get addons =>
      $$AddonsTableTableManager(_db, _db.addons);
  $$CatalogPreferencesTableTableManager get catalogPreferences =>
      $$CatalogPreferencesTableTableManager(_db, _db.catalogPreferences);
}
