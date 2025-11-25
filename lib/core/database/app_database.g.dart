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

class $TraktAuthTable extends TraktAuth
    with TableInfo<$TraktAuthTable, TraktAuthData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TraktAuthTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _accessTokenMeta =
      const VerificationMeta('accessToken');
  @override
  late final GeneratedColumn<String> accessToken = GeneratedColumn<String>(
      'access_token', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _refreshTokenMeta =
      const VerificationMeta('refreshToken');
  @override
  late final GeneratedColumn<String> refreshToken = GeneratedColumn<String>(
      'refresh_token', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _expiresInMeta =
      const VerificationMeta('expiresIn');
  @override
  late final GeneratedColumn<int> expiresIn = GeneratedColumn<int>(
      'expires_in', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _expiresAtMeta =
      const VerificationMeta('expiresAt');
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
      'expires_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _usernameMeta =
      const VerificationMeta('username');
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
      'username', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _slugMeta = const VerificationMeta('slug');
  @override
  late final GeneratedColumn<String> slug = GeneratedColumn<String>(
      'slug', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        accessToken,
        refreshToken,
        expiresIn,
        createdAt,
        expiresAt,
        username,
        slug
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trakt_auth';
  @override
  VerificationContext validateIntegrity(Insertable<TraktAuthData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('access_token')) {
      context.handle(
          _accessTokenMeta,
          accessToken.isAcceptableOrUnknown(
              data['access_token']!, _accessTokenMeta));
    } else if (isInserting) {
      context.missing(_accessTokenMeta);
    }
    if (data.containsKey('refresh_token')) {
      context.handle(
          _refreshTokenMeta,
          refreshToken.isAcceptableOrUnknown(
              data['refresh_token']!, _refreshTokenMeta));
    } else if (isInserting) {
      context.missing(_refreshTokenMeta);
    }
    if (data.containsKey('expires_in')) {
      context.handle(_expiresInMeta,
          expiresIn.isAcceptableOrUnknown(data['expires_in']!, _expiresInMeta));
    } else if (isInserting) {
      context.missing(_expiresInMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(_expiresAtMeta,
          expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta));
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    if (data.containsKey('username')) {
      context.handle(_usernameMeta,
          username.isAcceptableOrUnknown(data['username']!, _usernameMeta));
    }
    if (data.containsKey('slug')) {
      context.handle(
          _slugMeta, slug.isAcceptableOrUnknown(data['slug']!, _slugMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TraktAuthData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TraktAuthData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      accessToken: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}access_token'])!,
      refreshToken: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}refresh_token'])!,
      expiresIn: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}expires_in'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      expiresAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}expires_at'])!,
      username: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}username']),
      slug: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}slug']),
    );
  }

  @override
  $TraktAuthTable createAlias(String alias) {
    return $TraktAuthTable(attachedDatabase, alias);
  }
}

