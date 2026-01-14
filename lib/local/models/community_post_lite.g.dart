// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'community_post_lite.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetCommunityPostLiteCollection on Isar {
  IsarCollection<CommunityPostLite> get communityPostLites => this.collection();
}

const CommunityPostLiteSchema = CollectionSchema(
  name: r'CommunityPostLite',
  id: 722257314492252717,
  properties: {
    r'authorId': PropertySchema(
      id: 0,
      name: r'authorId',
      type: IsarType.string,
    ),
    r'authorName': PropertySchema(
      id: 1,
      name: r'authorName',
      type: IsarType.string,
    ),
    r'authorPhotoUrl': PropertySchema(
      id: 2,
      name: r'authorPhotoUrl',
      type: IsarType.string,
    ),
    r'bookmarkCount': PropertySchema(
      id: 3,
      name: r'bookmarkCount',
      type: IsarType.long,
    ),
    r'caption': PropertySchema(
      id: 4,
      name: r'caption',
      type: IsarType.string,
    ),
    r'commentCount': PropertySchema(
      id: 5,
      name: r'commentCount',
      type: IsarType.long,
    ),
    r'communityId': PropertySchema(
      id: 6,
      name: r'communityId',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 7,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'id': PropertySchema(
      id: 8,
      name: r'id',
      type: IsarType.string,
    ),
    r'likeCount': PropertySchema(
      id: 9,
      name: r'likeCount',
      type: IsarType.long,
    ),
    r'localUpdatedAt': PropertySchema(
      id: 10,
      name: r'localUpdatedAt',
      type: IsarType.dateTime,
    ),
    r'mediaThumbUrls': PropertySchema(
      id: 11,
      name: r'mediaThumbUrls',
      type: IsarType.stringList,
    ),
    r'mediaTypes': PropertySchema(
      id: 12,
      name: r'mediaTypes',
      type: IsarType.stringList,
    ),
    r'mediaUrls': PropertySchema(
      id: 13,
      name: r'mediaUrls',
      type: IsarType.stringList,
    ),
    r'repostCount': PropertySchema(
      id: 14,
      name: r'repostCount',
      type: IsarType.long,
    ),
    r'repostOf': PropertySchema(
      id: 15,
      name: r'repostOf',
      type: IsarType.string,
    ),
    r'shareCount': PropertySchema(
      id: 16,
      name: r'shareCount',
      type: IsarType.long,
    ),
    r'syncStatus': PropertySchema(
      id: 17,
      name: r'syncStatus',
      type: IsarType.string,
    ),
    r'updatedAt': PropertySchema(
      id: 18,
      name: r'updatedAt',
      type: IsarType.dateTime,
    )
  },
  estimateSize: _communityPostLiteEstimateSize,
  serialize: _communityPostLiteSerialize,
  deserialize: _communityPostLiteDeserialize,
  deserializeProp: _communityPostLiteDeserializeProp,
  idName: r'isarId',
  indexes: {
    r'id': IndexSchema(
      id: -3268401673993471357,
      name: r'id',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'id',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'communityId': IndexSchema(
      id: -8291877712508959585,
      name: r'communityId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'communityId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'createdAt': IndexSchema(
      id: -3433535483987302584,
      name: r'createdAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'createdAt',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'updatedAt': IndexSchema(
      id: -6238191080293565125,
      name: r'updatedAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'updatedAt',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'localUpdatedAt': IndexSchema(
      id: 7980285686227518886,
      name: r'localUpdatedAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'localUpdatedAt',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _communityPostLiteGetId,
  getLinks: _communityPostLiteGetLinks,
  attach: _communityPostLiteAttach,
  version: '3.1.0+1',
);

int _communityPostLiteEstimateSize(
  CommunityPostLite object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.authorId.length * 3;
  {
    final value = object.authorName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.authorPhotoUrl;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.caption;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.communityId.length * 3;
  bytesCount += 3 + object.id.length * 3;
  bytesCount += 3 + object.mediaThumbUrls.length * 3;
  {
    for (var i = 0; i < object.mediaThumbUrls.length; i++) {
      final value = object.mediaThumbUrls[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.mediaTypes.length * 3;
  {
    for (var i = 0; i < object.mediaTypes.length; i++) {
      final value = object.mediaTypes[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.mediaUrls.length * 3;
  {
    for (var i = 0; i < object.mediaUrls.length; i++) {
      final value = object.mediaUrls[i];
      bytesCount += value.length * 3;
    }
  }
  {
    final value = object.repostOf;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.syncStatus.length * 3;
  return bytesCount;
}

void _communityPostLiteSerialize(
  CommunityPostLite object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.authorId);
  writer.writeString(offsets[1], object.authorName);
  writer.writeString(offsets[2], object.authorPhotoUrl);
  writer.writeLong(offsets[3], object.bookmarkCount);
  writer.writeString(offsets[4], object.caption);
  writer.writeLong(offsets[5], object.commentCount);
  writer.writeString(offsets[6], object.communityId);
  writer.writeDateTime(offsets[7], object.createdAt);
  writer.writeString(offsets[8], object.id);
  writer.writeLong(offsets[9], object.likeCount);
  writer.writeDateTime(offsets[10], object.localUpdatedAt);
  writer.writeStringList(offsets[11], object.mediaThumbUrls);
  writer.writeStringList(offsets[12], object.mediaTypes);
  writer.writeStringList(offsets[13], object.mediaUrls);
  writer.writeLong(offsets[14], object.repostCount);
  writer.writeString(offsets[15], object.repostOf);
  writer.writeLong(offsets[16], object.shareCount);
  writer.writeString(offsets[17], object.syncStatus);
  writer.writeDateTime(offsets[18], object.updatedAt);
}

CommunityPostLite _communityPostLiteDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = CommunityPostLite();
  object.authorId = reader.readString(offsets[0]);
  object.authorName = reader.readStringOrNull(offsets[1]);
  object.authorPhotoUrl = reader.readStringOrNull(offsets[2]);
  object.bookmarkCount = reader.readLong(offsets[3]);
  object.caption = reader.readStringOrNull(offsets[4]);
  object.commentCount = reader.readLong(offsets[5]);
  object.communityId = reader.readString(offsets[6]);
  object.createdAt = reader.readDateTime(offsets[7]);
  object.id = reader.readString(offsets[8]);
  object.likeCount = reader.readLong(offsets[9]);
  object.localUpdatedAt = reader.readDateTime(offsets[10]);
  object.mediaThumbUrls = reader.readStringList(offsets[11]) ?? [];
  object.mediaTypes = reader.readStringList(offsets[12]) ?? [];
  object.mediaUrls = reader.readStringList(offsets[13]) ?? [];
  object.repostCount = reader.readLong(offsets[14]);
  object.repostOf = reader.readStringOrNull(offsets[15]);
  object.shareCount = reader.readLong(offsets[16]);
  object.syncStatus = reader.readString(offsets[17]);
  object.updatedAt = reader.readDateTimeOrNull(offsets[18]);
  return object;
}

P _communityPostLiteDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readDateTime(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readLong(offset)) as P;
    case 10:
      return (reader.readDateTime(offset)) as P;
    case 11:
      return (reader.readStringList(offset) ?? []) as P;
    case 12:
      return (reader.readStringList(offset) ?? []) as P;
    case 13:
      return (reader.readStringList(offset) ?? []) as P;
    case 14:
      return (reader.readLong(offset)) as P;
    case 15:
      return (reader.readStringOrNull(offset)) as P;
    case 16:
      return (reader.readLong(offset)) as P;
    case 17:
      return (reader.readString(offset)) as P;
    case 18:
      return (reader.readDateTimeOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _communityPostLiteGetId(CommunityPostLite object) {
  return object.isarId;
}

List<IsarLinkBase<dynamic>> _communityPostLiteGetLinks(
    CommunityPostLite object) {
  return [];
}

void _communityPostLiteAttach(
    IsarCollection<dynamic> col, Id id, CommunityPostLite object) {}

extension CommunityPostLiteByIndex on IsarCollection<CommunityPostLite> {
  Future<CommunityPostLite?> getById(String id) {
    return getByIndex(r'id', [id]);
  }

  CommunityPostLite? getByIdSync(String id) {
    return getByIndexSync(r'id', [id]);
  }

  Future<bool> deleteById(String id) {
    return deleteByIndex(r'id', [id]);
  }

  bool deleteByIdSync(String id) {
    return deleteByIndexSync(r'id', [id]);
  }

  Future<List<CommunityPostLite?>> getAllById(List<String> idValues) {
    final values = idValues.map((e) => [e]).toList();
    return getAllByIndex(r'id', values);
  }

  List<CommunityPostLite?> getAllByIdSync(List<String> idValues) {
    final values = idValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'id', values);
  }

  Future<int> deleteAllById(List<String> idValues) {
    final values = idValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'id', values);
  }

  int deleteAllByIdSync(List<String> idValues) {
    final values = idValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'id', values);
  }

  Future<Id> putById(CommunityPostLite object) {
    return putByIndex(r'id', object);
  }

  Id putByIdSync(CommunityPostLite object, {bool saveLinks = true}) {
    return putByIndexSync(r'id', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllById(List<CommunityPostLite> objects) {
    return putAllByIndex(r'id', objects);
  }

  List<Id> putAllByIdSync(List<CommunityPostLite> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'id', objects, saveLinks: saveLinks);
  }
}

extension CommunityPostLiteQueryWhereSort
    on QueryBuilder<CommunityPostLite, CommunityPostLite, QWhere> {
  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterWhere> anyIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterWhere>
      anyCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'createdAt'),
      );
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterWhere>
      anyUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'updatedAt'),
      );
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterWhere>
      anyLocalUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'localUpdatedAt'),
      );
    });
  }
}

extension CommunityPostLiteQueryWhere
    on QueryBuilder<CommunityPostLite, CommunityPostLite, QWhereClause> {
  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterWhereClause>
      isarIdEqualTo(Id isarId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: isarId,
        upper: isarId,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterWhereClause>
      isarIdNotEqualTo(Id isarId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: isarId, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: isarId, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: isarId, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: isarId, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterWhereClause>
      isarIdGreaterThan(Id isarId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: isarId, includeLower: include),
      );
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterWhereClause>
      isarIdLessThan(Id isarId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: isarId, includeUpper: include),
      );
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterWhereClause>
      isarIdBetween(
    Id lowerIsarId,
    Id upperIsarId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerIsarId,
        includeLower: includeLower,
        upper: upperIsarId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterWhereClause>
      idEqualTo(String id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'id',
        value: [id],
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterWhereClause>
      idNotEqualTo(String id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'id',
              lower: [],
              upper: [id],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'id',
              lower: [id],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'id',
              lower: [id],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'id',
              lower: [],
              upper: [id],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterWhereClause>
      communityIdEqualTo(String communityId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'communityId',
        value: [communityId],
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterWhereClause>
      communityIdNotEqualTo(String communityId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'communityId',
              lower: [],
              upper: [communityId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'communityId',
              lower: [communityId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'communityId',
              lower: [communityId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'communityId',
              lower: [],
              upper: [communityId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterWhereClause>
      createdAtEqualTo(DateTime createdAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'createdAt',
        value: [createdAt],
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterWhereClause>
      createdAtNotEqualTo(DateTime createdAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAt',
              lower: [],
              upper: [createdAt],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAt',
              lower: [createdAt],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAt',
              lower: [createdAt],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAt',
              lower: [],
              upper: [createdAt],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterWhereClause>
      createdAtGreaterThan(
    DateTime createdAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'createdAt',
        lower: [createdAt],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterWhereClause>
      createdAtLessThan(
    DateTime createdAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'createdAt',
        lower: [],
        upper: [createdAt],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterWhereClause>
      createdAtBetween(
    DateTime lowerCreatedAt,
    DateTime upperCreatedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'createdAt',
        lower: [lowerCreatedAt],
        includeLower: includeLower,
        upper: [upperCreatedAt],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterWhereClause>
      updatedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'updatedAt',
        value: [null],
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterWhereClause>
      updatedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'updatedAt',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterWhereClause>
      updatedAtEqualTo(DateTime? updatedAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'updatedAt',
        value: [updatedAt],
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterWhereClause>
      updatedAtNotEqualTo(DateTime? updatedAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'updatedAt',
              lower: [],
              upper: [updatedAt],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'updatedAt',
              lower: [updatedAt],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'updatedAt',
              lower: [updatedAt],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'updatedAt',
              lower: [],
              upper: [updatedAt],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterWhereClause>
      updatedAtGreaterThan(
    DateTime? updatedAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'updatedAt',
        lower: [updatedAt],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterWhereClause>
      updatedAtLessThan(
    DateTime? updatedAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'updatedAt',
        lower: [],
        upper: [updatedAt],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterWhereClause>
      updatedAtBetween(
    DateTime? lowerUpdatedAt,
    DateTime? upperUpdatedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'updatedAt',
        lower: [lowerUpdatedAt],
        includeLower: includeLower,
        upper: [upperUpdatedAt],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterWhereClause>
      localUpdatedAtEqualTo(DateTime localUpdatedAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'localUpdatedAt',
        value: [localUpdatedAt],
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterWhereClause>
      localUpdatedAtNotEqualTo(DateTime localUpdatedAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'localUpdatedAt',
              lower: [],
              upper: [localUpdatedAt],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'localUpdatedAt',
              lower: [localUpdatedAt],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'localUpdatedAt',
              lower: [localUpdatedAt],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'localUpdatedAt',
              lower: [],
              upper: [localUpdatedAt],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterWhereClause>
      localUpdatedAtGreaterThan(
    DateTime localUpdatedAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'localUpdatedAt',
        lower: [localUpdatedAt],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterWhereClause>
      localUpdatedAtLessThan(
    DateTime localUpdatedAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'localUpdatedAt',
        lower: [],
        upper: [localUpdatedAt],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterWhereClause>
      localUpdatedAtBetween(
    DateTime lowerLocalUpdatedAt,
    DateTime upperLocalUpdatedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'localUpdatedAt',
        lower: [lowerLocalUpdatedAt],
        includeLower: includeLower,
        upper: [upperLocalUpdatedAt],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension CommunityPostLiteQueryFilter
    on QueryBuilder<CommunityPostLite, CommunityPostLite, QFilterCondition> {
  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      authorIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'authorId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      authorIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'authorId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      authorIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'authorId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      authorIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'authorId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      authorIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'authorId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      authorIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'authorId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      authorIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'authorId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      authorIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'authorId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      authorIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'authorId',
        value: '',
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      authorIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'authorId',
        value: '',
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      authorNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'authorName',
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      authorNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'authorName',
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      authorNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'authorName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      authorNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'authorName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      authorNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'authorName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      authorNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'authorName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      authorNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'authorName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      authorNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'authorName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      authorNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'authorName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      authorNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'authorName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      authorNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'authorName',
        value: '',
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      authorNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'authorName',
        value: '',
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      authorPhotoUrlIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'authorPhotoUrl',
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      authorPhotoUrlIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'authorPhotoUrl',
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      authorPhotoUrlEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'authorPhotoUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      authorPhotoUrlGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'authorPhotoUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      authorPhotoUrlLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'authorPhotoUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      authorPhotoUrlBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'authorPhotoUrl',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      authorPhotoUrlStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'authorPhotoUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      authorPhotoUrlEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'authorPhotoUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      authorPhotoUrlContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'authorPhotoUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      authorPhotoUrlMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'authorPhotoUrl',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      authorPhotoUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'authorPhotoUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      authorPhotoUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'authorPhotoUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      bookmarkCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'bookmarkCount',
        value: value,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      bookmarkCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'bookmarkCount',
        value: value,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      bookmarkCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'bookmarkCount',
        value: value,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      bookmarkCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'bookmarkCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      captionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'caption',
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      captionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'caption',
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      captionEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'caption',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      captionGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'caption',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      captionLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'caption',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      captionBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'caption',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      captionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'caption',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      captionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'caption',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      captionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'caption',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      captionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'caption',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      captionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'caption',
        value: '',
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      captionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'caption',
        value: '',
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      commentCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'commentCount',
        value: value,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      commentCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'commentCount',
        value: value,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      commentCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'commentCount',
        value: value,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      commentCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'commentCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      communityIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'communityId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      communityIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'communityId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      communityIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'communityId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      communityIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'communityId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      communityIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'communityId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      communityIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'communityId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      communityIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'communityId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      communityIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'communityId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      communityIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'communityId',
        value: '',
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      communityIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'communityId',
        value: '',
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      createdAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      idEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      idGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      idLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      idBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      idStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      idEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      idContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      idMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'id',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      idIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: '',
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      idIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'id',
        value: '',
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      isarIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isarId',
        value: value,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      isarIdGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'isarId',
        value: value,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      isarIdLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'isarId',
        value: value,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      isarIdBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'isarId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      likeCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'likeCount',
        value: value,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      likeCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'likeCount',
        value: value,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      likeCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'likeCount',
        value: value,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      likeCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'likeCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      localUpdatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'localUpdatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      localUpdatedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'localUpdatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      localUpdatedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'localUpdatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      localUpdatedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'localUpdatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaThumbUrlsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'mediaThumbUrls',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaThumbUrlsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'mediaThumbUrls',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaThumbUrlsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'mediaThumbUrls',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaThumbUrlsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'mediaThumbUrls',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaThumbUrlsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'mediaThumbUrls',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaThumbUrlsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'mediaThumbUrls',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaThumbUrlsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'mediaThumbUrls',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaThumbUrlsElementMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'mediaThumbUrls',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaThumbUrlsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'mediaThumbUrls',
        value: '',
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaThumbUrlsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'mediaThumbUrls',
        value: '',
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaThumbUrlsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'mediaThumbUrls',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaThumbUrlsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'mediaThumbUrls',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaThumbUrlsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'mediaThumbUrls',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaThumbUrlsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'mediaThumbUrls',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaThumbUrlsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'mediaThumbUrls',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaThumbUrlsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'mediaThumbUrls',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaTypesElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'mediaTypes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaTypesElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'mediaTypes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaTypesElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'mediaTypes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaTypesElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'mediaTypes',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaTypesElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'mediaTypes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaTypesElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'mediaTypes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaTypesElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'mediaTypes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaTypesElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'mediaTypes',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaTypesElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'mediaTypes',
        value: '',
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaTypesElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'mediaTypes',
        value: '',
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaTypesLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'mediaTypes',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaTypesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'mediaTypes',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaTypesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'mediaTypes',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaTypesLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'mediaTypes',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaTypesLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'mediaTypes',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaTypesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'mediaTypes',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaUrlsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'mediaUrls',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaUrlsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'mediaUrls',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaUrlsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'mediaUrls',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaUrlsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'mediaUrls',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaUrlsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'mediaUrls',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaUrlsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'mediaUrls',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaUrlsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'mediaUrls',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaUrlsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'mediaUrls',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaUrlsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'mediaUrls',
        value: '',
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaUrlsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'mediaUrls',
        value: '',
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaUrlsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'mediaUrls',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaUrlsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'mediaUrls',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaUrlsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'mediaUrls',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaUrlsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'mediaUrls',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaUrlsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'mediaUrls',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      mediaUrlsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'mediaUrls',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      repostCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'repostCount',
        value: value,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      repostCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'repostCount',
        value: value,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      repostCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'repostCount',
        value: value,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      repostCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'repostCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      repostOfIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'repostOf',
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      repostOfIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'repostOf',
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      repostOfEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'repostOf',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      repostOfGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'repostOf',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      repostOfLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'repostOf',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      repostOfBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'repostOf',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      repostOfStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'repostOf',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      repostOfEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'repostOf',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      repostOfContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'repostOf',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      repostOfMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'repostOf',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      repostOfIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'repostOf',
        value: '',
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      repostOfIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'repostOf',
        value: '',
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      shareCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'shareCount',
        value: value,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      shareCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'shareCount',
        value: value,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      shareCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'shareCount',
        value: value,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      shareCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'shareCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      syncStatusEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'syncStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      syncStatusGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'syncStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      syncStatusLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'syncStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      syncStatusBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'syncStatus',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      syncStatusStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'syncStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      syncStatusEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'syncStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      syncStatusContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'syncStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      syncStatusMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'syncStatus',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      syncStatusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'syncStatus',
        value: '',
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      syncStatusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'syncStatus',
        value: '',
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      updatedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'updatedAt',
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      updatedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'updatedAt',
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      updatedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      updatedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      updatedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterFilterCondition>
      updatedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension CommunityPostLiteQueryObject
    on QueryBuilder<CommunityPostLite, CommunityPostLite, QFilterCondition> {}

extension CommunityPostLiteQueryLinks
    on QueryBuilder<CommunityPostLite, CommunityPostLite, QFilterCondition> {}

extension CommunityPostLiteQuerySortBy
    on QueryBuilder<CommunityPostLite, CommunityPostLite, QSortBy> {
  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      sortByAuthorId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authorId', Sort.asc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      sortByAuthorIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authorId', Sort.desc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      sortByAuthorName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authorName', Sort.asc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      sortByAuthorNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authorName', Sort.desc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      sortByAuthorPhotoUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authorPhotoUrl', Sort.asc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      sortByAuthorPhotoUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authorPhotoUrl', Sort.desc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      sortByBookmarkCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bookmarkCount', Sort.asc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      sortByBookmarkCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bookmarkCount', Sort.desc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      sortByCaption() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'caption', Sort.asc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      sortByCaptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'caption', Sort.desc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      sortByCommentCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'commentCount', Sort.asc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      sortByCommentCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'commentCount', Sort.desc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      sortByCommunityId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'communityId', Sort.asc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      sortByCommunityIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'communityId', Sort.desc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy> sortById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      sortByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      sortByLikeCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'likeCount', Sort.asc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      sortByLikeCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'likeCount', Sort.desc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      sortByLocalUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localUpdatedAt', Sort.asc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      sortByLocalUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localUpdatedAt', Sort.desc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      sortByRepostCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'repostCount', Sort.asc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      sortByRepostCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'repostCount', Sort.desc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      sortByRepostOf() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'repostOf', Sort.asc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      sortByRepostOfDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'repostOf', Sort.desc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      sortByShareCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'shareCount', Sort.asc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      sortByShareCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'shareCount', Sort.desc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      sortBySyncStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncStatus', Sort.asc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      sortBySyncStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncStatus', Sort.desc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension CommunityPostLiteQuerySortThenBy
    on QueryBuilder<CommunityPostLite, CommunityPostLite, QSortThenBy> {
  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      thenByAuthorId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authorId', Sort.asc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      thenByAuthorIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authorId', Sort.desc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      thenByAuthorName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authorName', Sort.asc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      thenByAuthorNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authorName', Sort.desc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      thenByAuthorPhotoUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authorPhotoUrl', Sort.asc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      thenByAuthorPhotoUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authorPhotoUrl', Sort.desc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      thenByBookmarkCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bookmarkCount', Sort.asc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      thenByBookmarkCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bookmarkCount', Sort.desc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      thenByCaption() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'caption', Sort.asc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      thenByCaptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'caption', Sort.desc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      thenByCommentCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'commentCount', Sort.asc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      thenByCommentCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'commentCount', Sort.desc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      thenByCommunityId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'communityId', Sort.asc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      thenByCommunityIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'communityId', Sort.desc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      thenByIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.asc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      thenByIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.desc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      thenByLikeCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'likeCount', Sort.asc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      thenByLikeCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'likeCount', Sort.desc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      thenByLocalUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localUpdatedAt', Sort.asc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      thenByLocalUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localUpdatedAt', Sort.desc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      thenByRepostCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'repostCount', Sort.asc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      thenByRepostCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'repostCount', Sort.desc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      thenByRepostOf() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'repostOf', Sort.asc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      thenByRepostOfDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'repostOf', Sort.desc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      thenByShareCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'shareCount', Sort.asc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      thenByShareCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'shareCount', Sort.desc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      thenBySyncStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncStatus', Sort.asc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      thenBySyncStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncStatus', Sort.desc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QAfterSortBy>
      thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension CommunityPostLiteQueryWhereDistinct
    on QueryBuilder<CommunityPostLite, CommunityPostLite, QDistinct> {
  QueryBuilder<CommunityPostLite, CommunityPostLite, QDistinct>
      distinctByAuthorId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'authorId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QDistinct>
      distinctByAuthorName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'authorName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QDistinct>
      distinctByAuthorPhotoUrl({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'authorPhotoUrl',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QDistinct>
      distinctByBookmarkCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'bookmarkCount');
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QDistinct>
      distinctByCaption({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'caption', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QDistinct>
      distinctByCommentCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'commentCount');
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QDistinct>
      distinctByCommunityId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'communityId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QDistinct> distinctById(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QDistinct>
      distinctByLikeCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'likeCount');
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QDistinct>
      distinctByLocalUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'localUpdatedAt');
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QDistinct>
      distinctByMediaThumbUrls() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'mediaThumbUrls');
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QDistinct>
      distinctByMediaTypes() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'mediaTypes');
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QDistinct>
      distinctByMediaUrls() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'mediaUrls');
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QDistinct>
      distinctByRepostCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'repostCount');
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QDistinct>
      distinctByRepostOf({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'repostOf', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QDistinct>
      distinctByShareCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'shareCount');
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QDistinct>
      distinctBySyncStatus({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'syncStatus', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CommunityPostLite, CommunityPostLite, QDistinct>
      distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension CommunityPostLiteQueryProperty
    on QueryBuilder<CommunityPostLite, CommunityPostLite, QQueryProperty> {
  QueryBuilder<CommunityPostLite, int, QQueryOperations> isarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isarId');
    });
  }

  QueryBuilder<CommunityPostLite, String, QQueryOperations> authorIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'authorId');
    });
  }

  QueryBuilder<CommunityPostLite, String?, QQueryOperations>
      authorNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'authorName');
    });
  }

  QueryBuilder<CommunityPostLite, String?, QQueryOperations>
      authorPhotoUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'authorPhotoUrl');
    });
  }

  QueryBuilder<CommunityPostLite, int, QQueryOperations>
      bookmarkCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'bookmarkCount');
    });
  }

  QueryBuilder<CommunityPostLite, String?, QQueryOperations> captionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'caption');
    });
  }

  QueryBuilder<CommunityPostLite, int, QQueryOperations>
      commentCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'commentCount');
    });
  }

  QueryBuilder<CommunityPostLite, String, QQueryOperations>
      communityIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'communityId');
    });
  }

  QueryBuilder<CommunityPostLite, DateTime, QQueryOperations>
      createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<CommunityPostLite, String, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<CommunityPostLite, int, QQueryOperations> likeCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'likeCount');
    });
  }

  QueryBuilder<CommunityPostLite, DateTime, QQueryOperations>
      localUpdatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'localUpdatedAt');
    });
  }

  QueryBuilder<CommunityPostLite, List<String>, QQueryOperations>
      mediaThumbUrlsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'mediaThumbUrls');
    });
  }

  QueryBuilder<CommunityPostLite, List<String>, QQueryOperations>
      mediaTypesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'mediaTypes');
    });
  }

  QueryBuilder<CommunityPostLite, List<String>, QQueryOperations>
      mediaUrlsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'mediaUrls');
    });
  }

  QueryBuilder<CommunityPostLite, int, QQueryOperations> repostCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'repostCount');
    });
  }

  QueryBuilder<CommunityPostLite, String?, QQueryOperations>
      repostOfProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'repostOf');
    });
  }

  QueryBuilder<CommunityPostLite, int, QQueryOperations> shareCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'shareCount');
    });
  }

  QueryBuilder<CommunityPostLite, String, QQueryOperations>
      syncStatusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'syncStatus');
    });
  }

  QueryBuilder<CommunityPostLite, DateTime?, QQueryOperations>
      updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}
