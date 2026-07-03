// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $MemesTableTable extends MemesTable
    with TableInfo<$MemesTableTable, Meme> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filenameMeta = const VerificationMeta(
    'filename',
  );
  @override
  late final GeneratedColumn<String> filename = GeneratedColumn<String>(
    'filename',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileSizeMeta = const VerificationMeta(
    'fileSize',
  );
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
    'file_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _analysisStatusMeta = const VerificationMeta(
    'analysisStatus',
  );
  @override
  late final GeneratedColumn<String> analysisStatus = GeneratedColumn<String>(
    'analysis_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _fileHashMeta = const VerificationMeta(
    'fileHash',
  );
  @override
  late final GeneratedColumn<String> fileHash = GeneratedColumn<String>(
    'file_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importedAtMeta = const VerificationMeta(
    'importedAt',
  );
  @override
  late final GeneratedColumn<int> importedAt = GeneratedColumn<int>(
    'imported_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _copyCountMeta = const VerificationMeta(
    'copyCount',
  );
  @override
  late final GeneratedColumn<int> copyCount = GeneratedColumn<int>(
    'copy_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    filename,
    filePath,
    fileSize,
    mimeType,
    width,
    height,
    folderId,
    analysisStatus,
    fileHash,
    description,
    createdAt,
    updatedAt,
    importedAt,
    copyCount,
    source,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memes_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<Meme> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('filename')) {
      context.handle(
        _filenameMeta,
        filename.isAcceptableOrUnknown(data['filename']!, _filenameMeta),
      );
    } else if (isInserting) {
      context.missing(_filenameMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('file_size')) {
      context.handle(
        _fileSizeMeta,
        fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta),
      );
    } else if (isInserting) {
      context.missing(_fileSizeMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeTypeMeta);
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    } else if (isInserting) {
      context.missing(_widthMeta);
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    } else if (isInserting) {
      context.missing(_heightMeta);
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    }
    if (data.containsKey('analysis_status')) {
      context.handle(
        _analysisStatusMeta,
        analysisStatus.isAcceptableOrUnknown(
          data['analysis_status']!,
          _analysisStatusMeta,
        ),
      );
    }
    if (data.containsKey('file_hash')) {
      context.handle(
        _fileHashMeta,
        fileHash.isAcceptableOrUnknown(data['file_hash']!, _fileHashMeta),
      );
    } else if (isInserting) {
      context.missing(_fileHashMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('imported_at')) {
      context.handle(
        _importedAtMeta,
        importedAt.isAcceptableOrUnknown(data['imported_at']!, _importedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_importedAtMeta);
    }
    if (data.containsKey('copy_count')) {
      context.handle(
        _copyCountMeta,
        copyCount.isAcceptableOrUnknown(data['copy_count']!, _copyCountMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Meme map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Meme(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      filename: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}filename'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      fileSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      )!,
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      )!,
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_id'],
      ),
      analysisStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}analysis_status'],
      )!,
      fileHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_hash'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      importedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}imported_at'],
      )!,
      copyCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}copy_count'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      ),
    );
  }

  @override
  $MemesTableTable createAlias(String alias) {
    return $MemesTableTable(attachedDatabase, alias);
  }
}

class Meme extends DataClass implements Insertable<Meme> {
  final String id;
  final String filename;
  final String filePath;
  final int fileSize;
  final String mimeType;
  final int width;
  final int height;
  final String? folderId;
  final String analysisStatus;
  final String fileHash;
  final String? description;
  final int createdAt;
  final int updatedAt;
  final int importedAt;

  /// 复制次数（用于排序和统计）
  final int copyCount;

  /// 图片来源：clipboard, wechat, album, bilibili, system_share, manual_import, drag_drop 等
  final String? source;
  const Meme({
    required this.id,
    required this.filename,
    required this.filePath,
    required this.fileSize,
    required this.mimeType,
    required this.width,
    required this.height,
    this.folderId,
    required this.analysisStatus,
    required this.fileHash,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    required this.importedAt,
    required this.copyCount,
    this.source,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['filename'] = Variable<String>(filename);
    map['file_path'] = Variable<String>(filePath);
    map['file_size'] = Variable<int>(fileSize);
    map['mime_type'] = Variable<String>(mimeType);
    map['width'] = Variable<int>(width);
    map['height'] = Variable<int>(height);
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<String>(folderId);
    }
    map['analysis_status'] = Variable<String>(analysisStatus);
    map['file_hash'] = Variable<String>(fileHash);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['imported_at'] = Variable<int>(importedAt);
    map['copy_count'] = Variable<int>(copyCount);
    if (!nullToAbsent || source != null) {
      map['source'] = Variable<String>(source);
    }
    return map;
  }