class TraktAuthData extends DataClass implements Insertable<TraktAuthData> {
  final int id;
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? username;
  final String? slug;
  const TraktAuthData(
      {required this.id,
      required this.accessToken,
      required this.refreshToken,
      required this.expiresIn,
      required this.createdAt,
      required this.expiresAt,
      this.username,
      this.slug});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['access_token'] = Variable<String>(accessToken);
    map['refresh_token'] = Variable<String>(refreshToken);
    map['expires_in'] = Variable<int>(expiresIn);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    if (!nullToAbsent || username != null) {
      map['username'] = Variable<String>(username);
    }
    if (!nullToAbsent || slug != null) {
      map['slug'] = Variable<String>(slug);
    }
    return map;
  }

  TraktAuthCompanion toCompanion(bool nullToAbsent) {
    return TraktAuthCompanion(
      id: Value(id),
      accessToken: Value(accessToken),
      refreshToken: Value(refreshToken),
      expiresIn: Value(expiresIn),
      createdAt: Value(createdAt),
      expiresAt: Value(expiresAt),
      username: username == null && nullToAbsent
          ? const Value.absent()
          : Value(username),
      slug: slug == null && nullToAbsent ? const Value.absent() : Value(slug),
    );
  }

  factory TraktAuthData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TraktAuthData(
      id: serializer.fromJson<int>(json['id']),
      accessToken: serializer.fromJson<String>(json['accessToken']),
      refreshToken: serializer.fromJson<String>(json['refreshToken']),
      expiresIn: serializer.fromJson<int>(json['expiresIn']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
      username: serializer.fromJson<String?>(json['username']),
      slug: serializer.fromJson<String?>(json['slug']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'accessToken': serializer.toJson<String>(accessToken),
      'refreshToken': serializer.toJson<String>(refreshToken),
      'expiresIn': serializer.toJson<int>(expiresIn),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
      'username': serializer.toJson<String?>(username),
      'slug': serializer.toJson<String?>(slug),
    };
  }

  TraktAuthData copyWith(
          {int? id,
          String? accessToken,
          String? refreshToken,
          int? expiresIn,
          DateTime? createdAt,
          DateTime? expiresAt,
          Value<String?> username = const Value.absent(),
          Value<String?> slug = const Value.absent()}) =>
      TraktAuthData(
        id: id ?? this.id,
        accessToken: accessToken ?? this.accessToken,
        refreshToken: refreshToken ?? this.refreshToken,
        expiresIn: expiresIn ?? this.expiresIn,
        createdAt: createdAt ?? this.createdAt,
        expiresAt: expiresAt ?? this.expiresAt,
        username: username.present ? username.value : this.username,
        slug: slug.present ? slug.value : this.slug,
      );
  TraktAuthData copyWithCompanion(TraktAuthCompanion data) {
    return TraktAuthData(
      id: data.id.present ? data.id.value : this.id,
      accessToken:
          data.accessToken.present ? data.accessToken.value : this.accessToken,
      refreshToken: data.refreshToken.present
          ? data.refreshToken.value
          : this.refreshToken,
      expiresIn: data.expiresIn.present ? data.expiresIn.value : this.expiresIn,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      username: data.username.present ? data.username.value : this.username,
      slug: data.slug.present ? data.slug.value : this.slug,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TraktAuthData(')
          ..write('id: $id, ')
          ..write('accessToken: $accessToken, ')
          ..write('refreshToken: $refreshToken, ')
          ..write('expiresIn: $expiresIn, ')
          ..write('createdAt: $createdAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('username: $username, ')
          ..write('slug: $slug')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, accessToken, refreshToken, expiresIn,
      createdAt, expiresAt, username, slug);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TraktAuthData &&
          other.id == this.id &&
          other.accessToken == this.accessToken &&
          other.refreshToken == this.refreshToken &&
          other.expiresIn == this.expiresIn &&
          other.createdAt == this.createdAt &&
          other.expiresAt == this.expiresAt &&
          other.username == this.username &&
          other.slug == this.slug);
}

class TraktAuthCompanion extends UpdateCompanion<TraktAuthData> {
  final Value<int> id;
  final Value<String> accessToken;
  final Value<String> refreshToken;
  final Value<int> expiresIn;
  final Value<DateTime> createdAt;
  final Value<DateTime> expiresAt;
  final Value<String?> username;
  final Value<String?> slug;
  const TraktAuthCompanion({
    this.id = const Value.absent(),
    this.accessToken = const Value.absent(),
    this.refreshToken = const Value.absent(),
    this.expiresIn = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.username = const Value.absent(),
    this.slug = const Value.absent(),
  });
  TraktAuthCompanion.insert({
    this.id = const Value.absent(),
    required String accessToken,
    required String refreshToken,
    required int expiresIn,
    required DateTime createdAt,
    required DateTime expiresAt,
    this.username = const Value.absent(),
    this.slug = const Value.absent(),
  })  : accessToken = Value(accessToken),
        refreshToken = Value(refreshToken),
        expiresIn = Value(expiresIn),
        createdAt = Value(createdAt),
        expiresAt = Value(expiresAt);
  static Insertable<TraktAuthData> custom({
    Expression<int>? id,
    Expression<String>? accessToken,
    Expression<String>? refreshToken,
    Expression<int>? expiresIn,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? expiresAt,
    Expression<String>? username,
    Expression<String>? slug,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accessToken != null) 'access_token': accessToken,
      if (refreshToken != null) 'refresh_token': refreshToken,
      if (expiresIn != null) 'expires_in': expiresIn,
      if (createdAt != null) 'created_at': createdAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (username != null) 'username': username,
      if (slug != null) 'slug': slug,
    });
  }

  TraktAuthCompanion copyWith(
      {Value<int>? id,
      Value<String>? accessToken,
      Value<String>? refreshToken,
      Value<int>? expiresIn,
      Value<DateTime>? createdAt,
      Value<DateTime>? expiresAt,
      Value<String?>? username,
      Value<String?>? slug}) {
    return TraktAuthCompanion(
      id: id ?? this.id,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresIn: expiresIn ?? this.expiresIn,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      username: username ?? this.username,
      slug: slug ?? this.slug,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (accessToken.present) {
      map['access_token'] = Variable<String>(accessToken.value);
    }
    if (refreshToken.present) {
      map['refresh_token'] = Variable<String>(refreshToken.value);
    }
    if (expiresIn.present) {
      map['expires_in'] = Variable<int>(expiresIn.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (slug.present) {
      map['slug'] = Variable<String>(slug.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TraktAuthCompanion(')
          ..write('id: $id, ')
          ..write('accessToken: $accessToken, ')
          ..write('refreshToken: $refreshToken, ')
          ..write('expiresIn: $expiresIn, ')
          ..write('createdAt: $createdAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('username: $username, ')
          ..write('slug: $slug')
          ..write(')'))
        .toString();
  }
}

class $WatchHistoryTable extends WatchHistory
    with TableInfo<$WatchHistoryTable, WatchHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WatchHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _traktIdMeta =
      const VerificationMeta('traktId');
  @override
  late final GeneratedColumn<String> traktId = GeneratedColumn<String>(
      'trakt_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _imdbIdMeta = const VerificationMeta('imdbId');
  @override
  late final GeneratedColumn<String> imdbId = GeneratedColumn<String>(
      'imdb_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _tmdbIdMeta = const VerificationMeta('tmdbId');
  @override
  late final GeneratedColumn<String> tmdbId = GeneratedColumn<String>(
      'tmdb_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _seasonNumberMeta =
      const VerificationMeta('seasonNumber');
  @override
  late final GeneratedColumn<int> seasonNumber = GeneratedColumn<int>(
      'season_number', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _episodeNumberMeta =
      const VerificationMeta('episodeNumber');
  @override
  late final GeneratedColumn<int> episodeNumber = GeneratedColumn<int>(
      'episode_number', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _progressMeta =
      const VerificationMeta('progress');
  @override
  late final GeneratedColumn<double> progress = GeneratedColumn<double>(
      'progress', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _watchedAtMeta =
      const VerificationMeta('watchedAt');
  @override
  late final GeneratedColumn<DateTime> watchedAt = GeneratedColumn<DateTime>(
      'watched_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _pausedAtMeta =
      const VerificationMeta('pausedAt');
  @override
  late final GeneratedColumn<DateTime> pausedAt = GeneratedColumn<DateTime>(
      'paused_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _runtimeMeta =
      const VerificationMeta('runtime');
  @override
  late final GeneratedColumn<int> runtime = GeneratedColumn<int>(
      'runtime', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _lastSyncedAtMeta =
      const VerificationMeta('lastSyncedAt');
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
      'last_synced_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        traktId,
        type,
        title,
        imdbId,
        tmdbId,
        seasonNumber,
        episodeNumber,
        progress,
        watchedAt,
        pausedAt,
        runtime,
        lastSyncedAt,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'watch_history';
  @override
  VerificationContext validateIntegrity(Insertable<WatchHistoryData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('trakt_id')) {
      context.handle(_traktIdMeta,
          traktId.isAcceptableOrUnknown(data['trakt_id']!, _traktIdMeta));
    } else if (isInserting) {
      context.missing(_traktIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('imdb_id')) {
      context.handle(_imdbIdMeta,
          imdbId.isAcceptableOrUnknown(data['imdb_id']!, _imdbIdMeta));
    }
    if (data.containsKey('tmdb_id')) {
      context.handle(_tmdbIdMeta,
          tmdbId.isAcceptableOrUnknown(data['tmdb_id']!, _tmdbIdMeta));
    }
    if (data.containsKey('season_number')) {
      context.handle(
          _seasonNumberMeta,
          seasonNumber.isAcceptableOrUnknown(
              data['season_number']!, _seasonNumberMeta));
    }
    if (data.containsKey('episode_number')) {
      context.handle(
          _episodeNumberMeta,
          episodeNumber.isAcceptableOrUnknown(
              data['episode_number']!, _episodeNumberMeta));
    }
    if (data.containsKey('progress')) {
      context.handle(_progressMeta,
          progress.isAcceptableOrUnknown(data['progress']!, _progressMeta));
    } else if (isInserting) {
      context.missing(_progressMeta);
    }
    if (data.containsKey('watched_at')) {
      context.handle(_watchedAtMeta,
          watchedAt.isAcceptableOrUnknown(data['watched_at']!, _watchedAtMeta));
    } else if (isInserting) {
      context.missing(_watchedAtMeta);
    }
    if (data.containsKey('paused_at')) {
      context.handle(_pausedAtMeta,
          pausedAt.isAcceptableOrUnknown(data['paused_at']!, _pausedAtMeta));
    }
    if (data.containsKey('runtime')) {
      context.handle(_runtimeMeta,
          runtime.isAcceptableOrUnknown(data['runtime']!, _runtimeMeta));
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
          _lastSyncedAtMeta,
          lastSyncedAt.isAcceptableOrUnknown(
              data['last_synced_at']!, _lastSyncedAtMeta));
    } else if (isInserting) {
      context.missing(_lastSyncedAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {traktId};
  @override
  WatchHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WatchHistoryData(
      traktId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}trakt_id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      imdbId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}imdb_id']),
      tmdbId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tmdb_id']),
      seasonNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}season_number']),
      episodeNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}episode_number']),
      progress: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}progress'])!,
      watchedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}watched_at'])!,
      pausedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}paused_at']),
      runtime: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}runtime']),
      lastSyncedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_synced_at'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $WatchHistoryTable createAlias(String alias) {
    return $WatchHistoryTable(attachedDatabase, alias);
  }
}

class WatchHistoryData extends DataClass
    implements Insertable<WatchHistoryData> {
  final String traktId;
  final String type;
  final String title;
  final String? imdbId;
  final String? tmdbId;
  final int? seasonNumber;
  final int? episodeNumber;
  final double progress;
  final DateTime watchedAt;
  final DateTime? pausedAt;
  final int? runtime;
  final DateTime lastSyncedAt;
  final DateTime createdAt;
  const WatchHistoryData(
      {required this.traktId,
      required this.type,
      required this.title,
      this.imdbId,
      this.tmdbId,
      this.seasonNumber,
      this.episodeNumber,
      required this.progress,
      required this.watchedAt,
      this.pausedAt,
      this.runtime,
      required this.lastSyncedAt,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['trakt_id'] = Variable<String>(traktId);
    map['type'] = Variable<String>(type);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || imdbId != null) {
      map['imdb_id'] = Variable<String>(imdbId);
    }
    if (!nullToAbsent || tmdbId != null) {
      map['tmdb_id'] = Variable<String>(tmdbId);
    }
    if (!nullToAbsent || seasonNumber != null) {
      map['season_number'] = Variable<int>(seasonNumber);
    }
    if (!nullToAbsent || episodeNumber != null) {
      map['episode_number'] = Variable<int>(episodeNumber);
    }
    map['progress'] = Variable<double>(progress);
    map['watched_at'] = Variable<DateTime>(watchedAt);
    if (!nullToAbsent || pausedAt != null) {
      map['paused_at'] = Variable<DateTime>(pausedAt);
    }
    if (!nullToAbsent || runtime != null) {
      map['runtime'] = Variable<int>(runtime);
    }
    map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  WatchHistoryCompanion toCompanion(bool nullToAbsent) {
    return WatchHistoryCompanion(
      traktId: Value(traktId),
      type: Value(type),
      title: Value(title),
      imdbId:
          imdbId == null && nullToAbsent ? const Value.absent() : Value(imdbId),
      tmdbId:
          tmdbId == null && nullToAbsent ? const Value.absent() : Value(tmdbId),
      seasonNumber: seasonNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(seasonNumber),
      episodeNumber: episodeNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeNumber),
      progress: Value(progress),
      watchedAt: Value(watchedAt),
      pausedAt: pausedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(pausedAt),
      runtime: runtime == null && nullToAbsent
          ? const Value.absent()
          : Value(runtime),
      lastSyncedAt: Value(lastSyncedAt),
      createdAt: Value(createdAt),
    );
  }

  factory WatchHistoryData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WatchHistoryData(
      traktId: serializer.fromJson<String>(json['traktId']),
      type: serializer.fromJson<String>(json['type']),
      title: serializer.fromJson<String>(json['title']),
      imdbId: serializer.fromJson<String?>(json['imdbId']),
      tmdbId: serializer.fromJson<String?>(json['tmdbId']),
      seasonNumber: serializer.fromJson<int?>(json['seasonNumber']),
      episodeNumber: serializer.fromJson<int?>(json['episodeNumber']),
      progress: serializer.fromJson<double>(json['progress']),
      watchedAt: serializer.fromJson<DateTime>(json['watchedAt']),
      pausedAt: serializer.fromJson<DateTime?>(json['pausedAt']),
      runtime: serializer.fromJson<int?>(json['runtime']),
      lastSyncedAt: serializer.fromJson<DateTime>(json['lastSyncedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'traktId': serializer.toJson<String>(traktId),
      'type': serializer.toJson<String>(type),
      'title': serializer.toJson<String>(title),
      'imdbId': serializer.toJson<String?>(imdbId),
      'tmdbId': serializer.toJson<String?>(tmdbId),
      'seasonNumber': serializer.toJson<int?>(seasonNumber),
      'episodeNumber': serializer.toJson<int?>(episodeNumber),
      'progress': serializer.toJson<double>(progress),
      'watchedAt': serializer.toJson<DateTime>(watchedAt),
      'pausedAt': serializer.toJson<DateTime?>(pausedAt),
      'runtime': serializer.toJson<int?>(runtime),
      'lastSyncedAt': serializer.toJson<DateTime>(lastSyncedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  WatchHistoryData copyWith(
          {String? traktId,
          String? type,
          String? title,
          Value<String?> imdbId = const Value.absent(),
          Value<String?> tmdbId = const Value.absent(),
          Value<int?> seasonNumber = const Value.absent(),
          Value<int?> episodeNumber = const Value.absent(),
          double? progress,
          DateTime? watchedAt,
          Value<DateTime?> pausedAt = const Value.absent(),
          Value<int?> runtime = const Value.absent(),
          DateTime? lastSyncedAt,
          DateTime? createdAt}) =>
      WatchHistoryData(
        traktId: traktId ?? this.traktId,
        type: type ?? this.type,
        title: title ?? this.title,
        imdbId: imdbId.present ? imdbId.value : this.imdbId,
        tmdbId: tmdbId.present ? tmdbId.value : this.tmdbId,
        seasonNumber:
            seasonNumber.present ? seasonNumber.value : this.seasonNumber,
        episodeNumber:
            episodeNumber.present ? episodeNumber.value : this.episodeNumber,
        progress: progress ?? this.progress,
        watchedAt: watchedAt ?? this.watchedAt,
        pausedAt: pausedAt.present ? pausedAt.value : this.pausedAt,
        runtime: runtime.present ? runtime.value : this.runtime,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        createdAt: createdAt ?? this.createdAt,
      );
  WatchHistoryData copyWithCompanion(WatchHistoryCompanion data) {
    return WatchHistoryData(
      traktId: data.traktId.present ? data.traktId.value : this.traktId,
      type: data.type.present ? data.type.value : this.type,
      title: data.title.present ? data.title.value : this.title,
      imdbId: data.imdbId.present ? data.imdbId.value : this.imdbId,
      tmdbId: data.tmdbId.present ? data.tmdbId.value : this.tmdbId,
      seasonNumber: data.seasonNumber.present
          ? data.seasonNumber.value
          : this.seasonNumber,
      episodeNumber: data.episodeNumber.present
          ? data.episodeNumber.value
          : this.episodeNumber,
      progress: data.progress.present ? data.progress.value : this.progress,
      watchedAt: data.watchedAt.present ? data.watchedAt.value : this.watchedAt,
      pausedAt: data.pausedAt.present ? data.pausedAt.value : this.pausedAt,
      runtime: data.runtime.present ? data.runtime.value : this.runtime,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WatchHistoryData(')
          ..write('traktId: $traktId, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('imdbId: $imdbId, ')
          ..write('tmdbId: $tmdbId, ')
          ..write('seasonNumber: $seasonNumber, ')
          ..write('episodeNumber: $episodeNumber, ')
          ..write('progress: $progress, ')
          ..write('watchedAt: $watchedAt, ')
          ..write('pausedAt: $pausedAt, ')
          ..write('runtime: $runtime, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      traktId,
      type,
      title,
      imdbId,
      tmdbId,
      seasonNumber,
      episodeNumber,
      progress,
      watchedAt,
      pausedAt,
      runtime,
      lastSyncedAt,
      createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WatchHistoryData &&
          other.traktId == this.traktId &&
          other.type == this.type &&
          other.title == this.title &&
          other.imdbId == this.imdbId &&
          other.tmdbId == this.tmdbId &&
          other.seasonNumber == this.seasonNumber &&
          other.episodeNumber == this.episodeNumber &&
          other.progress == this.progress &&
          other.watchedAt == this.watchedAt &&
          other.pausedAt == this.pausedAt &&
          other.runtime == this.runtime &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.createdAt == this.createdAt);
}

class WatchHistoryCompanion extends UpdateCompanion<WatchHistoryData> {
  final Value<String> traktId;
  final Value<String> type;
  final Value<String> title;
  final Value<String?> imdbId;
  final Value<String?> tmdbId;
  final Value<int?> seasonNumber;
  final Value<int?> episodeNumber;
  final Value<double> progress;
  final Value<DateTime> watchedAt;
  final Value<DateTime?> pausedAt;
  final Value<int?> runtime;
  final Value<DateTime> lastSyncedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const WatchHistoryCompanion({
    this.traktId = const Value.absent(),
    this.type = const Value.absent(),
    this.title = const Value.absent(),
    this.imdbId = const Value.absent(),
    this.tmdbId = const Value.absent(),
    this.seasonNumber = const Value.absent(),
    this.episodeNumber = const Value.absent(),
    this.progress = const Value.absent(),
    this.watchedAt = const Value.absent(),
    this.pausedAt = const Value.absent(),
    this.runtime = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WatchHistoryCompanion.insert({
    required String traktId,
    required String type,
    required String title,
    this.imdbId = const Value.absent(),
    this.tmdbId = const Value.absent(),
    this.seasonNumber = const Value.absent(),
    this.episodeNumber = const Value.absent(),
    required double progress,
    required DateTime watchedAt,
    this.pausedAt = const Value.absent(),
    this.runtime = const Value.absent(),
    required DateTime lastSyncedAt,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : traktId = Value(traktId),
        type = Value(type),
        title = Value(title),
        progress = Value(progress),
        watchedAt = Value(watchedAt),
        lastSyncedAt = Value(lastSyncedAt),
        createdAt = Value(createdAt);
  static Insertable<WatchHistoryData> custom({
    Expression<String>? traktId,
    Expression<String>? type,
    Expression<String>? title,
    Expression<String>? imdbId,
    Expression<String>? tmdbId,
    Expression<int>? seasonNumber,
    Expression<int>? episodeNumber,
    Expression<double>? progress,
    Expression<DateTime>? watchedAt,
    Expression<DateTime>? pausedAt,
    Expression<int>? runtime,
    Expression<DateTime>? lastSyncedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (traktId != null) 'trakt_id': traktId,
      if (type != null) 'type': type,
      if (title != null) 'title': title,
      if (imdbId != null) 'imdb_id': imdbId,
      if (tmdbId != null) 'tmdb_id': tmdbId,
      if (seasonNumber != null) 'season_number': seasonNumber,
      if (episodeNumber != null) 'episode_number': episodeNumber,
      if (progress != null) 'progress': progress,
      if (watchedAt != null) 'watched_at': watchedAt,
      if (pausedAt != null) 'paused_at': pausedAt,
      if (runtime != null) 'runtime': runtime,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WatchHistoryCompanion copyWith(
      {Value<String>? traktId,
      Value<String>? type,
      Value<String>? title,
      Value<String?>? imdbId,
      Value<String?>? tmdbId,
      Value<int?>? seasonNumber,
      Value<int?>? episodeNumber,
      Value<double>? progress,
      Value<DateTime>? watchedAt,
      Value<DateTime?>? pausedAt,
      Value<int?>? runtime,
      Value<DateTime>? lastSyncedAt,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return WatchHistoryCompanion(
      traktId: traktId ?? this.traktId,
      type: type ?? this.type,
      title: title ?? this.title,
      imdbId: imdbId ?? this.imdbId,
      tmdbId: tmdbId ?? this.tmdbId,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      progress: progress ?? this.progress,
      watchedAt: watchedAt ?? this.watchedAt,
      pausedAt: pausedAt ?? this.pausedAt,
      runtime: runtime ?? this.runtime,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (traktId.present) {
      map['trakt_id'] = Variable<String>(traktId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (imdbId.present) {
      map['imdb_id'] = Variable<String>(imdbId.value);
    }
    if (tmdbId.present) {
      map['tmdb_id'] = Variable<String>(tmdbId.value);
    }
    if (seasonNumber.present) {
      map['season_number'] = Variable<int>(seasonNumber.value);
    }
    if (episodeNumber.present) {
      map['episode_number'] = Variable<int>(episodeNumber.value);
    }
    if (progress.present) {
      map['progress'] = Variable<double>(progress.value);
    }
    if (watchedAt.present) {
      map['watched_at'] = Variable<DateTime>(watchedAt.value);
    }
    if (pausedAt.present) {
      map['paused_at'] = Variable<DateTime>(pausedAt.value);
    }
    if (runtime.present) {
      map['runtime'] = Variable<int>(runtime.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WatchHistoryCompanion(')
          ..write('traktId: $traktId, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('imdbId: $imdbId, ')
          ..write('tmdbId: $tmdbId, ')
          ..write('seasonNumber: $seasonNumber, ')
          ..write('episodeNumber: $episodeNumber, ')
          ..write('progress: $progress, ')
          ..write('watchedAt: $watchedAt, ')
          ..write('pausedAt: $pausedAt, ')
          ..write('runtime: $runtime, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(Insertable<AppSetting> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
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
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
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
  const AppSetting(
      {required this.key, required this.value, required this.updatedAt});
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

  factory AppSetting.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
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
  })  : key = Value(key),
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

  AppSettingsCompanion copyWith(
      {Value<String>? key,
      Value<String>? value,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AddonsTable addons = $AddonsTable(this);
  late final $CatalogPreferencesTable catalogPreferences =
      $CatalogPreferencesTable(this);
  late final $TraktAuthTable traktAuth = $TraktAuthTable(this);
  late final $WatchHistoryTable watchHistory = $WatchHistoryTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [addons, catalogPreferences, traktAuth, watchHistory, appSettings];
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
typedef $$TraktAuthTableCreateCompanionBuilder = TraktAuthCompanion Function({
  Value<int> id,
  required String accessToken,
  required String refreshToken,
  required int expiresIn,
  required DateTime createdAt,
  required DateTime expiresAt,
  Value<String?> username,
  Value<String?> slug,
});
typedef $$TraktAuthTableUpdateCompanionBuilder = TraktAuthCompanion Function({
  Value<int> id,
  Value<String> accessToken,
  Value<String> refreshToken,
  Value<int> expiresIn,
  Value<DateTime> createdAt,
  Value<DateTime> expiresAt,
  Value<String?> username,
  Value<String?> slug,
});

class $$TraktAuthTableFilterComposer
    extends Composer<_$AppDatabase, $TraktAuthTable> {
  $$TraktAuthTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accessToken => $composableBuilder(
      column: $table.accessToken, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get refreshToken => $composableBuilder(
      column: $table.refreshToken, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get expiresIn => $composableBuilder(
      column: $table.expiresIn, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
      column: $table.expiresAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get username => $composableBuilder(
      column: $table.username, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get slug => $composableBuilder(
      column: $table.slug, builder: (column) => ColumnFilters(column));
}

class $$TraktAuthTableOrderingComposer
    extends Composer<_$AppDatabase, $TraktAuthTable> {
  $$TraktAuthTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accessToken => $composableBuilder(
      column: $table.accessToken, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get refreshToken => $composableBuilder(
      column: $table.refreshToken,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get expiresIn => $composableBuilder(
      column: $table.expiresIn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
      column: $table.expiresAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get username => $composableBuilder(
      column: $table.username, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get slug => $composableBuilder(
      column: $table.slug, builder: (column) => ColumnOrderings(column));
}

class $$TraktAuthTableAnnotationComposer
    extends Composer<_$AppDatabase, $TraktAuthTable> {
  $$TraktAuthTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get accessToken => $composableBuilder(
      column: $table.accessToken, builder: (column) => column);

  GeneratedColumn<String> get refreshToken => $composableBuilder(
      column: $table.refreshToken, builder: (column) => column);

  GeneratedColumn<int> get expiresIn =>
      $composableBuilder(column: $table.expiresIn, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get slug =>
      $composableBuilder(column: $table.slug, builder: (column) => column);
}

class $$TraktAuthTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TraktAuthTable,
    TraktAuthData,
    $$TraktAuthTableFilterComposer,
    $$TraktAuthTableOrderingComposer,
    $$TraktAuthTableAnnotationComposer,
    $$TraktAuthTableCreateCompanionBuilder,
    $$TraktAuthTableUpdateCompanionBuilder,
    (
      TraktAuthData,
      BaseReferences<_$AppDatabase, $TraktAuthTable, TraktAuthData>
    ),
    TraktAuthData,
    PrefetchHooks Function()> {
  $$TraktAuthTableTableManager(_$AppDatabase db, $TraktAuthTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TraktAuthTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TraktAuthTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TraktAuthTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> accessToken = const Value.absent(),
            Value<String> refreshToken = const Value.absent(),
            Value<int> expiresIn = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> expiresAt = const Value.absent(),
            Value<String?> username = const Value.absent(),
            Value<String?> slug = const Value.absent(),
          }) =>
              TraktAuthCompanion(
            id: id,
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresIn: expiresIn,
            createdAt: createdAt,
            expiresAt: expiresAt,
            username: username,
            slug: slug,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String accessToken,
            required String refreshToken,
            required int expiresIn,
            required DateTime createdAt,
            required DateTime expiresAt,
            Value<String?> username = const Value.absent(),
            Value<String?> slug = const Value.absent(),
          }) =>
              TraktAuthCompanion.insert(
            id: id,
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresIn: expiresIn,
            createdAt: createdAt,
            expiresAt: expiresAt,
            username: username,
            slug: slug,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TraktAuthTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TraktAuthTable,
    TraktAuthData,
    $$TraktAuthTableFilterComposer,
    $$TraktAuthTableOrderingComposer,
    $$TraktAuthTableAnnotationComposer,
    $$TraktAuthTableCreateCompanionBuilder,
    $$TraktAuthTableUpdateCompanionBuilder,
    (
      TraktAuthData,
      BaseReferences<_$AppDatabase, $TraktAuthTable, TraktAuthData>
    ),
    TraktAuthData,
    PrefetchHooks Function()>;
typedef $$WatchHistoryTableCreateCompanionBuilder = WatchHistoryCompanion
    Function({
  required String traktId,
  required String type,
  required String title,
  Value<String?> imdbId,
  Value<String?> tmdbId,
  Value<int?> seasonNumber,
  Value<int?> episodeNumber,
  required double progress,
  required DateTime watchedAt,
  Value<DateTime?> pausedAt,
  Value<int?> runtime,
  required DateTime lastSyncedAt,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$WatchHistoryTableUpdateCompanionBuilder = WatchHistoryCompanion
    Function({
  Value<String> traktId,
  Value<String> type,
  Value<String> title,
  Value<String?> imdbId,
  Value<String?> tmdbId,
  Value<int?> seasonNumber,
  Value<int?> episodeNumber,
  Value<double> progress,
  Value<DateTime> watchedAt,
  Value<DateTime?> pausedAt,
  Value<int?> runtime,
  Value<DateTime> lastSyncedAt,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$WatchHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $WatchHistoryTable> {
  $$WatchHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get traktId => $composableBuilder(
      column: $table.traktId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imdbId => $composableBuilder(
      column: $table.imdbId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tmdbId => $composableBuilder(
      column: $table.tmdbId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get seasonNumber => $composableBuilder(
      column: $table.seasonNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get episodeNumber => $composableBuilder(
      column: $table.episodeNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get progress => $composableBuilder(
      column: $table.progress, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get watchedAt => $composableBuilder(
      column: $table.watchedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get pausedAt => $composableBuilder(
      column: $table.pausedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get runtime => $composableBuilder(
      column: $table.runtime, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
      column: $table.lastSyncedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$WatchHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $WatchHistoryTable> {
  $$WatchHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get traktId => $composableBuilder(
      column: $table.traktId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imdbId => $composableBuilder(
      column: $table.imdbId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tmdbId => $composableBuilder(
      column: $table.tmdbId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get seasonNumber => $composableBuilder(
      column: $table.seasonNumber,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get episodeNumber => $composableBuilder(
      column: $table.episodeNumber,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get progress => $composableBuilder(
      column: $table.progress, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get watchedAt => $composableBuilder(
      column: $table.watchedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get pausedAt => $composableBuilder(
      column: $table.pausedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get runtime => $composableBuilder(
      column: $table.runtime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
      column: $table.lastSyncedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$WatchHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $WatchHistoryTable> {
  $$WatchHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get traktId =>
      $composableBuilder(column: $table.traktId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get imdbId =>
      $composableBuilder(column: $table.imdbId, builder: (column) => column);

  GeneratedColumn<String> get tmdbId =>
      $composableBuilder(column: $table.tmdbId, builder: (column) => column);

  GeneratedColumn<int> get seasonNumber => $composableBuilder(
      column: $table.seasonNumber, builder: (column) => column);

  GeneratedColumn<int> get episodeNumber => $composableBuilder(
      column: $table.episodeNumber, builder: (column) => column);

  GeneratedColumn<double> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<DateTime> get watchedAt =>
      $composableBuilder(column: $table.watchedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get pausedAt =>
      $composableBuilder(column: $table.pausedAt, builder: (column) => column);

  GeneratedColumn<int> get runtime =>
      $composableBuilder(column: $table.runtime, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
      column: $table.lastSyncedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$WatchHistoryTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WatchHistoryTable,
    WatchHistoryData,
    $$WatchHistoryTableFilterComposer,
    $$WatchHistoryTableOrderingComposer,
    $$WatchHistoryTableAnnotationComposer,
    $$WatchHistoryTableCreateCompanionBuilder,
    $$WatchHistoryTableUpdateCompanionBuilder,
    (
      WatchHistoryData,
      BaseReferences<_$AppDatabase, $WatchHistoryTable, WatchHistoryData>
    ),
    WatchHistoryData,
    PrefetchHooks Function()> {
  $$WatchHistoryTableTableManager(_$AppDatabase db, $WatchHistoryTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WatchHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WatchHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WatchHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> traktId = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> imdbId = const Value.absent(),
            Value<String?> tmdbId = const Value.absent(),
            Value<int?> seasonNumber = const Value.absent(),
            Value<int?> episodeNumber = const Value.absent(),
            Value<double> progress = const Value.absent(),
            Value<DateTime> watchedAt = const Value.absent(),
            Value<DateTime?> pausedAt = const Value.absent(),
            Value<int?> runtime = const Value.absent(),
            Value<DateTime> lastSyncedAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WatchHistoryCompanion(
            traktId: traktId,
            type: type,
            title: title,
            imdbId: imdbId,
            tmdbId: tmdbId,
            seasonNumber: seasonNumber,
            episodeNumber: episodeNumber,
            progress: progress,
            watchedAt: watchedAt,
            pausedAt: pausedAt,
            runtime: runtime,
            lastSyncedAt: lastSyncedAt,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String traktId,
            required String type,
            required String title,
            Value<String?> imdbId = const Value.absent(),
            Value<String?> tmdbId = const Value.absent(),
            Value<int?> seasonNumber = const Value.absent(),
            Value<int?> episodeNumber = const Value.absent(),
            required double progress,
            required DateTime watchedAt,
            Value<DateTime?> pausedAt = const Value.absent(),
            Value<int?> runtime = const Value.absent(),
            required DateTime lastSyncedAt,
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              WatchHistoryCompanion.insert(
            traktId: traktId,
            type: type,
            title: title,
            imdbId: imdbId,
            tmdbId: tmdbId,
            seasonNumber: seasonNumber,
            episodeNumber: episodeNumber,
            progress: progress,
            watchedAt: watchedAt,
            pausedAt: pausedAt,
            runtime: runtime,
            lastSyncedAt: lastSyncedAt,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WatchHistoryTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $WatchHistoryTable,
    WatchHistoryData,
    $$WatchHistoryTableFilterComposer,
    $$WatchHistoryTableOrderingComposer,
    $$WatchHistoryTableAnnotationComposer,
    $$WatchHistoryTableCreateCompanionBuilder,
    $$WatchHistoryTableUpdateCompanionBuilder,
    (
      WatchHistoryData,
      BaseReferences<_$AppDatabase, $WatchHistoryTable, WatchHistoryData>
    ),
    WatchHistoryData,
    PrefetchHooks Function()>;
typedef $$AppSettingsTableCreateCompanionBuilder = AppSettingsCompanion
    Function({
  required String key,
  required String value,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$AppSettingsTableUpdateCompanionBuilder = AppSettingsCompanion
    Function({
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
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
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
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
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

class $$AppSettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AppSettingsTable,
    AppSetting,
    $$AppSettingsTableFilterComposer,
    $$AppSettingsTableOrderingComposer,
    $$AppSettingsTableAnnotationComposer,
    $$AppSettingsTableCreateCompanionBuilder,
    $$AppSettingsTableUpdateCompanionBuilder,
    (AppSetting, BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>),
    AppSetting,
    PrefetchHooks Function()> {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppSettingsCompanion(
            key: key,
            value: value,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              AppSettingsCompanion.insert(
            key: key,
            value: value,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppSettingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AppSettingsTable,
    AppSetting,
    $$AppSettingsTableFilterComposer,
    $$AppSettingsTableOrderingComposer,
    $$AppSettingsTableAnnotationComposer,
    $$AppSettingsTableCreateCompanionBuilder,
    $$AppSettingsTableUpdateCompanionBuilder,
    (AppSetting, BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>),
    AppSetting,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AddonsTableTableManager get addons =>
      $$AddonsTableTableManager(_db, _db.addons);
  $$CatalogPreferencesTableTableManager get catalogPreferences =>
      $$CatalogPreferencesTableTableManager(_db, _db.catalogPreferences);
  $$TraktAuthTableTableManager get traktAuth =>
      $$TraktAuthTableTableManager(_db, _db.traktAuth);
  $$WatchHistoryTableTableManager get watchHistory =>
      $$WatchHistoryTableTableManager(_db, _db.watchHistory);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
}