  MemesTableCompanion toCompanion(bool nullToAbsent) {
    return MemesTableCompanion(
      id: Value(id),
      filename: Value(filename),
      filePath: Value(filePath),
      fileSize: Value(fileSize),
      mimeType: Value(mimeType),
      width: Value(width),
      height: Value(height),
      folderId: folderId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderId),
      analysisStatus: Value(analysisStatus),
      fileHash: Value(fileHash),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      importedAt: Value(importedAt),
      copyCount: Value(copyCount),
      source: source == null && nullToAbsent
          ? const Value.absent()
          : Value(source),
    );
  }

  factory Meme.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Meme(
      id: serializer.fromJson<String>(json['id']),
      filename: serializer.fromJson<String>(json['filename']),
      filePath: serializer.fromJson<String>(json['filePath']),
      fileSize: serializer.fromJson<int>(json['fileSize']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      width: serializer.fromJson<int>(json['width']),
      height: serializer.fromJson<int>(json['height']),
      folderId: serializer.fromJson<String?>(json['folderId']),
      analysisStatus: serializer.fromJson<String>(json['analysisStatus']),
      fileHash: serializer.fromJson<String>(json['fileHash']),
      description: serializer.fromJson<String?>(json['description']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      importedAt: serializer.fromJson<int>(json['importedAt']),
      copyCount: serializer.fromJson<int>(json['copyCount']),
      source: serializer.fromJson<String?>(json['source']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'filename': serializer.toJson<String>(filename),
      'filePath': serializer.toJson<String>(filePath),
      'fileSize': serializer.toJson<int>(fileSize),
      'mimeType': serializer.toJson<String>(mimeType),
      'width': serializer.toJson<int>(width),
      'height': serializer.toJson<int>(height),
      'folderId': serializer.toJson<String?>(folderId),
      'analysisStatus': serializer.toJson<String>(analysisStatus),
      'fileHash': serializer.toJson<String>(fileHash),
      'description': serializer.toJson<String?>(description),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'importedAt': serializer.toJson<int>(importedAt),
      'copyCount': serializer.toJson<int>(copyCount),
      'source': serializer.toJson<String?>(source),
    };
  }

  Meme copyWith({
    String? id,
    String? filename,
    String? filePath,
    int? fileSize,
    String? mimeType,
    int? width,
    int? height,
    Value<String?> folderId = const Value.absent(),
    String? analysisStatus,
    String? fileHash,
    Value<String?> description = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    int? importedAt,
    int? copyCount,
    Value<String?> source = const Value.absent(),
  }) => Meme(
    id: id ?? this.id,
    filename: filename ?? this.filename,
    filePath: filePath ?? this.filePath,
    fileSize: fileSize ?? this.fileSize,
    mimeType: mimeType ?? this.mimeType,
    width: width ?? this.width,
    height: height ?? this.height,
    folderId: folderId.present ? folderId.value : this.folderId,
    analysisStatus: analysisStatus ?? this.analysisStatus,
    fileHash: fileHash ?? this.fileHash,
    description: description.present ? description.value : this.description,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    importedAt: importedAt ?? this.importedAt,
    copyCount: copyCount ?? this.copyCount,
    source: source.present ? source.value : this.source,
  );
  Meme copyWithCompanion(MemesTableCompanion data) {
    return Meme(
      id: data.id.present ? data.id.value : this.id,
      filename: data.filename.present ? data.filename.value : this.filename,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      analysisStatus: data.analysisStatus.present
          ? data.analysisStatus.value
          : this.analysisStatus,
      fileHash: data.fileHash.present ? data.fileHash.value : this.fileHash,
      description: data.description.present
          ? data.description.value
          : this.description,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      importedAt: data.importedAt.present
          ? data.importedAt.value
          : this.importedAt,
      copyCount: data.copyCount.present ? data.copyCount.value : this.copyCount,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Meme(')
          ..write('id: $id, ')
          ..write('filename: $filename, ')
          ..write('filePath: $filePath, ')
          ..write('fileSize: $fileSize, ')
          ..write('mimeType: $mimeType, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('folderId: $folderId, ')
          ..write('analysisStatus: $analysisStatus, ')
          ..write('fileHash: $fileHash, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('importedAt: $importedAt, ')
          ..write('copyCount: $copyCount, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    filename,
    filePath,
    fileSize,
    mimeType,
    width,
    height,
    folderId,
    analysisStatus,
    fileHash,
    description,
    createdAt,
    updatedAt,
    importedAt,
    copyCount,
    source,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Meme &&
          other.id == this.id &&
          other.filename == this.filename &&
          other.filePath == this.filePath &&
          other.fileSize == this.fileSize &&
          other.mimeType == this.mimeType &&
          other.width == this.width &&
          other.height == this.height &&
          other.folderId == this.folderId &&
          other.analysisStatus == this.analysisStatus &&
          other.fileHash == this.fileHash &&
          other.description == this.description &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.importedAt == this.importedAt &&
          other.copyCount == this.copyCount &&
          other.source == this.source);
}

class MemesTableCompanion extends UpdateCompanion<Meme> {
  final Value<String> id;
  final Value<String> filename;
  final Value<String> filePath;
  final Value<int> fileSize;
  final Value<String> mimeType;
  final Value<int> width;
  final Value<int> height;
  final Value<String?> folderId;
  final Value<String> analysisStatus;
  final Value<String> fileHash;
  final Value<String?> description;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> importedAt;
  final Value<int> copyCount;
  final Value<String?> source;
  final Value<int> rowid;
  const MemesTableCompanion({
    this.id = const Value.absent(),
    this.filename = const Value.absent(),
    this.filePath = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.folderId = const Value.absent(),
    this.analysisStatus = const Value.absent(),
    this.fileHash = const Value.absent(),
    this.description = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.importedAt = const Value.absent(),
    this.copyCount = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemesTableCompanion.insert({
    required String id,
    required String filename,
    required String filePath,
    required int fileSize,
    required String mimeType,
    required int width,
    required int height,
    this.folderId = const Value.absent(),
    this.analysisStatus = const Value.absent(),
    required String fileHash,
    this.description = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    required int importedAt,
    this.copyCount = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       filename = Value(filename),
       filePath = Value(filePath),
       fileSize = Value(fileSize),
       mimeType = Value(mimeType),
       width = Value(width),
       height = Value(height),
       fileHash = Value(fileHash),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       importedAt = Value(importedAt);
  static Insertable<Meme> custom({
    Expression<String>? id,
    Expression<String>? filename,
    Expression<String>? filePath,
    Expression<int>? fileSize,
    Expression<String>? mimeType,
    Expression<int>? width,
    Expression<int>? height,
    Expression<String>? folderId,
    Expression<String>? analysisStatus,
    Expression<String>? fileHash,
    Expression<String>? description,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? importedAt,
    Expression<int>? copyCount,
    Expression<String>? source,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (filename != null) 'filename': filename,
      if (filePath != null) 'file_path': filePath,
      if (fileSize != null) 'file_size': fileSize,
      if (mimeType != null) 'mime_type': mimeType,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (folderId != null) 'folder_id': folderId,
      if (analysisStatus != null) 'analysis_status': analysisStatus,
      if (fileHash != null) 'file_hash': fileHash,
      if (description != null) 'description': description,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (importedAt != null) 'imported_at': importedAt,
      if (copyCount != null) 'copy_count': copyCount,
      if (source != null) 'source': source,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemesTableCompanion copyWith({
    Value<String>? id,
    Value<String>? filename,
    Value<String>? filePath,
    Value<int>? fileSize,
    Value<String>? mimeType,
    Value<int>? width,
    Value<int>? height,
    Value<String?>? folderId,
    Value<String>? analysisStatus,
    Value<String>? fileHash,
    Value<String?>? description,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? importedAt,
    Value<int>? copyCount,
    Value<String?>? source,
    Value<int>? rowid,
  }) {
    return MemesTableCompanion(
      id: id ?? this.id,
      filename: filename ?? this.filename,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      width: width ?? this.width,
      height: height ?? this.height,
      folderId: folderId ?? this.folderId,
      analysisStatus: analysisStatus ?? this.analysisStatus,
      fileHash: fileHash ?? this.fileHash,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      importedAt: importedAt ?? this.importedAt,
      copyCount: copyCount ?? this.copyCount,
      source: source ?? this.source,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (filename.present) {
      map['filename'] = Variable<String>(filename.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (analysisStatus.present) {
      map['analysis_status'] = Variable<String>(analysisStatus.value);
    }
    if (fileHash.present) {
      map['file_hash'] = Variable<String>(fileHash.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (importedAt.present) {
      map['imported_at'] = Variable<int>(importedAt.value);
    }
    if (copyCount.present) {
      map['copy_count'] = Variable<int>(copyCount.value);
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
    return (StringBuffer('MemesTableCompanion(')
          ..write('id: $id, ')
          ..write('filename: $filename, ')
          ..write('filePath: $filePath, ')
          ..write('fileSize: $fileSize, ')
          ..write('mimeType: $mimeType, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('folderId: $folderId, ')
          ..write('analysisStatus: $analysisStatus, ')
          ..write('fileHash: $fileHash, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('importedAt: $importedAt, ')
          ..write('copyCount: $copyCount, ')
          ..write('source: $source, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TagsTableTable extends TagsTable
    with TableInfo<$TagsTableTable, TagEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _memeIdMeta = const VerificationMeta('memeId');
  @override
  late final GeneratedColumn<String> memeId = GeneratedColumn<String>(
    'meme_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES memes_table (id)',
    ),
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
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    memeId,
    source,
    content,
    confidence,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<TagEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('meme_id')) {
      context.handle(
        _memeIdMeta,
        memeId.isAcceptableOrUnknown(data['meme_id']!, _memeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_memeIdMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TagEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TagEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      memeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meme_id'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      )!,
    );
  }

  @override
  $TagsTableTable createAlias(String alias) {
    return $TagsTableTable(attachedDatabase, alias);
  }
}

class TagEntry extends DataClass implements Insertable<TagEntry> {
  final String id;
  final String memeId;
  final String source;
  final String content;
  final double confidence;
  const TagEntry({
    required this.id,
    required this.memeId,
    required this.source,
    required this.content,
    required this.confidence,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['meme_id'] = Variable<String>(memeId);
    map['source'] = Variable<String>(source);
    map['content'] = Variable<String>(content);
    map['confidence'] = Variable<double>(confidence);
    return map;
  }

  TagsTableCompanion toCompanion(bool nullToAbsent) {
    return TagsTableCompanion(
      id: Value(id),
      memeId: Value(memeId),
      source: Value(source),
      content: Value(content),
      confidence: Value(confidence),
    );
  }

  factory TagEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TagEntry(
      id: serializer.fromJson<String>(json['id']),
      memeId: serializer.fromJson<String>(json['memeId']),
      source: serializer.fromJson<String>(json['source']),
      content: serializer.fromJson<String>(json['content']),
      confidence: serializer.fromJson<double>(json['confidence']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'memeId': serializer.toJson<String>(memeId),
      'source': serializer.toJson<String>(source),
      'content': serializer.toJson<String>(content),
      'confidence': serializer.toJson<double>(confidence),
    };
  }

  TagEntry copyWith({
    String? id,
    String? memeId,
    String? source,
    String? content,
    double? confidence,
  }) => TagEntry(
    id: id ?? this.id,
    memeId: memeId ?? this.memeId,
    source: source ?? this.source,
    content: content ?? this.content,
    confidence: confidence ?? this.confidence,
  );
  TagEntry copyWithCompanion(TagsTableCompanion data) {
    return TagEntry(
      id: data.id.present ? data.id.value : this.id,
      memeId: data.memeId.present ? data.memeId.value : this.memeId,
      source: data.source.present ? data.source.value : this.source,
      content: data.content.present ? data.content.value : this.content,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TagEntry(')
          ..write('id: $id, ')
          ..write('memeId: $memeId, ')
          ..write('source: $source, ')
          ..write('content: $content, ')
          ..write('confidence: $confidence')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, memeId, source, content, confidence);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TagEntry &&
          other.id == this.id &&
          other.memeId == this.memeId &&
          other.source == this.source &&
          other.content == this.content &&
          other.confidence == this.confidence);
}

class TagsTableCompanion extends UpdateCompanion<TagEntry> {
  final Value<String> id;
  final Value<String> memeId;
  final Value<String> source;
  final Value<String> content;
  final Value<double> confidence;
  final Value<int> rowid;
  const TagsTableCompanion({
    this.id = const Value.absent(),
    this.memeId = const Value.absent(),
    this.source = const Value.absent(),
    this.content = const Value.absent(),
    this.confidence = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagsTableCompanion.insert({
    required String id,
    required String memeId,
    required String source,
    required String content,
    this.confidence = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       memeId = Value(memeId),
       source = Value(source),
       content = Value(content);
  static Insertable<TagEntry> custom({
    Expression<String>? id,
    Expression<String>? memeId,
    Expression<String>? source,
    Expression<String>? content,
    Expression<double>? confidence,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (memeId != null) 'meme_id': memeId,
      if (source != null) 'source': source,
      if (content != null) 'content': content,
      if (confidence != null) 'confidence': confidence,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? memeId,
    Value<String>? source,
    Value<String>? content,
    Value<double>? confidence,
    Value<int>? rowid,
  }) {
    return TagsTableCompanion(
      id: id ?? this.id,
      memeId: memeId ?? this.memeId,
      source: source ?? this.source,
      content: content ?? this.content,
      confidence: confidence ?? this.confidence,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (memeId.present) {
      map['meme_id'] = Variable<String>(memeId.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsTableCompanion(')
          ..write('id: $id, ')
          ..write('memeId: $memeId, ')
          ..write('source: $source, ')
          ..write('content: $content, ')
          ..write('confidence: $confidence, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ColorsTableTable extends ColorsTable
    with TableInfo<$ColorsTableTable, ColorEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ColorsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _memeIdMeta = const VerificationMeta('memeId');
  @override
  late final GeneratedColumn<String> memeId = GeneratedColumn<String>(
    'meme_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES memes_table (id)',
    ),
  );
  static const VerificationMeta _hexColorMeta = const VerificationMeta(
    'hexColor',
  );
  @override
  late final GeneratedColumn<String> hexColor = GeneratedColumn<String>(
    'hex_color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labLMeta = const VerificationMeta('labL');
  @override
  late final GeneratedColumn<double> labL = GeneratedColumn<double>(
    'lab_l',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labAMeta = const VerificationMeta('labA');
  @override
  late final GeneratedColumn<double> labA = GeneratedColumn<double>(
    'lab_a',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labBMeta = const VerificationMeta('labB');
  @override
  late final GeneratedColumn<double> labB = GeneratedColumn<double>(
    'lab_b',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ratioMeta = const VerificationMeta('ratio');
  @override
  late final GeneratedColumn<double> ratio = GeneratedColumn<double>(
    'ratio',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    memeId,
    hexColor,
    labL,
    labA,
    labB,
    ratio,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'colors_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<ColorEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('meme_id')) {
      context.handle(
        _memeIdMeta,
        memeId.isAcceptableOrUnknown(data['meme_id']!, _memeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_memeIdMeta);
    }
    if (data.containsKey('hex_color')) {
      context.handle(
        _hexColorMeta,
        hexColor.isAcceptableOrUnknown(data['hex_color']!, _hexColorMeta),
      );
    } else if (isInserting) {
      context.missing(_hexColorMeta);
    }
    if (data.containsKey('lab_l')) {
      context.handle(
        _labLMeta,
        labL.isAcceptableOrUnknown(data['lab_l']!, _labLMeta),
      );
    } else if (isInserting) {
      context.missing(_labLMeta);
    }
    if (data.containsKey('lab_a')) {
      context.handle(
        _labAMeta,
        labA.isAcceptableOrUnknown(data['lab_a']!, _labAMeta),
      );
    } else if (isInserting) {
      context.missing(_labAMeta);
    }
    if (data.containsKey('lab_b')) {
      context.handle(
        _labBMeta,
        labB.isAcceptableOrUnknown(data['lab_b']!, _labBMeta),
      );
    } else if (isInserting) {
      context.missing(_labBMeta);
    }
    if (data.containsKey('ratio')) {
      context.handle(
        _ratioMeta,
        ratio.isAcceptableOrUnknown(data['ratio']!, _ratioMeta),
      );
    } else if (isInserting) {
      context.missing(_ratioMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ColorEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ColorEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      memeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meme_id'],
      )!,
      hexColor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hex_color'],
      )!,
      labL: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lab_l'],
      )!,
      labA: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lab_a'],
      )!,
      labB: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lab_b'],
      )!,
      ratio: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ratio'],
      )!,
    );
  }

  @override
  $ColorsTableTable createAlias(String alias) {
    return $ColorsTableTable(attachedDatabase, alias);
  }
}

class ColorEntry extends DataClass implements Insertable<ColorEntry> {
  final String id;
  final String memeId;
  final String hexColor;
  final double labL;
  final double labA;
  final double labB;
  final double ratio;
  const ColorEntry({
    required this.id,
    required this.memeId,
    required this.hexColor,
    required this.labL,
    required this.labA,
    required this.labB,
    required this.ratio,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['meme_id'] = Variable<String>(memeId);
    map['hex_color'] = Variable<String>(hexColor);
    map['lab_l'] = Variable<double>(labL);
    map['lab_a'] = Variable<double>(labA);
    map['lab_b'] = Variable<double>(labB);
    map['ratio'] = Variable<double>(ratio);
    return map;
  }

  ColorsTableCompanion toCompanion(bool nullToAbsent) {
    return ColorsTableCompanion(
      id: Value(id),
      memeId: Value(memeId),
      hexColor: Value(hexColor),
      labL: Value(labL),
      labA: Value(labA),
      labB: Value(labB),
      ratio: Value(ratio),
    );
  }

  factory ColorEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ColorEntry(
      id: serializer.fromJson<String>(json['id']),
      memeId: serializer.fromJson<String>(json['memeId']),
      hexColor: serializer.fromJson<String>(json['hexColor']),
      labL: serializer.fromJson<double>(json['labL']),
      labA: serializer.fromJson<double>(json['labA']),
      labB: serializer.fromJson<double>(json['labB']),
      ratio: serializer.fromJson<double>(json['ratio']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'memeId': serializer.toJson<String>(memeId),
      'hexColor': serializer.toJson<String>(hexColor),
      'labL': serializer.toJson<double>(labL),
      'labA': serializer.toJson<double>(labA),
      'labB': serializer.toJson<double>(labB),
      'ratio': serializer.toJson<double>(ratio),
    };
  }

  ColorEntry copyWith({
    String? id,
    String? memeId,
    String? hexColor,
    double? labL,
    double? labA,
    double? labB,
    double? ratio,
  }) => ColorEntry(
    id: id ?? this.id,
    memeId: memeId ?? this.memeId,
    hexColor: hexColor ?? this.hexColor,
    labL: labL ?? this.labL,
    labA: labA ?? this.labA,
    labB: labB ?? this.labB,
    ratio: ratio ?? this.ratio,
  );
  ColorEntry copyWithCompanion(ColorsTableCompanion data) {
    return ColorEntry(
      id: data.id.present ? data.id.value : this.id,
      memeId: data.memeId.present ? data.memeId.value : this.memeId,
      hexColor: data.hexColor.present ? data.hexColor.value : this.hexColor,
      labL: data.labL.present ? data.labL.value : this.labL,
      labA: data.labA.present ? data.labA.value : this.labA,
      labB: data.labB.present ? data.labB.value : this.labB,
      ratio: data.ratio.present ? data.ratio.value : this.ratio,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ColorEntry(')
          ..write('id: $id, ')
          ..write('memeId: $memeId, ')
          ..write('hexColor: $hexColor, ')
          ..write('labL: $labL, ')
          ..write('labA: $labA, ')
          ..write('labB: $labB, ')
          ..write('ratio: $ratio')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, memeId, hexColor, labL, labA, labB, ratio);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ColorEntry &&
          other.id == this.id &&
          other.memeId == this.memeId &&
          other.hexColor == this.hexColor &&
          other.labL == this.labL &&
          other.labA == this.labA &&
          other.labB == this.labB &&
          other.ratio == this.ratio);
}

class ColorsTableCompanion extends UpdateCompanion<ColorEntry> {
  final Value<String> id;
  final Value<String> memeId;
  final Value<String> hexColor;
  final Value<double> labL;
  final Value<double> labA;
  final Value<double> labB;
  final Value<double> ratio;
  final Value<int> rowid;
  const ColorsTableCompanion({
    this.id = const Value.absent(),
    this.memeId = const Value.absent(),
    this.hexColor = const Value.absent(),
    this.labL = const Value.absent(),
    this.labA = const Value.absent(),
    this.labB = const Value.absent(),
    this.ratio = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ColorsTableCompanion.insert({
    required String id,
    required String memeId,
    required String hexColor,
    required double labL,
    required double labA,
    required double labB,
    required double ratio,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       memeId = Value(memeId),
       hexColor = Value(hexColor),
       labL = Value(labL),
       labA = Value(labA),
       labB = Value(labB),
       ratio = Value(ratio);
  static Insertable<ColorEntry> custom({
    Expression<String>? id,
    Expression<String>? memeId,
    Expression<String>? hexColor,
    Expression<double>? labL,
    Expression<double>? labA,
    Expression<double>? labB,
    Expression<double>? ratio,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (memeId != null) 'meme_id': memeId,
      if (hexColor != null) 'hex_color': hexColor,
      if (labL != null) 'lab_l': labL,
      if (labA != null) 'lab_a': labA,
      if (labB != null) 'lab_b': labB,
      if (ratio != null) 'ratio': ratio,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ColorsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? memeId,
    Value<String>? hexColor,
    Value<double>? labL,
    Value<double>? labA,
    Value<double>? labB,
    Value<double>? ratio,
    Value<int>? rowid,
  }) {
    return ColorsTableCompanion(
      id: id ?? this.id,
      memeId: memeId ?? this.memeId,
      hexColor: hexColor ?? this.hexColor,
      labL: labL ?? this.labL,
      labA: labA ?? this.labA,
      labB: labB ?? this.labB,
      ratio: ratio ?? this.ratio,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (memeId.present) {
      map['meme_id'] = Variable<String>(memeId.value);
    }
    if (hexColor.present) {
      map['hex_color'] = Variable<String>(hexColor.value);
    }
    if (labL.present) {
      map['lab_l'] = Variable<double>(labL.value);
    }
    if (labA.present) {
      map['lab_a'] = Variable<double>(labA.value);
    }
    if (labB.present) {
      map['lab_b'] = Variable<double>(labB.value);
    }
    if (ratio.present) {
      map['ratio'] = Variable<double>(ratio.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ColorsTableCompanion(')
          ..write('id: $id, ')
          ..write('memeId: $memeId, ')
          ..write('hexColor: $hexColor, ')
          ..write('labL: $labL, ')
          ..write('labA: $labA, ')
          ..write('labB: $labB, ')
          ..write('ratio: $ratio, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EmbeddingsTableTable extends EmbeddingsTable
    with TableInfo<$EmbeddingsTableTable, EmbeddingEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EmbeddingsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _memeIdMeta = const VerificationMeta('memeId');
  @override
  late final GeneratedColumn<String> memeId = GeneratedColumn<String>(
    'meme_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vectorMeta = const VerificationMeta('vector');
  @override
  late final GeneratedColumn<Uint8List> vector = GeneratedColumn<Uint8List>(
    'vector',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelIdMeta = const VerificationMeta(
    'modelId',
  );
  @override
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
    'model_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [memeId, vector, modelId, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'embeddings_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<EmbeddingEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('meme_id')) {
      context.handle(
        _memeIdMeta,
        memeId.isAcceptableOrUnknown(data['meme_id']!, _memeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_memeIdMeta);
    }
    if (data.containsKey('vector')) {
      context.handle(
        _vectorMeta,
        vector.isAcceptableOrUnknown(data['vector']!, _vectorMeta),
      );
    } else if (isInserting) {
      context.missing(_vectorMeta);
    }
    if (data.containsKey('model_id')) {
      context.handle(
        _modelIdMeta,
        modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_modelIdMeta);
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
  Set<GeneratedColumn> get $primaryKey => {memeId};
  @override
  EmbeddingEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EmbeddingEntry(
      memeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meme_id'],
      )!,
      vector: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}vector'],
      )!,
      modelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $EmbeddingsTableTable createAlias(String alias) {
    return $EmbeddingsTableTable(attachedDatabase, alias);
  }
}

class EmbeddingEntry extends DataClass implements Insertable<EmbeddingEntry> {
  final String memeId;
  final Uint8List vector;
  final String modelId;
  final int updatedAt;
  const EmbeddingEntry({
    required this.memeId,
    required this.vector,
    required this.modelId,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['meme_id'] = Variable<String>(memeId);
    map['vector'] = Variable<Uint8List>(vector);
    map['model_id'] = Variable<String>(modelId);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  EmbeddingsTableCompanion toCompanion(bool nullToAbsent) {
    return EmbeddingsTableCompanion(
      memeId: Value(memeId),
      vector: Value(vector),
      modelId: Value(modelId),
      updatedAt: Value(updatedAt),
    );
  }

  factory EmbeddingEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EmbeddingEntry(
      memeId: serializer.fromJson<String>(json['memeId']),
      vector: serializer.fromJson<Uint8List>(json['vector']),
      modelId: serializer.fromJson<String>(json['modelId']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'memeId': serializer.toJson<String>(memeId),
      'vector': serializer.toJson<Uint8List>(vector),
      'modelId': serializer.toJson<String>(modelId),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  EmbeddingEntry copyWith({
    String? memeId,
    Uint8List? vector,
    String? modelId,
    int? updatedAt,
  }) => EmbeddingEntry(
    memeId: memeId ?? this.memeId,
    vector: vector ?? this.vector,
    modelId: modelId ?? this.modelId,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  EmbeddingEntry copyWithCompanion(EmbeddingsTableCompanion data) {
    return EmbeddingEntry(
      memeId: data.memeId.present ? data.memeId.value : this.memeId,
      vector: data.vector.present ? data.vector.value : this.vector,
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EmbeddingEntry(')
          ..write('memeId: $memeId, ')
          ..write('vector: $vector, ')
          ..write('modelId: $modelId, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(memeId, $driftBlobEquality.hash(vector), modelId, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EmbeddingEntry &&
          other.memeId == this.memeId &&
          $driftBlobEquality.equals(other.vector, this.vector) &&
          other.modelId == this.modelId &&
          other.updatedAt == this.updatedAt);
}

class EmbeddingsTableCompanion extends UpdateCompanion<EmbeddingEntry> {
  final Value<String> memeId;
  final Value<Uint8List> vector;
  final Value<String> modelId;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const EmbeddingsTableCompanion({
    this.memeId = const Value.absent(),
    this.vector = const Value.absent(),
    this.modelId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EmbeddingsTableCompanion.insert({
    required String memeId,
    required Uint8List vector,
    required String modelId,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : memeId = Value(memeId),
       vector = Value(vector),
       modelId = Value(modelId),
       updatedAt = Value(updatedAt);
  static Insertable<EmbeddingEntry> custom({
    Expression<String>? memeId,
    Expression<Uint8List>? vector,
    Expression<String>? modelId,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (memeId != null) 'meme_id': memeId,
      if (vector != null) 'vector': vector,
      if (modelId != null) 'model_id': modelId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EmbeddingsTableCompanion copyWith({
    Value<String>? memeId,
    Value<Uint8List>? vector,
    Value<String>? modelId,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return EmbeddingsTableCompanion(
      memeId: memeId ?? this.memeId,
      vector: vector ?? this.vector,
      modelId: modelId ?? this.modelId,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (memeId.present) {
      map['meme_id'] = Variable<String>(memeId.value);
    }
    if (vector.present) {
      map['vector'] = Variable<Uint8List>(vector.value);
    }
    if (modelId.present) {
      map['model_id'] = Variable<String>(modelId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EmbeddingsTableCompanion(')
          ..write('memeId: $memeId, ')
          ..write('vector: $vector, ')
          ..write('modelId: $modelId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AnalysisQueueTableTable extends AnalysisQueueTable
    with TableInfo<$AnalysisQueueTableTable, AnalysisQueueItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnalysisQueueTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _memeIdMeta = const VerificationMeta('memeId');
  @override
  late final GeneratedColumn<String> memeId = GeneratedColumn<String>(
    'meme_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES memes_table (id)',
    ),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('queued'),
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
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _errorMsgMeta = const VerificationMeta(
    'errorMsg',
  );
  @override
  late final GeneratedColumn<String> errorMsg = GeneratedColumn<String>(
    'error_msg',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<int> startedAt = GeneratedColumn<int>(
    'started_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _doneAtMeta = const VerificationMeta('doneAt');
  @override
  late final GeneratedColumn<int> doneAt = GeneratedColumn<int>(
    'done_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    memeId,
    status,
    priority,
    retryCount,
    errorMsg,
    createdAt,
    startedAt,
    doneAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'analysis_queue_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<AnalysisQueueItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('meme_id')) {
      context.handle(
        _memeIdMeta,
        memeId.isAcceptableOrUnknown(data['meme_id']!, _memeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_memeIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('error_msg')) {
      context.handle(
        _errorMsgMeta,
        errorMsg.isAcceptableOrUnknown(data['error_msg']!, _errorMsgMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('done_at')) {
      context.handle(
        _doneAtMeta,
        doneAt.isAcceptableOrUnknown(data['done_at']!, _doneAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AnalysisQueueItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AnalysisQueueItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      memeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meme_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      errorMsg: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_msg'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at'],
      ),
      doneAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}done_at'],
      ),
    );
  }

  @override
  $AnalysisQueueTableTable createAlias(String alias) {
    return $AnalysisQueueTableTable(attachedDatabase, alias);
  }
}

class AnalysisQueueItem extends DataClass
    implements Insertable<AnalysisQueueItem> {
  final String id;
  final String memeId;
  final String status;
  final int priority;
  final int retryCount;
  final String? errorMsg;
  final int createdAt;
  final int? startedAt;
  final int? doneAt;
  const AnalysisQueueItem({
    required this.id,
    required this.memeId,
    required this.status,
    required this.priority,
    required this.retryCount,
    this.errorMsg,
    required this.createdAt,
    this.startedAt,
    this.doneAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['meme_id'] = Variable<String>(memeId);
    map['status'] = Variable<String>(status);
    map['priority'] = Variable<int>(priority);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || errorMsg != null) {
      map['error_msg'] = Variable<String>(errorMsg);
    }
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<int>(startedAt);
    }
    if (!nullToAbsent || doneAt != null) {
      map['done_at'] = Variable<int>(doneAt);
    }
    return map;
  }

  AnalysisQueueTableCompanion toCompanion(bool nullToAbsent) {
    return AnalysisQueueTableCompanion(
      id: Value(id),
      memeId: Value(memeId),
      status: Value(status),
      priority: Value(priority),
      retryCount: Value(retryCount),
      errorMsg: errorMsg == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMsg),
      createdAt: Value(createdAt),
      startedAt: startedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAt),
      doneAt: doneAt == null && nullToAbsent
          ? const Value.absent()
          : Value(doneAt),
    );
  }

  factory AnalysisQueueItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AnalysisQueueItem(
      id: serializer.fromJson<String>(json['id']),
      memeId: serializer.fromJson<String>(json['memeId']),
      status: serializer.fromJson<String>(json['status']),
      priority: serializer.fromJson<int>(json['priority']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      errorMsg: serializer.fromJson<String?>(json['errorMsg']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      startedAt: serializer.fromJson<int?>(json['startedAt']),
      doneAt: serializer.fromJson<int?>(json['doneAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'memeId': serializer.toJson<String>(memeId),
      'status': serializer.toJson<String>(status),
      'priority': serializer.toJson<int>(priority),
      'retryCount': serializer.toJson<int>(retryCount),
      'errorMsg': serializer.toJson<String?>(errorMsg),
      'createdAt': serializer.toJson<int>(createdAt),
      'startedAt': serializer.toJson<int?>(startedAt),
      'doneAt': serializer.toJson<int?>(doneAt),
    };
  }

  AnalysisQueueItem copyWith({
    String? id,
    String? memeId,
    String? status,
    int? priority,
    int? retryCount,
    Value<String?> errorMsg = const Value.absent(),
    int? createdAt,
    Value<int?> startedAt = const Value.absent(),
    Value<int?> doneAt = const Value.absent(),
  }) => AnalysisQueueItem(
    id: id ?? this.id,
    memeId: memeId ?? this.memeId,
    status: status ?? this.status,
    priority: priority ?? this.priority,
    retryCount: retryCount ?? this.retryCount,
    errorMsg: errorMsg.present ? errorMsg.value : this.errorMsg,
    createdAt: createdAt ?? this.createdAt,
    startedAt: startedAt.present ? startedAt.value : this.startedAt,
    doneAt: doneAt.present ? doneAt.value : this.doneAt,
  );
  AnalysisQueueItem copyWithCompanion(AnalysisQueueTableCompanion data) {
    return AnalysisQueueItem(
      id: data.id.present ? data.id.value : this.id,
      memeId: data.memeId.present ? data.memeId.value : this.memeId,
      status: data.status.present ? data.status.value : this.status,
      priority: data.priority.present ? data.priority.value : this.priority,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      errorMsg: data.errorMsg.present ? data.errorMsg.value : this.errorMsg,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      doneAt: data.doneAt.present ? data.doneAt.value : this.doneAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AnalysisQueueItem(')
          ..write('id: $id, ')
          ..write('memeId: $memeId, ')
          ..write('status: $status, ')
          ..write('priority: $priority, ')
          ..write('retryCount: $retryCount, ')
          ..write('errorMsg: $errorMsg, ')
          ..write('createdAt: $createdAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('doneAt: $doneAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    memeId,
    status,
    priority,
    retryCount,
    errorMsg,
    createdAt,
    startedAt,
    doneAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnalysisQueueItem &&
          other.id == this.id &&
          other.memeId == this.memeId &&
          other.status == this.status &&
          other.priority == this.priority &&
          other.retryCount == this.retryCount &&
          other.errorMsg == this.errorMsg &&
          other.createdAt == this.createdAt &&
          other.startedAt == this.startedAt &&
          other.doneAt == this.doneAt);
}

class AnalysisQueueTableCompanion extends UpdateCompanion<AnalysisQueueItem> {
  final Value<String> id;
  final Value<String> memeId;
  final Value<String> status;
  final Value<int> priority;
  final Value<int> retryCount;
  final Value<String?> errorMsg;
  final Value<int> createdAt;
  final Value<int?> startedAt;
  final Value<int?> doneAt;
  final Value<int> rowid;
  const AnalysisQueueTableCompanion({
    this.id = const Value.absent(),
    this.memeId = const Value.absent(),
    this.status = const Value.absent(),
    this.priority = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.errorMsg = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.doneAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AnalysisQueueTableCompanion.insert({
    required String id,
    required String memeId,
    this.status = const Value.absent(),
    this.priority = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.errorMsg = const Value.absent(),
    required int createdAt,
    this.startedAt = const Value.absent(),
    this.doneAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       memeId = Value(memeId),
       createdAt = Value(createdAt);
  static Insertable<AnalysisQueueItem> custom({
    Expression<String>? id,
    Expression<String>? memeId,
    Expression<String>? status,
    Expression<int>? priority,
    Expression<int>? retryCount,
    Expression<String>? errorMsg,
    Expression<int>? createdAt,
    Expression<int>? startedAt,
    Expression<int>? doneAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (memeId != null) 'meme_id': memeId,
      if (status != null) 'status': status,
      if (priority != null) 'priority': priority,
      if (retryCount != null) 'retry_count': retryCount,
      if (errorMsg != null) 'error_msg': errorMsg,
      if (createdAt != null) 'created_at': createdAt,
      if (startedAt != null) 'started_at': startedAt,
      if (doneAt != null) 'done_at': doneAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AnalysisQueueTableCompanion copyWith({
    Value<String>? id,
    Value<String>? memeId,
    Value<String>? status,
    Value<int>? priority,
    Value<int>? retryCount,
    Value<String?>? errorMsg,
    Value<int>? createdAt,
    Value<int?>? startedAt,
    Value<int?>? doneAt,
    Value<int>? rowid,
  }) {
    return AnalysisQueueTableCompanion(
      id: id ?? this.id,
      memeId: memeId ?? this.memeId,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      retryCount: retryCount ?? this.retryCount,
      errorMsg: errorMsg ?? this.errorMsg,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      doneAt: doneAt ?? this.doneAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (memeId.present) {
      map['meme_id'] = Variable<String>(memeId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (errorMsg.present) {
      map['error_msg'] = Variable<String>(errorMsg.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<int>(startedAt.value);
    }
    if (doneAt.present) {
      map['done_at'] = Variable<int>(doneAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnalysisQueueTableCompanion(')
          ..write('id: $id, ')
          ..write('memeId: $memeId, ')
          ..write('status: $status, ')
          ..write('priority: $priority, ')
          ..write('retryCount: $retryCount, ')
          ..write('errorMsg: $errorMsg, ')
          ..write('createdAt: $createdAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('doneAt: $doneAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStateTableTable extends SyncStateTable
    with TableInfo<$SyncStateTableTable, SyncStateEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncStateEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SyncStateTableTable createAlias(String alias) {
    return $SyncStateTableTable(attachedDatabase, alias);
  }
}

class SyncStateEntry extends DataClass implements Insertable<SyncStateEntry> {
  final String id;
  final String value;
  final int updatedAt;
  const SyncStateEntry({
    required this.id,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  SyncStateTableCompanion toCompanion(bool nullToAbsent) {
    return SyncStateTableCompanion(
      id: Value(id),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory SyncStateEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateEntry(
      id: serializer.fromJson<String>(json['id']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  SyncStateEntry copyWith({String? id, String? value, int? updatedAt}) =>
      SyncStateEntry(
        id: id ?? this.id,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  SyncStateEntry copyWithCompanion(SyncStateTableCompanion data) {
    return SyncStateEntry(
      id: data.id.present ? data.id.value : this.id,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateEntry(')
          ..write('id: $id, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateEntry &&
          other.id == this.id &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class SyncStateTableCompanion extends UpdateCompanion<SyncStateEntry> {
  final Value<String> id;
  final Value<String> value;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const SyncStateTableCompanion({
    this.id = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStateTableCompanion.insert({
    required String id,
    required String value,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       value = Value(value),
       updatedAt = Value(updatedAt);
  static Insertable<SyncStateEntry> custom({
    Expression<String>? id,
    Expression<String>? value,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStateTableCompanion copyWith({
    Value<String>? id,
    Value<String>? value,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return SyncStateTableCompanion(
      id: id ?? this.id,
      value: value ?? this.value,
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
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateTableCompanion(')
          ..write('id: $id, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AlbumsTableTable extends AlbumsTable
    with TableInfo<$AlbumsTableTable, Album> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AlbumsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<int> isDefault = GeneratedColumn<int>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    icon,
    sortOrder,
    isDefault,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'albums_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<Album> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Album map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Album(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}is_default'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AlbumsTableTable createAlias(String alias) {
    return $AlbumsTableTable(attachedDatabase, alias);
  }
}

class Album extends DataClass implements Insertable<Album> {
  final String id;
  final String name;
  final String? icon;
  final int sortOrder;
  final int isDefault;
  final int createdAt;
  const Album({
    required this.id,
    required this.name,
    this.icon,
    required this.sortOrder,
    required this.isDefault,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(icon);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['is_default'] = Variable<int>(isDefault);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  AlbumsTableCompanion toCompanion(bool nullToAbsent) {
    return AlbumsTableCompanion(
      id: Value(id),
      name: Value(name),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
      sortOrder: Value(sortOrder),
      isDefault: Value(isDefault),
      createdAt: Value(createdAt),
    );
  }

  factory Album.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Album(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      icon: serializer.fromJson<String?>(json['icon']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      isDefault: serializer.fromJson<int>(json['isDefault']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'icon': serializer.toJson<String?>(icon),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'isDefault': serializer.toJson<int>(isDefault),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  Album copyWith({
    String? id,
    String? name,
    Value<String?> icon = const Value.absent(),
    int? sortOrder,
    int? isDefault,
    int? createdAt,
  }) => Album(
    id: id ?? this.id,
    name: name ?? this.name,
    icon: icon.present ? icon.value : this.icon,
    sortOrder: sortOrder ?? this.sortOrder,
    isDefault: isDefault ?? this.isDefault,
    createdAt: createdAt ?? this.createdAt,
  );
  Album copyWithCompanion(AlbumsTableCompanion data) {
    return Album(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      icon: data.icon.present ? data.icon.value : this.icon,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Album(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isDefault: $isDefault, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, icon, sortOrder, isDefault, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Album &&
          other.id == this.id &&
          other.name == this.name &&
          other.icon == this.icon &&
          other.sortOrder == this.sortOrder &&
          other.isDefault == this.isDefault &&
          other.createdAt == this.createdAt);
}

class AlbumsTableCompanion extends UpdateCompanion<Album> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> icon;
  final Value<int> sortOrder;
  final Value<int> isDefault;
  final Value<int> createdAt;
  final Value<int> rowid;
  const AlbumsTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.icon = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AlbumsTableCompanion.insert({
    required String id,
    required String name,
    this.icon = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isDefault = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<Album> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? icon,
    Expression<int>? sortOrder,
    Expression<int>? isDefault,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (icon != null) 'icon': icon,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isDefault != null) 'is_default': isDefault,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AlbumsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? icon,
    Value<int>? sortOrder,
    Value<int>? isDefault,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return AlbumsTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
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
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<int>(isDefault.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AlbumsTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isDefault: $isDefault, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MemeAlbumsTableTable extends MemeAlbumsTable
    with TableInfo<$MemeAlbumsTableTable, MemeAlbum> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemeAlbumsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _memeIdMeta = const VerificationMeta('memeId');
  @override
  late final GeneratedColumn<String> memeId = GeneratedColumn<String>(
    'meme_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES memes_table (id)',
    ),
  );
  static const VerificationMeta _albumIdMeta = const VerificationMeta(
    'albumId',
  );
  @override
  late final GeneratedColumn<String> albumId = GeneratedColumn<String>(
    'album_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES albums_table (id)',
    ),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<int> addedAt = GeneratedColumn<int>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [memeId, albumId, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meme_albums_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemeAlbum> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('meme_id')) {
      context.handle(
        _memeIdMeta,
        memeId.isAcceptableOrUnknown(data['meme_id']!, _memeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_memeIdMeta);
    }
    if (data.containsKey('album_id')) {
      context.handle(
        _albumIdMeta,
        albumId.isAcceptableOrUnknown(data['album_id']!, _albumIdMeta),
      );
    } else if (isInserting) {
      context.missing(_albumIdMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {memeId, albumId};
  @override
  MemeAlbum map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemeAlbum(
      memeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meme_id'],
      )!,
      albumId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_id'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $MemeAlbumsTableTable createAlias(String alias) {
    return $MemeAlbumsTableTable(attachedDatabase, alias);
  }
}

class MemeAlbum extends DataClass implements Insertable<MemeAlbum> {
  final String memeId;
  final String albumId;
  final int addedAt;
  const MemeAlbum({
    required this.memeId,
    required this.albumId,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['meme_id'] = Variable<String>(memeId);
    map['album_id'] = Variable<String>(albumId);
    map['added_at'] = Variable<int>(addedAt);
    return map;
  }

  MemeAlbumsTableCompanion toCompanion(bool nullToAbsent) {
    return MemeAlbumsTableCompanion(
      memeId: Value(memeId),
      albumId: Value(albumId),
      addedAt: Value(addedAt),
    );
  }

  factory MemeAlbum.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemeAlbum(
      memeId: serializer.fromJson<String>(json['memeId']),
      albumId: serializer.fromJson<String>(json['albumId']),
      addedAt: serializer.fromJson<int>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'memeId': serializer.toJson<String>(memeId),
      'albumId': serializer.toJson<String>(albumId),
      'addedAt': serializer.toJson<int>(addedAt),
    };
  }

  MemeAlbum copyWith({String? memeId, String? albumId, int? addedAt}) =>
      MemeAlbum(
        memeId: memeId ?? this.memeId,
        albumId: albumId ?? this.albumId,
        addedAt: addedAt ?? this.addedAt,
      );
  MemeAlbum copyWithCompanion(MemeAlbumsTableCompanion data) {
    return MemeAlbum(
      memeId: data.memeId.present ? data.memeId.value : this.memeId,
      albumId: data.albumId.present ? data.albumId.value : this.albumId,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemeAlbum(')
          ..write('memeId: $memeId, ')
          ..write('albumId: $albumId, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(memeId, albumId, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemeAlbum &&
          other.memeId == this.memeId &&
          other.albumId == this.albumId &&
          other.addedAt == this.addedAt);
}

class MemeAlbumsTableCompanion extends UpdateCompanion<MemeAlbum> {
  final Value<String> memeId;
  final Value<String> albumId;
  final Value<int> addedAt;
  final Value<int> rowid;
  const MemeAlbumsTableCompanion({
    this.memeId = const Value.absent(),
    this.albumId = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemeAlbumsTableCompanion.insert({
    required String memeId,
    required String albumId,
    required int addedAt,
    this.rowid = const Value.absent(),
  }) : memeId = Value(memeId),
       albumId = Value(albumId),
       addedAt = Value(addedAt);
  static Insertable<MemeAlbum> custom({
    Expression<String>? memeId,
    Expression<String>? albumId,
    Expression<int>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (memeId != null) 'meme_id': memeId,
      if (albumId != null) 'album_id': albumId,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemeAlbumsTableCompanion copyWith({
    Value<String>? memeId,
    Value<String>? albumId,
    Value<int>? addedAt,
    Value<int>? rowid,
  }) {
    return MemeAlbumsTableCompanion(
      memeId: memeId ?? this.memeId,
      albumId: albumId ?? this.albumId,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (memeId.present) {
      map['meme_id'] = Variable<String>(memeId.value);
    }
    if (albumId.present) {
      map['album_id'] = Variable<String>(albumId.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemeAlbumsTableCompanion(')
          ..write('memeId: $memeId, ')
          ..write('albumId: $albumId, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserStatsTableTable extends UserStatsTable
    with TableInfo<$UserStatsTableTable, UserStatsEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserStatsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importedCountMeta = const VerificationMeta(
    'importedCount',
  );
  @override
  late final GeneratedColumn<int> importedCount = GeneratedColumn<int>(
    'imported_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _copiedCountMeta = const VerificationMeta(
    'copiedCount',
  );
  @override
  late final GeneratedColumn<int> copiedCount = GeneratedColumn<int>(
    'copied_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _favoritedCountMeta = const VerificationMeta(
    'favoritedCount',
  );
  @override
  late final GeneratedColumn<int> favoritedCount = GeneratedColumn<int>(
    'favorited_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _promptTokensMeta = const VerificationMeta(
    'promptTokens',
  );
  @override
  late final GeneratedColumn<int> promptTokens = GeneratedColumn<int>(
    'prompt_tokens',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _completionTokensMeta = const VerificationMeta(
    'completionTokens',
  );
  @override
  late final GeneratedColumn<int> completionTokens = GeneratedColumn<int>(
    'completion_tokens',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    date,
    importedCount,
    copiedCount,
    favoritedCount,
    promptTokens,
    completionTokens,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_stats_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserStatsEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('imported_count')) {
      context.handle(
        _importedCountMeta,
        importedCount.isAcceptableOrUnknown(
          data['imported_count']!,
          _importedCountMeta,
        ),
      );
    }
    if (data.containsKey('copied_count')) {
      context.handle(
        _copiedCountMeta,
        copiedCount.isAcceptableOrUnknown(
          data['copied_count']!,
          _copiedCountMeta,
        ),
      );
    }
    if (data.containsKey('favorited_count')) {
      context.handle(
        _favoritedCountMeta,
        favoritedCount.isAcceptableOrUnknown(
          data['favorited_count']!,
          _favoritedCountMeta,
        ),
      );
    }
    if (data.containsKey('prompt_tokens')) {
      context.handle(
        _promptTokensMeta,
        promptTokens.isAcceptableOrUnknown(
          data['prompt_tokens']!,
          _promptTokensMeta,
        ),
      );
    }
    if (data.containsKey('completion_tokens')) {
      context.handle(
        _completionTokensMeta,
        completionTokens.isAcceptableOrUnknown(
          data['completion_tokens']!,
          _completionTokensMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {date};
  @override
  UserStatsEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserStatsEntry(
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      importedCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}imported_count'],
      )!,
      copiedCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}copied_count'],
      )!,
      favoritedCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}favorited_count'],
      )!,
      promptTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}prompt_tokens'],
      )!,
      completionTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completion_tokens'],
      )!,
    );
  }

  @override
  $UserStatsTableTable createAlias(String alias) {
    return $UserStatsTableTable(attachedDatabase, alias);
  }
}

class UserStatsEntry extends DataClass implements Insertable<UserStatsEntry> {
  /// 日期字符串（yyyy-MM-dd）
  final String date;

  /// 当天导入 meme 数量
  final int importedCount;

  /// 当天复制 meme 次数
  final int copiedCount;

  /// 当天收藏 meme 数量
  final int favoritedCount;

  /// 当天 remote LLM 调用 prompt token 数
  final int promptTokens;

  /// 当天 remote LLM 调用 completion token 数
  final int completionTokens;
  const UserStatsEntry({
    required this.date,
    required this.importedCount,
    required this.copiedCount,
    required this.favoritedCount,
    required this.promptTokens,
    required this.completionTokens,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<String>(date);
    map['imported_count'] = Variable<int>(importedCount);
    map['copied_count'] = Variable<int>(copiedCount);
    map['favorited_count'] = Variable<int>(favoritedCount);
    map['prompt_tokens'] = Variable<int>(promptTokens);
    map['completion_tokens'] = Variable<int>(completionTokens);
    return map;
  }

  UserStatsTableCompanion toCompanion(bool nullToAbsent) {
    return UserStatsTableCompanion(
      date: Value(date),
      importedCount: Value(importedCount),
      copiedCount: Value(copiedCount),
      favoritedCount: Value(favoritedCount),
      promptTokens: Value(promptTokens),
      completionTokens: Value(completionTokens),
    );
  }

  factory UserStatsEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserStatsEntry(
      date: serializer.fromJson<String>(json['date']),
      importedCount: serializer.fromJson<int>(json['importedCount']),
      copiedCount: serializer.fromJson<int>(json['copiedCount']),
      favoritedCount: serializer.fromJson<int>(json['favoritedCount']),
      promptTokens: serializer.fromJson<int>(json['promptTokens']),
      completionTokens: serializer.fromJson<int>(json['completionTokens']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'date': serializer.toJson<String>(date),
      'importedCount': serializer.toJson<int>(importedCount),
      'copiedCount': serializer.toJson<int>(copiedCount),
      'favoritedCount': serializer.toJson<int>(favoritedCount),
      'promptTokens': serializer.toJson<int>(promptTokens),
      'completionTokens': serializer.toJson<int>(completionTokens),
    };
  }

  UserStatsEntry copyWith({
    String? date,
    int? importedCount,
    int? copiedCount,
    int? favoritedCount,
    int? promptTokens,
    int? completionTokens,
  }) => UserStatsEntry(
    date: date ?? this.date,
    importedCount: importedCount ?? this.importedCount,
    copiedCount: copiedCount ?? this.copiedCount,
    favoritedCount: favoritedCount ?? this.favoritedCount,
    promptTokens: promptTokens ?? this.promptTokens,
    completionTokens: completionTokens ?? this.completionTokens,
  );
  UserStatsEntry copyWithCompanion(UserStatsTableCompanion data) {
    return UserStatsEntry(
      date: data.date.present ? data.date.value : this.date,
      importedCount: data.importedCount.present
          ? data.importedCount.value
          : this.importedCount,
      copiedCount: data.copiedCount.present
          ? data.copiedCount.value
          : this.copiedCount,
      favoritedCount: data.favoritedCount.present
          ? data.favoritedCount.value
          : this.favoritedCount,
      promptTokens: data.promptTokens.present
          ? data.promptTokens.value
          : this.promptTokens,
      completionTokens: data.completionTokens.present
          ? data.completionTokens.value
          : this.completionTokens,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserStatsEntry(')
          ..write('date: $date, ')
          ..write('importedCount: $importedCount, ')
          ..write('copiedCount: $copiedCount, ')
          ..write('favoritedCount: $favoritedCount, ')
          ..write('promptTokens: $promptTokens, ')
          ..write('completionTokens: $completionTokens')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    date,
    importedCount,
    copiedCount,
    favoritedCount,
    promptTokens,
    completionTokens,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserStatsEntry &&
          other.date == this.date &&
          other.importedCount == this.importedCount &&
          other.copiedCount == this.copiedCount &&
          other.favoritedCount == this.favoritedCount &&
          other.promptTokens == this.promptTokens &&
          other.completionTokens == this.completionTokens);
}

class UserStatsTableCompanion extends UpdateCompanion<UserStatsEntry> {
  final Value<String> date;
  final Value<int> importedCount;
  final Value<int> copiedCount;
  final Value<int> favoritedCount;
  final Value<int> promptTokens;
  final Value<int> completionTokens;
  final Value<int> rowid;
  const UserStatsTableCompanion({
    this.date = const Value.absent(),
    this.importedCount = const Value.absent(),
    this.copiedCount = const Value.absent(),
    this.favoritedCount = const Value.absent(),
    this.promptTokens = const Value.absent(),
    this.completionTokens = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserStatsTableCompanion.insert({
    required String date,
    this.importedCount = const Value.absent(),
    this.copiedCount = const Value.absent(),
    this.favoritedCount = const Value.absent(),
    this.promptTokens = const Value.absent(),
    this.completionTokens = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : date = Value(date);
  static Insertable<UserStatsEntry> custom({
    Expression<String>? date,
    Expression<int>? importedCount,
    Expression<int>? copiedCount,
    Expression<int>? favoritedCount,
    Expression<int>? promptTokens,
    Expression<int>? completionTokens,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (importedCount != null) 'imported_count': importedCount,
      if (copiedCount != null) 'copied_count': copiedCount,
      if (favoritedCount != null) 'favorited_count': favoritedCount,
      if (promptTokens != null) 'prompt_tokens': promptTokens,
      if (completionTokens != null) 'completion_tokens': completionTokens,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserStatsTableCompanion copyWith({
    Value<String>? date,
    Value<int>? importedCount,
    Value<int>? copiedCount,
    Value<int>? favoritedCount,
    Value<int>? promptTokens,
    Value<int>? completionTokens,
    Value<int>? rowid,
  }) {
    return UserStatsTableCompanion(
      date: date ?? this.date,
      importedCount: importedCount ?? this.importedCount,
      copiedCount: copiedCount ?? this.copiedCount,
      favoritedCount: favoritedCount ?? this.favoritedCount,
      promptTokens: promptTokens ?? this.promptTokens,
      completionTokens: completionTokens ?? this.completionTokens,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (importedCount.present) {
      map['imported_count'] = Variable<int>(importedCount.value);
    }
    if (copiedCount.present) {
      map['copied_count'] = Variable<int>(copiedCount.value);
    }
    if (favoritedCount.present) {
      map['favorited_count'] = Variable<int>(favoritedCount.value);
    }
    if (promptTokens.present) {
      map['prompt_tokens'] = Variable<int>(promptTokens.value);
    }
    if (completionTokens.present) {
      map['completion_tokens'] = Variable<int>(completionTokens.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserStatsTableCompanion(')
          ..write('date: $date, ')
          ..write('importedCount: $importedCount, ')
          ..write('copiedCount: $copiedCount, ')
          ..write('favoritedCount: $favoritedCount, ')
          ..write('promptTokens: $promptTokens, ')
          ..write('completionTokens: $completionTokens, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MemesTableTable memesTable = $MemesTableTable(this);
  late final $TagsTableTable tagsTable = $TagsTableTable(this);
  late final $ColorsTableTable colorsTable = $ColorsTableTable(this);
  late final $EmbeddingsTableTable embeddingsTable = $EmbeddingsTableTable(
    this,
  );
  late final $AnalysisQueueTableTable analysisQueueTable =
      $AnalysisQueueTableTable(this);
  late final $SyncStateTableTable syncStateTable = $SyncStateTableTable(this);
  late final $AlbumsTableTable albumsTable = $AlbumsTableTable(this);
  late final $MemeAlbumsTableTable memeAlbumsTable = $MemeAlbumsTableTable(
    this,
  );
  late final $UserStatsTableTable userStatsTable = $UserStatsTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    memesTable,
    tagsTable,
    colorsTable,
    embeddingsTable,
    analysisQueueTable,
    syncStateTable,
    albumsTable,
    memeAlbumsTable,
    userStatsTable,
  ];
}

typedef $$MemesTableTableCreateCompanionBuilder =
    MemesTableCompanion Function({
      required String id,
      required String filename,
      required String filePath,
      required int fileSize,
      required String mimeType,
      required int width,
      required int height,
      Value<String?> folderId,
      Value<String> analysisStatus,
      required String fileHash,
      Value<String?> description,
      required int createdAt,
      required int updatedAt,
      required int importedAt,
      Value<int> copyCount,
      Value<String?> source,
      Value<int> rowid,
    });
typedef $$MemesTableTableUpdateCompanionBuilder =
    MemesTableCompanion Function({
      Value<String> id,
      Value<String> filename,
      Value<String> filePath,
      Value<int> fileSize,
      Value<String> mimeType,
      Value<int> width,
      Value<int> height,
      Value<String?> folderId,
      Value<String> analysisStatus,
      Value<String> fileHash,
      Value<String?> description,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> importedAt,
      Value<int> copyCount,
      Value<String?> source,
      Value<int> rowid,
    });

final class $$MemesTableTableReferences
    extends BaseReferences<_$AppDatabase, $MemesTableTable, Meme> {
  $$MemesTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TagsTableTable, List<TagEntry>>
  _tagsTableRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.tagsTable,
    aliasName: $_aliasNameGenerator(db.memesTable.id, db.tagsTable.memeId),
  );

  $$TagsTableTableProcessedTableManager get tagsTableRefs {
    final manager = $$TagsTableTableTableManager(
      $_db,
      $_db.tagsTable,
    ).filter((f) => f.memeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_tagsTableRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ColorsTableTable, List<ColorEntry>>
  _colorsTableRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.colorsTable,
    aliasName: $_aliasNameGenerator(db.memesTable.id, db.colorsTable.memeId),
  );

  $$ColorsTableTableProcessedTableManager get colorsTableRefs {
    final manager = $$ColorsTableTableTableManager(
      $_db,
      $_db.colorsTable,
    ).filter((f) => f.memeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_colorsTableRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AnalysisQueueTableTable, List<AnalysisQueueItem>>
  _analysisQueueTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.analysisQueueTable,
        aliasName: $_aliasNameGenerator(
          db.memesTable.id,
          db.analysisQueueTable.memeId,
        ),
      );

  $$AnalysisQueueTableTableProcessedTableManager get analysisQueueTableRefs {
    final manager = $$AnalysisQueueTableTableTableManager(
      $_db,
      $_db.analysisQueueTable,
    ).filter((f) => f.memeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _analysisQueueTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MemeAlbumsTableTable, List<MemeAlbum>>
  _memeAlbumsTableRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.memeAlbumsTable,
    aliasName: $_aliasNameGenerator(
      db.memesTable.id,
      db.memeAlbumsTable.memeId,
    ),
  );

  $$MemeAlbumsTableTableProcessedTableManager get memeAlbumsTableRefs {
    final manager = $$MemeAlbumsTableTableTableManager(
      $_db,
      $_db.memeAlbumsTable,
    ).filter((f) => f.memeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _memeAlbumsTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MemesTableTableFilterComposer
    extends Composer<_$AppDatabase, $MemesTableTable> {
  $$MemesTableTableFilterComposer({
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

  ColumnFilters<String> get filename => $composableBuilder(
    column: $table.filename,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get analysisStatus => $composableBuilder(
    column: $table.analysisStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileHash => $composableBuilder(
    column: $table.fileHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get copyCount => $composableBuilder(
    column: $table.copyCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> tagsTableRefs(
    Expression<bool> Function($$TagsTableTableFilterComposer f) f,
  ) {
    final $$TagsTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tagsTable,
      getReferencedColumn: (t) => t.memeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableTableFilterComposer(
            $db: $db,
            $table: $db.tagsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> colorsTableRefs(
    Expression<bool> Function($$ColorsTableTableFilterComposer f) f,
  ) {
    final $$ColorsTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.colorsTable,
      getReferencedColumn: (t) => t.memeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ColorsTableTableFilterComposer(
            $db: $db,
            $table: $db.colorsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> analysisQueueTableRefs(
    Expression<bool> Function($$AnalysisQueueTableTableFilterComposer f) f,
  ) {
    final $$AnalysisQueueTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.analysisQueueTable,
      getReferencedColumn: (t) => t.memeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnalysisQueueTableTableFilterComposer(
            $db: $db,
            $table: $db.analysisQueueTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> memeAlbumsTableRefs(
    Expression<bool> Function($$MemeAlbumsTableTableFilterComposer f) f,
  ) {
    final $$MemeAlbumsTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memeAlbumsTable,
      getReferencedColumn: (t) => t.memeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemeAlbumsTableTableFilterComposer(
            $db: $db,
            $table: $db.memeAlbumsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MemesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $MemesTableTable> {
  $$MemesTableTableOrderingComposer({
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

  ColumnOrderings<String> get filename => $composableBuilder(
    column: $table.filename,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get analysisStatus => $composableBuilder(
    column: $table.analysisStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileHash => $composableBuilder(
    column: $table.fileHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get copyCount => $composableBuilder(
    column: $table.copyCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MemesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemesTableTable> {
  $$MemesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get filename =>
      $composableBuilder(column: $table.filename, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<String> get folderId =>
      $composableBuilder(column: $table.folderId, builder: (column) => column);

  GeneratedColumn<String> get analysisStatus => $composableBuilder(
    column: $table.analysisStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fileHash =>
      $composableBuilder(column: $table.fileHash, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get copyCount =>
      $composableBuilder(column: $table.copyCount, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  Expression<T> tagsTableRefs<T extends Object>(
    Expression<T> Function($$TagsTableTableAnnotationComposer a) f,
  ) {
    final $$TagsTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tagsTable,
      getReferencedColumn: (t) => t.memeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableTableAnnotationComposer(
            $db: $db,
            $table: $db.tagsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> colorsTableRefs<T extends Object>(
    Expression<T> Function($$ColorsTableTableAnnotationComposer a) f,
  ) {
    final $$ColorsTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.colorsTable,
      getReferencedColumn: (t) => t.memeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ColorsTableTableAnnotationComposer(
            $db: $db,
            $table: $db.colorsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> analysisQueueTableRefs<T extends Object>(
    Expression<T> Function($$AnalysisQueueTableTableAnnotationComposer a) f,
  ) {
    final $$AnalysisQueueTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.analysisQueueTable,
          getReferencedColumn: (t) => t.memeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AnalysisQueueTableTableAnnotationComposer(
                $db: $db,
                $table: $db.analysisQueueTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> memeAlbumsTableRefs<T extends Object>(
    Expression<T> Function($$MemeAlbumsTableTableAnnotationComposer a) f,
  ) {
    final $$MemeAlbumsTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memeAlbumsTable,
      getReferencedColumn: (t) => t.memeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemeAlbumsTableTableAnnotationComposer(
            $db: $db,
            $table: $db.memeAlbumsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MemesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemesTableTable,
          Meme,
          $$MemesTableTableFilterComposer,
          $$MemesTableTableOrderingComposer,
          $$MemesTableTableAnnotationComposer,
          $$MemesTableTableCreateCompanionBuilder,
          $$MemesTableTableUpdateCompanionBuilder,
          (Meme, $$MemesTableTableReferences),
          Meme,
          PrefetchHooks Function({
            bool tagsTableRefs,
            bool colorsTableRefs,
            bool analysisQueueTableRefs,
            bool memeAlbumsTableRefs,
          })
        > {
  $$MemesTableTableTableManager(_$AppDatabase db, $MemesTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> filename = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<int> fileSize = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<int> width = const Value.absent(),
                Value<int> height = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                Value<String> analysisStatus = const Value.absent(),
                Value<String> fileHash = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> importedAt = const Value.absent(),
                Value<int> copyCount = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemesTableCompanion(
                id: id,
                filename: filename,
                filePath: filePath,
                fileSize: fileSize,
                mimeType: mimeType,
                width: width,
                height: height,
                folderId: folderId,
                analysisStatus: analysisStatus,
                fileHash: fileHash,
                description: description,
                createdAt: createdAt,
                updatedAt: updatedAt,
                importedAt: importedAt,
                copyCount: copyCount,
                source: source,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String filename,
                required String filePath,
                required int fileSize,
                required String mimeType,
                required int width,
                required int height,
                Value<String?> folderId = const Value.absent(),
                Value<String> analysisStatus = const Value.absent(),
                required String fileHash,
                Value<String?> description = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                required int importedAt,
                Value<int> copyCount = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemesTableCompanion.insert(
                id: id,
                filename: filename,
                filePath: filePath,
                fileSize: fileSize,
                mimeType: mimeType,
                width: width,
                height: height,
                folderId: folderId,
                analysisStatus: analysisStatus,
                fileHash: fileHash,
                description: description,
                createdAt: createdAt,
                updatedAt: updatedAt,
                importedAt: importedAt,
                copyCount: copyCount,
                source: source,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MemesTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                tagsTableRefs = false,
                colorsTableRefs = false,
                analysisQueueTableRefs = false,
                memeAlbumsTableRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (tagsTableRefs) db.tagsTable,
                    if (colorsTableRefs) db.colorsTable,
                    if (analysisQueueTableRefs) db.analysisQueueTable,
                    if (memeAlbumsTableRefs) db.memeAlbumsTable,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (tagsTableRefs)
                        await $_getPrefetchedData<
                          Meme,
                          $MemesTableTable,
                          TagEntry
                        >(
                          currentTable: table,
                          referencedTable: $$MemesTableTableReferences
                              ._tagsTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MemesTableTableReferences(
                                db,
                                table,
                                p0,
                              ).tagsTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.memeId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (colorsTableRefs)
                        await $_getPrefetchedData<
                          Meme,
                          $MemesTableTable,
                          ColorEntry
                        >(
                          currentTable: table,
                          referencedTable: $$MemesTableTableReferences
                              ._colorsTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MemesTableTableReferences(
                                db,
                                table,
                                p0,
                              ).colorsTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.memeId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (analysisQueueTableRefs)
                        await $_getPrefetchedData<
                          Meme,
                          $MemesTableTable,
                          AnalysisQueueItem
                        >(
                          currentTable: table,
                          referencedTable: $$MemesTableTableReferences
                              ._analysisQueueTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MemesTableTableReferences(
                                db,
                                table,
                                p0,
                              ).analysisQueueTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.memeId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (memeAlbumsTableRefs)
                        await $_getPrefetchedData<
                          Meme,
                          $MemesTableTable,
                          MemeAlbum
                        >(
                          currentTable: table,
                          referencedTable: $$MemesTableTableReferences
                              ._memeAlbumsTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MemesTableTableReferences(
                                db,
                                table,
                                p0,
                              ).memeAlbumsTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.memeId == item.id,
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

typedef $$MemesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemesTableTable,
      Meme,
      $$MemesTableTableFilterComposer,
      $$MemesTableTableOrderingComposer,
      $$MemesTableTableAnnotationComposer,
      $$MemesTableTableCreateCompanionBuilder,
      $$MemesTableTableUpdateCompanionBuilder,
      (Meme, $$MemesTableTableReferences),
      Meme,
      PrefetchHooks Function({
        bool tagsTableRefs,
        bool colorsTableRefs,
        bool analysisQueueTableRefs,
        bool memeAlbumsTableRefs,
      })
    >;
typedef $$TagsTableTableCreateCompanionBuilder =
    TagsTableCompanion Function({
      required String id,
      required String memeId,
      required String source,
      required String content,
      Value<double> confidence,
      Value<int> rowid,
    });
typedef $$TagsTableTableUpdateCompanionBuilder =
    TagsTableCompanion Function({
      Value<String> id,
      Value<String> memeId,
      Value<String> source,
      Value<String> content,
      Value<double> confidence,
      Value<int> rowid,
    });

final class $$TagsTableTableReferences
    extends BaseReferences<_$AppDatabase, $TagsTableTable, TagEntry> {
  $$TagsTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MemesTableTable _memeIdTable(_$AppDatabase db) => db.memesTable
      .createAlias($_aliasNameGenerator(db.tagsTable.memeId, db.memesTable.id));

  $$MemesTableTableProcessedTableManager get memeId {
    final $_column = $_itemColumn<String>('meme_id')!;

    final manager = $$MemesTableTableTableManager(
      $_db,
      $_db.memesTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_memeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TagsTableTableFilterComposer
    extends Composer<_$AppDatabase, $TagsTableTable> {
  $$TagsTableTableFilterComposer({
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

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  $$MemesTableTableFilterComposer get memeId {
    final $$MemesTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memeId,
      referencedTable: $db.memesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemesTableTableFilterComposer(
            $db: $db,
            $table: $db.memesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TagsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $TagsTableTable> {
  $$TagsTableTableOrderingComposer({
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

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  $$MemesTableTableOrderingComposer get memeId {
    final $$MemesTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memeId,
      referencedTable: $db.memesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemesTableTableOrderingComposer(
            $db: $db,
            $table: $db.memesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TagsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagsTableTable> {
  $$TagsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  $$MemesTableTableAnnotationComposer get memeId {
    final $$MemesTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memeId,
      referencedTable: $db.memesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemesTableTableAnnotationComposer(
            $db: $db,
            $table: $db.memesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TagsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TagsTableTable,
          TagEntry,
          $$TagsTableTableFilterComposer,
          $$TagsTableTableOrderingComposer,
          $$TagsTableTableAnnotationComposer,
          $$TagsTableTableCreateCompanionBuilder,
          $$TagsTableTableUpdateCompanionBuilder,
          (TagEntry, $$TagsTableTableReferences),
          TagEntry,
          PrefetchHooks Function({bool memeId})
        > {
  $$TagsTableTableTableManager(_$AppDatabase db, $TagsTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> memeId = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<double> confidence = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsTableCompanion(
                id: id,
                memeId: memeId,
                source: source,
                content: content,
                confidence: confidence,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String memeId,
                required String source,
                required String content,
                Value<double> confidence = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsTableCompanion.insert(
                id: id,
                memeId: memeId,
                source: source,
                content: content,
                confidence: confidence,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TagsTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({memeId = false}) {
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
                    if (memeId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.memeId,
                                referencedTable: $$TagsTableTableReferences
                                    ._memeIdTable(db),
                                referencedColumn: $$TagsTableTableReferences
                                    ._memeIdTable(db)
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

typedef $$TagsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TagsTableTable,
      TagEntry,
      $$TagsTableTableFilterComposer,
      $$TagsTableTableOrderingComposer,
      $$TagsTableTableAnnotationComposer,
      $$TagsTableTableCreateCompanionBuilder,
      $$TagsTableTableUpdateCompanionBuilder,
      (TagEntry, $$TagsTableTableReferences),
      TagEntry,
      PrefetchHooks Function({bool memeId})
    >;
typedef $$ColorsTableTableCreateCompanionBuilder =
    ColorsTableCompanion Function({
      required String id,
      required String memeId,
      required String hexColor,
      required double labL,
      required double labA,
      required double labB,
      required double ratio,
      Value<int> rowid,
    });
typedef $$ColorsTableTableUpdateCompanionBuilder =
    ColorsTableCompanion Function({
      Value<String> id,
      Value<String> memeId,
      Value<String> hexColor,
      Value<double> labL,
      Value<double> labA,
      Value<double> labB,
      Value<double> ratio,
      Value<int> rowid,
    });

final class $$ColorsTableTableReferences
    extends BaseReferences<_$AppDatabase, $ColorsTableTable, ColorEntry> {
  $$ColorsTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MemesTableTable _memeIdTable(_$AppDatabase db) =>
      db.memesTable.createAlias(
        $_aliasNameGenerator(db.colorsTable.memeId, db.memesTable.id),
      );

  $$MemesTableTableProcessedTableManager get memeId {
    final $_column = $_itemColumn<String>('meme_id')!;

    final manager = $$MemesTableTableTableManager(
      $_db,
      $_db.memesTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_memeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ColorsTableTableFilterComposer
    extends Composer<_$AppDatabase, $ColorsTableTable> {
  $$ColorsTableTableFilterComposer({
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

  ColumnFilters<String> get hexColor => $composableBuilder(
    column: $table.hexColor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get labL => $composableBuilder(
    column: $table.labL,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get labA => $composableBuilder(
    column: $table.labA,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get labB => $composableBuilder(
    column: $table.labB,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get ratio => $composableBuilder(
    column: $table.ratio,
    builder: (column) => ColumnFilters(column),
  );

  $$MemesTableTableFilterComposer get memeId {
    final $$MemesTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memeId,
      referencedTable: $db.memesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemesTableTableFilterComposer(
            $db: $db,
            $table: $db.memesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ColorsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ColorsTableTable> {
  $$ColorsTableTableOrderingComposer({
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

  ColumnOrderings<String> get hexColor => $composableBuilder(
    column: $table.hexColor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get labL => $composableBuilder(
    column: $table.labL,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get labA => $composableBuilder(
    column: $table.labA,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get labB => $composableBuilder(
    column: $table.labB,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get ratio => $composableBuilder(
    column: $table.ratio,
    builder: (column) => ColumnOrderings(column),
  );

  $$MemesTableTableOrderingComposer get memeId {
    final $$MemesTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memeId,
      referencedTable: $db.memesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemesTableTableOrderingComposer(
            $db: $db,
            $table: $db.memesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ColorsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ColorsTableTable> {
  $$ColorsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get hexColor =>
      $composableBuilder(column: $table.hexColor, builder: (column) => column);

  GeneratedColumn<double> get labL =>
      $composableBuilder(column: $table.labL, builder: (column) => column);

  GeneratedColumn<double> get labA =>
      $composableBuilder(column: $table.labA, builder: (column) => column);

  GeneratedColumn<double> get labB =>
      $composableBuilder(column: $table.labB, builder: (column) => column);

  GeneratedColumn<double> get ratio =>
      $composableBuilder(column: $table.ratio, builder: (column) => column);

  $$MemesTableTableAnnotationComposer get memeId {
    final $$MemesTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memeId,
      referencedTable: $db.memesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemesTableTableAnnotationComposer(
            $db: $db,
            $table: $db.memesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ColorsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ColorsTableTable,
          ColorEntry,
          $$ColorsTableTableFilterComposer,
          $$ColorsTableTableOrderingComposer,
          $$ColorsTableTableAnnotationComposer,
          $$ColorsTableTableCreateCompanionBuilder,
          $$ColorsTableTableUpdateCompanionBuilder,
          (ColorEntry, $$ColorsTableTableReferences),
          ColorEntry,
          PrefetchHooks Function({bool memeId})
        > {
  $$ColorsTableTableTableManager(_$AppDatabase db, $ColorsTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ColorsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ColorsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ColorsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> memeId = const Value.absent(),
                Value<String> hexColor = const Value.absent(),
                Value<double> labL = const Value.absent(),
                Value<double> labA = const Value.absent(),
                Value<double> labB = const Value.absent(),
                Value<double> ratio = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ColorsTableCompanion(
                id: id,
                memeId: memeId,
                hexColor: hexColor,
                labL: labL,
                labA: labA,
                labB: labB,
                ratio: ratio,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String memeId,
                required String hexColor,
                required double labL,
                required double labA,
                required double labB,
                required double ratio,
                Value<int> rowid = const Value.absent(),
              }) => ColorsTableCompanion.insert(
                id: id,
                memeId: memeId,
                hexColor: hexColor,
                labL: labL,
                labA: labA,
                labB: labB,
                ratio: ratio,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ColorsTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({memeId = false}) {
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
                    if (memeId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.memeId,
                                referencedTable: $$ColorsTableTableReferences
                                    ._memeIdTable(db),
                                referencedColumn: $$ColorsTableTableReferences
                                    ._memeIdTable(db)
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

typedef $$ColorsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ColorsTableTable,
      ColorEntry,
      $$ColorsTableTableFilterComposer,
      $$ColorsTableTableOrderingComposer,
      $$ColorsTableTableAnnotationComposer,
      $$ColorsTableTableCreateCompanionBuilder,
      $$ColorsTableTableUpdateCompanionBuilder,
      (ColorEntry, $$ColorsTableTableReferences),
      ColorEntry,
      PrefetchHooks Function({bool memeId})
    >;
typedef $$EmbeddingsTableTableCreateCompanionBuilder =
    EmbeddingsTableCompanion Function({
      required String memeId,
      required Uint8List vector,
      required String modelId,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$EmbeddingsTableTableUpdateCompanionBuilder =
    EmbeddingsTableCompanion Function({
      Value<String> memeId,
      Value<Uint8List> vector,
      Value<String> modelId,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$EmbeddingsTableTableFilterComposer
    extends Composer<_$AppDatabase, $EmbeddingsTableTable> {
  $$EmbeddingsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get memeId => $composableBuilder(
    column: $table.memeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get vector => $composableBuilder(
    column: $table.vector,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EmbeddingsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $EmbeddingsTableTable> {
  $$EmbeddingsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get memeId => $composableBuilder(
    column: $table.memeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get vector => $composableBuilder(
    column: $table.vector,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EmbeddingsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $EmbeddingsTableTable> {
  $$EmbeddingsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get memeId =>
      $composableBuilder(column: $table.memeId, builder: (column) => column);

  GeneratedColumn<Uint8List> get vector =>
      $composableBuilder(column: $table.vector, builder: (column) => column);

  GeneratedColumn<String> get modelId =>
      $composableBuilder(column: $table.modelId, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$EmbeddingsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EmbeddingsTableTable,
          EmbeddingEntry,
          $$EmbeddingsTableTableFilterComposer,
          $$EmbeddingsTableTableOrderingComposer,
          $$EmbeddingsTableTableAnnotationComposer,
          $$EmbeddingsTableTableCreateCompanionBuilder,
          $$EmbeddingsTableTableUpdateCompanionBuilder,
          (
            EmbeddingEntry,
            BaseReferences<
              _$AppDatabase,
              $EmbeddingsTableTable,
              EmbeddingEntry
            >,
          ),
          EmbeddingEntry,
          PrefetchHooks Function()
        > {
  $$EmbeddingsTableTableTableManager(
    _$AppDatabase db,
    $EmbeddingsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EmbeddingsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EmbeddingsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EmbeddingsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> memeId = const Value.absent(),
                Value<Uint8List> vector = const Value.absent(),
                Value<String> modelId = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EmbeddingsTableCompanion(
                memeId: memeId,
                vector: vector,
                modelId: modelId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String memeId,
                required Uint8List vector,
                required String modelId,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => EmbeddingsTableCompanion.insert(
                memeId: memeId,
                vector: vector,
                modelId: modelId,
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

typedef $$EmbeddingsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EmbeddingsTableTable,
      EmbeddingEntry,
      $$EmbeddingsTableTableFilterComposer,
      $$EmbeddingsTableTableOrderingComposer,
      $$EmbeddingsTableTableAnnotationComposer,
      $$EmbeddingsTableTableCreateCompanionBuilder,
      $$EmbeddingsTableTableUpdateCompanionBuilder,
      (
        EmbeddingEntry,
        BaseReferences<_$AppDatabase, $EmbeddingsTableTable, EmbeddingEntry>,
      ),
      EmbeddingEntry,
      PrefetchHooks Function()
    >;
typedef $$AnalysisQueueTableTableCreateCompanionBuilder =
    AnalysisQueueTableCompanion Function({
      required String id,
      required String memeId,
      Value<String> status,
      Value<int> priority,
      Value<int> retryCount,
      Value<String?> errorMsg,
      required int createdAt,
      Value<int?> startedAt,
      Value<int?> doneAt,
      Value<int> rowid,
    });
typedef $$AnalysisQueueTableTableUpdateCompanionBuilder =
    AnalysisQueueTableCompanion Function({
      Value<String> id,
      Value<String> memeId,
      Value<String> status,
      Value<int> priority,
      Value<int> retryCount,
      Value<String?> errorMsg,
      Value<int> createdAt,
      Value<int?> startedAt,
      Value<int?> doneAt,
      Value<int> rowid,
    });

final class $$AnalysisQueueTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $AnalysisQueueTableTable,
          AnalysisQueueItem
        > {
  $$AnalysisQueueTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MemesTableTable _memeIdTable(_$AppDatabase db) =>
      db.memesTable.createAlias(
        $_aliasNameGenerator(db.analysisQueueTable.memeId, db.memesTable.id),
      );

  $$MemesTableTableProcessedTableManager get memeId {
    final $_column = $_itemColumn<String>('meme_id')!;

    final manager = $$MemesTableTableTableManager(
      $_db,
      $_db.memesTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_memeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AnalysisQueueTableTableFilterComposer
    extends Composer<_$AppDatabase, $AnalysisQueueTableTable> {
  $$AnalysisQueueTableTableFilterComposer({
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

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMsg => $composableBuilder(
    column: $table.errorMsg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get doneAt => $composableBuilder(
    column: $table.doneAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MemesTableTableFilterComposer get memeId {
    final $$MemesTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memeId,
      referencedTable: $db.memesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemesTableTableFilterComposer(
            $db: $db,
            $table: $db.memesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AnalysisQueueTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AnalysisQueueTableTable> {
  $$AnalysisQueueTableTableOrderingComposer({
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

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMsg => $composableBuilder(
    column: $table.errorMsg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get doneAt => $composableBuilder(
    column: $table.doneAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MemesTableTableOrderingComposer get memeId {
    final $$MemesTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memeId,
      referencedTable: $db.memesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemesTableTableOrderingComposer(
            $db: $db,
            $table: $db.memesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AnalysisQueueTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AnalysisQueueTableTable> {
  $$AnalysisQueueTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorMsg =>
      $composableBuilder(column: $table.errorMsg, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get doneAt =>
      $composableBuilder(column: $table.doneAt, builder: (column) => column);

  $$MemesTableTableAnnotationComposer get memeId {
    final $$MemesTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memeId,
      referencedTable: $db.memesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemesTableTableAnnotationComposer(
            $db: $db,
            $table: $db.memesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AnalysisQueueTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AnalysisQueueTableTable,
          AnalysisQueueItem,
          $$AnalysisQueueTableTableFilterComposer,
          $$AnalysisQueueTableTableOrderingComposer,
          $$AnalysisQueueTableTableAnnotationComposer,
          $$AnalysisQueueTableTableCreateCompanionBuilder,
          $$AnalysisQueueTableTableUpdateCompanionBuilder,
          (AnalysisQueueItem, $$AnalysisQueueTableTableReferences),
          AnalysisQueueItem,
          PrefetchHooks Function({bool memeId})
        > {
  $$AnalysisQueueTableTableTableManager(
    _$AppDatabase db,
    $AnalysisQueueTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnalysisQueueTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnalysisQueueTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnalysisQueueTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> memeId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String?> errorMsg = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int?> startedAt = const Value.absent(),
                Value<int?> doneAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AnalysisQueueTableCompanion(
                id: id,
                memeId: memeId,
                status: status,
                priority: priority,
                retryCount: retryCount,
                errorMsg: errorMsg,
                createdAt: createdAt,
                startedAt: startedAt,
                doneAt: doneAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String memeId,
                Value<String> status = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String?> errorMsg = const Value.absent(),
                required int createdAt,
                Value<int?> startedAt = const Value.absent(),
                Value<int?> doneAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AnalysisQueueTableCompanion.insert(
                id: id,
                memeId: memeId,
                status: status,
                priority: priority,
                retryCount: retryCount,
                errorMsg: errorMsg,
                createdAt: createdAt,
                startedAt: startedAt,
                doneAt: doneAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AnalysisQueueTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({memeId = false}) {
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
                    if (memeId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.memeId,
                                referencedTable:
                                    $$AnalysisQueueTableTableReferences
                                        ._memeIdTable(db),
                                referencedColumn:
                                    $$AnalysisQueueTableTableReferences
                                        ._memeIdTable(db)
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

typedef $$AnalysisQueueTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AnalysisQueueTableTable,
      AnalysisQueueItem,
      $$AnalysisQueueTableTableFilterComposer,
      $$AnalysisQueueTableTableOrderingComposer,
      $$AnalysisQueueTableTableAnnotationComposer,
      $$AnalysisQueueTableTableCreateCompanionBuilder,
      $$AnalysisQueueTableTableUpdateCompanionBuilder,
      (AnalysisQueueItem, $$AnalysisQueueTableTableReferences),
      AnalysisQueueItem,
      PrefetchHooks Function({bool memeId})
    >;
typedef $$SyncStateTableTableCreateCompanionBuilder =
    SyncStateTableCompanion Function({
      required String id,
      required String value,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$SyncStateTableTableUpdateCompanionBuilder =
    SyncStateTableCompanion Function({
      Value<String> id,
      Value<String> value,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$SyncStateTableTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStateTableTable> {
  $$SyncStateTableTableFilterComposer({
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

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStateTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStateTableTable> {
  $$SyncStateTableTableOrderingComposer({
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

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStateTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStateTableTable> {
  $$SyncStateTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SyncStateTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncStateTableTable,
          SyncStateEntry,
          $$SyncStateTableTableFilterComposer,
          $$SyncStateTableTableOrderingComposer,
          $$SyncStateTableTableAnnotationComposer,
          $$SyncStateTableTableCreateCompanionBuilder,
          $$SyncStateTableTableUpdateCompanionBuilder,
          (
            SyncStateEntry,
            BaseReferences<_$AppDatabase, $SyncStateTableTable, SyncStateEntry>,
          ),
          SyncStateEntry,
          PrefetchHooks Function()
        > {
  $$SyncStateTableTableTableManager(
    _$AppDatabase db,
    $SyncStateTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStateTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStateTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStateTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStateTableCompanion(
                id: id,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String value,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SyncStateTableCompanion.insert(
                id: id,
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

typedef $$SyncStateTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncStateTableTable,
      SyncStateEntry,
      $$SyncStateTableTableFilterComposer,
      $$SyncStateTableTableOrderingComposer,
      $$SyncStateTableTableAnnotationComposer,
      $$SyncStateTableTableCreateCompanionBuilder,
      $$SyncStateTableTableUpdateCompanionBuilder,
      (
        SyncStateEntry,
        BaseReferences<_$AppDatabase, $SyncStateTableTable, SyncStateEntry>,
      ),
      SyncStateEntry,
      PrefetchHooks Function()
    >;
typedef $$AlbumsTableTableCreateCompanionBuilder =
    AlbumsTableCompanion Function({
      required String id,
      required String name,
      Value<String?> icon,
      Value<int> sortOrder,
      Value<int> isDefault,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$AlbumsTableTableUpdateCompanionBuilder =
    AlbumsTableCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> icon,
      Value<int> sortOrder,
      Value<int> isDefault,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $$AlbumsTableTableReferences
    extends BaseReferences<_$AppDatabase, $AlbumsTableTable, Album> {
  $$AlbumsTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MemeAlbumsTableTable, List<MemeAlbum>>
  _memeAlbumsTableRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.memeAlbumsTable,
    aliasName: $_aliasNameGenerator(
      db.albumsTable.id,
      db.memeAlbumsTable.albumId,
    ),
  );

  $$MemeAlbumsTableTableProcessedTableManager get memeAlbumsTableRefs {
    final manager = $$MemeAlbumsTableTableTableManager(
      $_db,
      $_db.memeAlbumsTable,
    ).filter((f) => f.albumId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _memeAlbumsTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AlbumsTableTableFilterComposer
    extends Composer<_$AppDatabase, $AlbumsTableTable> {
  $$AlbumsTableTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> memeAlbumsTableRefs(
    Expression<bool> Function($$MemeAlbumsTableTableFilterComposer f) f,
  ) {
    final $$MemeAlbumsTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memeAlbumsTable,
      getReferencedColumn: (t) => t.albumId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemeAlbumsTableTableFilterComposer(
            $db: $db,
            $table: $db.memeAlbumsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AlbumsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AlbumsTableTable> {
  $$AlbumsTableTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AlbumsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AlbumsTableTable> {
  $$AlbumsTableTableAnnotationComposer({
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

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> memeAlbumsTableRefs<T extends Object>(
    Expression<T> Function($$MemeAlbumsTableTableAnnotationComposer a) f,
  ) {
    final $$MemeAlbumsTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memeAlbumsTable,
      getReferencedColumn: (t) => t.albumId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemeAlbumsTableTableAnnotationComposer(
            $db: $db,
            $table: $db.memeAlbumsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AlbumsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AlbumsTableTable,
          Album,
          $$AlbumsTableTableFilterComposer,
          $$AlbumsTableTableOrderingComposer,
          $$AlbumsTableTableAnnotationComposer,
          $$AlbumsTableTableCreateCompanionBuilder,
          $$AlbumsTableTableUpdateCompanionBuilder,
          (Album, $$AlbumsTableTableReferences),
          Album,
          PrefetchHooks Function({bool memeAlbumsTableRefs})
        > {
  $$AlbumsTableTableTableManager(_$AppDatabase db, $AlbumsTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AlbumsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AlbumsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AlbumsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> isDefault = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AlbumsTableCompanion(
                id: id,
                name: name,
                icon: icon,
                sortOrder: sortOrder,
                isDefault: isDefault,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> icon = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> isDefault = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => AlbumsTableCompanion.insert(
                id: id,
                name: name,
                icon: icon,
                sortOrder: sortOrder,
                isDefault: isDefault,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AlbumsTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({memeAlbumsTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (memeAlbumsTableRefs) db.memeAlbumsTable,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (memeAlbumsTableRefs)
                    await $_getPrefetchedData<
                      Album,
                      $AlbumsTableTable,
                      MemeAlbum
                    >(
                      currentTable: table,
                      referencedTable: $$AlbumsTableTableReferences
                          ._memeAlbumsTableRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$AlbumsTableTableReferences(
                            db,
                            table,
                            p0,
                          ).memeAlbumsTableRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.albumId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$AlbumsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AlbumsTableTable,
      Album,
      $$AlbumsTableTableFilterComposer,
      $$AlbumsTableTableOrderingComposer,
      $$AlbumsTableTableAnnotationComposer,
      $$AlbumsTableTableCreateCompanionBuilder,
      $$AlbumsTableTableUpdateCompanionBuilder,
      (Album, $$AlbumsTableTableReferences),
      Album,
      PrefetchHooks Function({bool memeAlbumsTableRefs})
    >;
typedef $$MemeAlbumsTableTableCreateCompanionBuilder =
    MemeAlbumsTableCompanion Function({
      required String memeId,
      required String albumId,
      required int addedAt,
      Value<int> rowid,
    });
typedef $$MemeAlbumsTableTableUpdateCompanionBuilder =
    MemeAlbumsTableCompanion Function({
      Value<String> memeId,
      Value<String> albumId,
      Value<int> addedAt,
      Value<int> rowid,
    });

final class $$MemeAlbumsTableTableReferences
    extends BaseReferences<_$AppDatabase, $MemeAlbumsTableTable, MemeAlbum> {
  $$MemeAlbumsTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MemesTableTable _memeIdTable(_$AppDatabase db) =>
      db.memesTable.createAlias(
        $_aliasNameGenerator(db.memeAlbumsTable.memeId, db.memesTable.id),
      );

  $$MemesTableTableProcessedTableManager get memeId {
    final $_column = $_itemColumn<String>('meme_id')!;

    final manager = $$MemesTableTableTableManager(
      $_db,
      $_db.memesTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_memeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $AlbumsTableTable _albumIdTable(_$AppDatabase db) =>
      db.albumsTable.createAlias(
        $_aliasNameGenerator(db.memeAlbumsTable.albumId, db.albumsTable.id),
      );

  $$AlbumsTableTableProcessedTableManager get albumId {
    final $_column = $_itemColumn<String>('album_id')!;

    final manager = $$AlbumsTableTableTableManager(
      $_db,
      $_db.albumsTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_albumIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MemeAlbumsTableTableFilterComposer
    extends Composer<_$AppDatabase, $MemeAlbumsTableTable> {
  $$MemeAlbumsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MemesTableTableFilterComposer get memeId {
    final $$MemesTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memeId,
      referencedTable: $db.memesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemesTableTableFilterComposer(
            $db: $db,
            $table: $db.memesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AlbumsTableTableFilterComposer get albumId {
    final $$AlbumsTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.albumId,
      referencedTable: $db.albumsTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlbumsTableTableFilterComposer(
            $db: $db,
            $table: $db.albumsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemeAlbumsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $MemeAlbumsTableTable> {
  $$MemeAlbumsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MemesTableTableOrderingComposer get memeId {
    final $$MemesTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memeId,
      referencedTable: $db.memesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemesTableTableOrderingComposer(
            $db: $db,
            $table: $db.memesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AlbumsTableTableOrderingComposer get albumId {
    final $$AlbumsTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.albumId,
      referencedTable: $db.albumsTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlbumsTableTableOrderingComposer(
            $db: $db,
            $table: $db.albumsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemeAlbumsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemeAlbumsTableTable> {
  $$MemeAlbumsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$MemesTableTableAnnotationComposer get memeId {
    final $$MemesTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memeId,
      referencedTable: $db.memesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemesTableTableAnnotationComposer(
            $db: $db,
            $table: $db.memesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AlbumsTableTableAnnotationComposer get albumId {
    final $$AlbumsTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.albumId,
      referencedTable: $db.albumsTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlbumsTableTableAnnotationComposer(
            $db: $db,
            $table: $db.albumsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemeAlbumsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemeAlbumsTableTable,
          MemeAlbum,
          $$MemeAlbumsTableTableFilterComposer,
          $$MemeAlbumsTableTableOrderingComposer,
          $$MemeAlbumsTableTableAnnotationComposer,
          $$MemeAlbumsTableTableCreateCompanionBuilder,
          $$MemeAlbumsTableTableUpdateCompanionBuilder,
          (MemeAlbum, $$MemeAlbumsTableTableReferences),
          MemeAlbum,
          PrefetchHooks Function({bool memeId, bool albumId})
        > {
  $$MemeAlbumsTableTableTableManager(
    _$AppDatabase db,
    $MemeAlbumsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemeAlbumsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemeAlbumsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemeAlbumsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> memeId = const Value.absent(),
                Value<String> albumId = const Value.absent(),
                Value<int> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemeAlbumsTableCompanion(
                memeId: memeId,
                albumId: albumId,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String memeId,
                required String albumId,
                required int addedAt,
                Value<int> rowid = const Value.absent(),
              }) => MemeAlbumsTableCompanion.insert(
                memeId: memeId,
                albumId: albumId,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MemeAlbumsTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({memeId = false, albumId = false}) {
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
                    if (memeId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.memeId,
                                referencedTable:
                                    $$MemeAlbumsTableTableReferences
                                        ._memeIdTable(db),
                                referencedColumn:
                                    $$MemeAlbumsTableTableReferences
                                        ._memeIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (albumId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.albumId,
                                referencedTable:
                                    $$MemeAlbumsTableTableReferences
                                        ._albumIdTable(db),
                                referencedColumn:
                                    $$MemeAlbumsTableTableReferences
                                        ._albumIdTable(db)
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

typedef $$MemeAlbumsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemeAlbumsTableTable,
      MemeAlbum,
      $$MemeAlbumsTableTableFilterComposer,
      $$MemeAlbumsTableTableOrderingComposer,
      $$MemeAlbumsTableTableAnnotationComposer,
      $$MemeAlbumsTableTableCreateCompanionBuilder,
      $$MemeAlbumsTableTableUpdateCompanionBuilder,
      (MemeAlbum, $$MemeAlbumsTableTableReferences),
      MemeAlbum,
      PrefetchHooks Function({bool memeId, bool albumId})
    >;
typedef $$UserStatsTableTableCreateCompanionBuilder =
    UserStatsTableCompanion Function({
      required String date,
      Value<int> importedCount,
      Value<int> copiedCount,
      Value<int> favoritedCount,
      Value<int> promptTokens,
      Value<int> completionTokens,
      Value<int> rowid,
    });
typedef $$UserStatsTableTableUpdateCompanionBuilder =
    UserStatsTableCompanion Function({
      Value<String> date,
      Value<int> importedCount,
      Value<int> copiedCount,
      Value<int> favoritedCount,
      Value<int> promptTokens,
      Value<int> completionTokens,
      Value<int> rowid,
    });

class $$UserStatsTableTableFilterComposer
    extends Composer<_$AppDatabase, $UserStatsTableTable> {
  $$UserStatsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get importedCount => $composableBuilder(
    column: $table.importedCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get copiedCount => $composableBuilder(
    column: $table.copiedCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get favoritedCount => $composableBuilder(
    column: $table.favoritedCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get promptTokens => $composableBuilder(
    column: $table.promptTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completionTokens => $composableBuilder(
    column: $table.completionTokens,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserStatsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $UserStatsTableTable> {
  $$UserStatsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get importedCount => $composableBuilder(
    column: $table.importedCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get copiedCount => $composableBuilder(
    column: $table.copiedCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get favoritedCount => $composableBuilder(
    column: $table.favoritedCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get promptTokens => $composableBuilder(
    column: $table.promptTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completionTokens => $composableBuilder(
    column: $table.completionTokens,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserStatsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserStatsTableTable> {
  $$UserStatsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get importedCount => $composableBuilder(
    column: $table.importedCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get copiedCount => $composableBuilder(
    column: $table.copiedCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get favoritedCount => $composableBuilder(
    column: $table.favoritedCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get promptTokens => $composableBuilder(
    column: $table.promptTokens,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completionTokens => $composableBuilder(
    column: $table.completionTokens,
    builder: (column) => column,
  );
}

class $$UserStatsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserStatsTableTable,
          UserStatsEntry,
          $$UserStatsTableTableFilterComposer,
          $$UserStatsTableTableOrderingComposer,
          $$UserStatsTableTableAnnotationComposer,
          $$UserStatsTableTableCreateCompanionBuilder,
          $$UserStatsTableTableUpdateCompanionBuilder,
          (
            UserStatsEntry,
            BaseReferences<_$AppDatabase, $UserStatsTableTable, UserStatsEntry>,
          ),
          UserStatsEntry,
          PrefetchHooks Function()
        > {
  $$UserStatsTableTableTableManager(
    _$AppDatabase db,
    $UserStatsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserStatsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserStatsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserStatsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> date = const Value.absent(),
                Value<int> importedCount = const Value.absent(),
                Value<int> copiedCount = const Value.absent(),
                Value<int> favoritedCount = const Value.absent(),
                Value<int> promptTokens = const Value.absent(),
                Value<int> completionTokens = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserStatsTableCompanion(
                date: date,
                importedCount: importedCount,
                copiedCount: copiedCount,
                favoritedCount: favoritedCount,
                promptTokens: promptTokens,
                completionTokens: completionTokens,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String date,
                Value<int> importedCount = const Value.absent(),
                Value<int> copiedCount = const Value.absent(),
                Value<int> favoritedCount = const Value.absent(),
                Value<int> promptTokens = const Value.absent(),
                Value<int> completionTokens = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserStatsTableCompanion.insert(
                date: date,
                importedCount: importedCount,
                copiedCount: copiedCount,
                favoritedCount: favoritedCount,
                promptTokens: promptTokens,
                completionTokens: completionTokens,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserStatsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserStatsTableTable,
      UserStatsEntry,
      $$UserStatsTableTableFilterComposer,
      $$UserStatsTableTableOrderingComposer,
      $$UserStatsTableTableAnnotationComposer,
      $$UserStatsTableTableCreateCompanionBuilder,
      $$UserStatsTableTableUpdateCompanionBuilder,
      (
        UserStatsEntry,
        BaseReferences<_$AppDatabase, $UserStatsTableTable, UserStatsEntry>,
      ),
      UserStatsEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MemesTableTableTableManager get memesTable =>
      $$MemesTableTableTableManager(_db, _db.memesTable);
  $$TagsTableTableTableManager get tagsTable =>
      $$TagsTableTableTableManager(_db, _db.tagsTable);
  $$ColorsTableTableTableManager get colorsTable =>
      $$ColorsTableTableTableManager(_db, _db.colorsTable);
  $$EmbeddingsTableTableTableManager get embeddingsTable =>
      $$EmbeddingsTableTableTableManager(_db, _db.embeddingsTable);
  $$AnalysisQueueTableTableTableManager get analysisQueueTable =>
      $$AnalysisQueueTableTableTableManager(_db, _db.analysisQueueTable);
  $$SyncStateTableTableTableManager get syncStateTable =>
      $$SyncStateTableTableTableManager(_db, _db.syncStateTable);
  $$AlbumsTableTableTableManager get albumsTable =>
      $$AlbumsTableTableTableManager(_db, _db.albumsTable);
  $$MemeAlbumsTableTableTableManager get memeAlbumsTable =>
      $$MemeAlbumsTableTableTableManager(_db, _db.memeAlbumsTable);
  $$UserStatsTableTableTableManager get userStatsTable =>
      $$UserStatsTableTableTableManager(_db, _db.userStatsTable);
}
