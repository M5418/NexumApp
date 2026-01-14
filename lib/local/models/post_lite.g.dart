// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post_lite.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetPostLiteCollection on Isar {
  IsarCollection<PostLite> get postLites => this.collection();
}

const PostLiteSchema = CollectionSchema(
  name: r'PostLite',
  id: 8023845464095178335,
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
    r'repostAuthorId': PropertySchema(
      id: 14,
      name: r'repostAuthorId',
      type: IsarType.string,
    ),
    r'repostAuthorName': PropertySchema(
      id: 15,
      name: r'repostAuthorName',
      type: IsarType.string,
    ),
    r'repostCount': PropertySchema(
      id: 16,
      name: r'repostCount',
      type: IsarType.long,
    ),
    r'repostOf': PropertySchema(
      id: 17,
      name: r'repostOf',
      type: IsarType.string,
    ),
    r'shareCount': PropertySchema(
      id: 18,
      name: r'shareCount',
      type: IsarType.long,
    ),
    r'syncStatus': PropertySchema(
      id: 19,
      name: r'syncStatus',
      type: IsarType.string,
    ),
    r'updatedAt': PropertySchema(
      id: 20,
      name: r'updatedAt',
      type: IsarType.dateTime,
    )
  },
  estimateSize: _postLiteEstimateSize,
  serialize: _postLiteSerialize,
  deserialize: _postLiteDeserialize,
  deserializeProp: _postLiteDeserializeProp,
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
    ),
    r'syncStatus': IndexSchema(
      id: 8239539375045684509,
      name: r'syncStatus',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'syncStatus',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _postLiteGetId,
  getLinks: _postLiteGetLinks,
  attach: _postLiteAttach,
  version: '3.1.0+1',
);

int _postLiteEstimateSize(
  PostLite object,
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
  {
    final value = object.communityId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
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
    final value = object.repostAuthorId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.repostAuthorName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
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

void _postLiteSerialize(
  PostLite object,
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
  writer.writeString(offsets[14], object.repostAuthorId);
  writer.writeString(offsets[15], object.repostAuthorName);
  writer.writeLong(offsets[16], object.repostCount);
  writer.writeString(offsets[17], object.repostOf);
  writer.writeLong(offsets[18], object.shareCount);
  writer.writeString(offsets[19], object.syncStatus);
  writer.writeDateTime(offsets[20], object.updatedAt);
}

PostLite _postLiteDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = PostLite();
  object.authorId = reader.readString(offsets[0]);
  object.authorName = reader.readStringOrNull(offsets[1]);
  object.authorPhotoUrl = reader.readStringOrNull(offsets[2]);
  object.bookmarkCount = reader.readLong(offsets[3]);
  object.caption = reader.readStringOrNull(offsets[4]);
  object.commentCount = reader.readLong(offsets[5]);
  object.communityId = reader.readStringOrNull(offsets[6]);
  object.createdAt = reader.readDateTime(offsets[7]);
  object.id = reader.readString(offsets[8]);
  object.likeCount = reader.readLong(offsets[9]);
  object.localUpdatedAt = reader.readDateTime(offsets[10]);
  object.mediaThumbUrls = reader.readStringList(offsets[11]) ?? [];
  object.mediaTypes = reader.readStringList(offsets[12]) ?? [];
  object.mediaUrls = reader.readStringList(offsets[13]) ?? [];
  object.repostAuthorId = reader.readStringOrNull(offsets[14]);
  object.repostAuthorName = reader.readStringOrNull(offsets[15]);
  object.repostCount = reader.readLong(offsets[16]);
  object.repostOf = reader.readStringOrNull(offsets[17]);
  object.shareCount = reader.readLong(offsets[18]);
  object.syncStatus = reader.readString(offsets[19]);
  object.updatedAt = reader.readDateTimeOrNull(offsets[20]);
  return object;
}

P _postLiteDeserializeProp<P>(
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
      return (reader.readStringOrNull(offset)) as P;
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
      return (reader.readStringOrNull(offset)) as P;
    case 15:
      return (reader.readStringOrNull(offset)) as P;
    case 16:
      return (reader.readLong(offset)) as P;
    case 17:
      return (reader.readStringOrNull(offset)) as P;
    case 18:
      return (reader.readLong(offset)) as P;
    case 19:
      return (reader.readString(offset)) as P;
    case 20:
      return (reader.readDateTimeOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _postLiteGetId(PostLite object) {
  return object.isarId;
}

List<IsarLinkBase<dynamic>> _postLiteGetLinks(PostLite object) {
  return [];
}

void _postLiteAttach(IsarCollection<dynamic> col, Id id, PostLite object) {}

extension PostLiteByIndex on IsarCollection<PostLite> {
  Future<PostLite?> getById(String id) {
    return getByIndex(r'id', [id]);
  }

  PostLite? getByIdSync(String id) {
    return getByIndexSync(r'id', [id]);
  }

  Future<bool> deleteById(String id) {
    return deleteByIndex(r'id', [id]);
  }

  bool deleteByIdSync(String id) {
    return deleteByIndexSync(r'id', [id]);
  }

  Future<List<PostLite?>> getAllById(List<String> idValues) {
    final values = idValues.map((e) => [e]).toList();
    return getAllByIndex(r'id', values);
  }

  List<PostLite?> getAllByIdSync(List<String> idValues) {
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

  Future<Id> putById(PostLite object) {
    return putByIndex(r'id', object);
  }

  Id putByIdSync(PostLite object, {bool saveLinks = true}) {
    return putByIndexSync(r'id', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllById(List<PostLite> objects) {
    return putAllByIndex(r'id', objects);
  }

  List<Id> putAllByIdSync(List<PostLite> objects, {bool saveLinks = true}) {
    return putAllByIndexSync(r'id', objects, saveLinks: saveLinks);
  }
}

extension PostLiteQueryWhereSort on QueryBuilder<PostLite, PostLite, QWhere> {
  QueryBuilder<PostLite, PostLite, QAfterWhere> anyIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterWhere> anyCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'createdAt'),
      );
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterWhere> anyUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'updatedAt'),
      );
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterWhere> anyLocalUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'localUpdatedAt'),
      );
    });
  }
}

extension PostLiteQueryWhere on QueryBuilder<PostLite, PostLite, QWhereClause> {
  QueryBuilder<PostLite, PostLite, QAfterWhereClause> isarIdEqualTo(Id isarId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: isarId,
        upper: isarId,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterWhereClause> isarIdNotEqualTo(
      Id isarId) {
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

  QueryBuilder<PostLite, PostLite, QAfterWhereClause> isarIdGreaterThan(
      Id isarId,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: isarId, includeLower: include),
      );
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterWhereClause> isarIdLessThan(Id isarId,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: isarId, includeUpper: include),
      );
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterWhereClause> isarIdBetween(
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

  QueryBuilder<PostLite, PostLite, QAfterWhereClause> idEqualTo(String id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'id',
        value: [id],
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterWhereClause> idNotEqualTo(String id) {
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

  QueryBuilder<PostLite, PostLite, QAfterWhereClause> createdAtEqualTo(
      DateTime createdAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'createdAt',
        value: [createdAt],
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterWhereClause> createdAtNotEqualTo(
      DateTime createdAt) {
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

  QueryBuilder<PostLite, PostLite, QAfterWhereClause> createdAtGreaterThan(
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

  QueryBuilder<PostLite, PostLite, QAfterWhereClause> createdAtLessThan(
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

  QueryBuilder<PostLite, PostLite, QAfterWhereClause> createdAtBetween(
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

  QueryBuilder<PostLite, PostLite, QAfterWhereClause> updatedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'updatedAt',
        value: [null],
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterWhereClause> updatedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'updatedAt',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterWhereClause> updatedAtEqualTo(
      DateTime? updatedAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'updatedAt',
        value: [updatedAt],
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterWhereClause> updatedAtNotEqualTo(
      DateTime? updatedAt) {
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

  QueryBuilder<PostLite, PostLite, QAfterWhereClause> updatedAtGreaterThan(
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

  QueryBuilder<PostLite, PostLite, QAfterWhereClause> updatedAtLessThan(
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

  QueryBuilder<PostLite, PostLite, QAfterWhereClause> updatedAtBetween(
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

  QueryBuilder<PostLite, PostLite, QAfterWhereClause> localUpdatedAtEqualTo(
      DateTime localUpdatedAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'localUpdatedAt',
        value: [localUpdatedAt],
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterWhereClause> localUpdatedAtNotEqualTo(
      DateTime localUpdatedAt) {
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

  QueryBuilder<PostLite, PostLite, QAfterWhereClause> localUpdatedAtGreaterThan(
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

  QueryBuilder<PostLite, PostLite, QAfterWhereClause> localUpdatedAtLessThan(
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

  QueryBuilder<PostLite, PostLite, QAfterWhereClause> localUpdatedAtBetween(
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

  QueryBuilder<PostLite, PostLite, QAfterWhereClause> syncStatusEqualTo(
      String syncStatus) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'syncStatus',
        value: [syncStatus],
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterWhereClause> syncStatusNotEqualTo(
      String syncStatus) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'syncStatus',
              lower: [],
              upper: [syncStatus],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'syncStatus',
              lower: [syncStatus],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'syncStatus',
              lower: [syncStatus],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'syncStatus',
              lower: [],
              upper: [syncStatus],
              includeUpper: false,
            ));
      }
    });
  }
}

extension PostLiteQueryFilter
    on QueryBuilder<PostLite, PostLite, QFilterCondition> {
  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> authorIdEqualTo(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> authorIdGreaterThan(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> authorIdLessThan(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> authorIdBetween(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> authorIdStartsWith(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> authorIdEndsWith(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> authorIdContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'authorId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> authorIdMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'authorId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> authorIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'authorId',
        value: '',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> authorIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'authorId',
        value: '',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> authorNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'authorName',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      authorNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'authorName',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> authorNameEqualTo(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> authorNameGreaterThan(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> authorNameLessThan(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> authorNameBetween(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> authorNameStartsWith(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> authorNameEndsWith(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> authorNameContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'authorName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> authorNameMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'authorName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> authorNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'authorName',
        value: '',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      authorNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'authorName',
        value: '',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      authorPhotoUrlIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'authorPhotoUrl',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      authorPhotoUrlIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'authorPhotoUrl',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> authorPhotoUrlEqualTo(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> authorPhotoUrlBetween(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      authorPhotoUrlContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'authorPhotoUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> authorPhotoUrlMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'authorPhotoUrl',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      authorPhotoUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'authorPhotoUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      authorPhotoUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'authorPhotoUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> bookmarkCountEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'bookmarkCount',
        value: value,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> bookmarkCountLessThan(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> bookmarkCountBetween(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> captionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'caption',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> captionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'caption',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> captionEqualTo(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> captionGreaterThan(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> captionLessThan(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> captionBetween(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> captionStartsWith(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> captionEndsWith(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> captionContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'caption',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> captionMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'caption',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> captionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'caption',
        value: '',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> captionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'caption',
        value: '',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> commentCountEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'commentCount',
        value: value,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> commentCountLessThan(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> commentCountBetween(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> communityIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'communityId',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      communityIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'communityId',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> communityIdEqualTo(
    String? value, {
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      communityIdGreaterThan(
    String? value, {
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> communityIdLessThan(
    String? value, {
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> communityIdBetween(
    String? lower,
    String? upper, {
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> communityIdStartsWith(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> communityIdEndsWith(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> communityIdContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'communityId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> communityIdMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'communityId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> communityIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'communityId',
        value: '',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      communityIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'communityId',
        value: '',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> createdAtEqualTo(
      DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> createdAtGreaterThan(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> createdAtLessThan(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> createdAtBetween(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> idEqualTo(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> idBetween(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> idStartsWith(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> idEndsWith(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> idContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> idMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'id',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> idIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: '',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> idIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'id',
        value: '',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> isarIdEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isarId',
        value: value,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> isarIdGreaterThan(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> isarIdLessThan(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> isarIdBetween(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> likeCountEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'likeCount',
        value: value,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> likeCountGreaterThan(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> likeCountLessThan(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> likeCountBetween(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> localUpdatedAtEqualTo(
      DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'localUpdatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> localUpdatedAtBetween(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      mediaThumbUrlsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'mediaThumbUrls',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      mediaThumbUrlsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'mediaThumbUrls',
        value: '',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      mediaThumbUrlsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'mediaThumbUrls',
        value: '',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      mediaTypesElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'mediaTypes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      mediaTypesElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'mediaTypes',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      mediaTypesElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'mediaTypes',
        value: '',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      mediaTypesElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'mediaTypes',
        value: '',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> mediaTypesIsEmpty() {
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      mediaUrlsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'mediaUrls',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      mediaUrlsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'mediaUrls',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      mediaUrlsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'mediaUrls',
        value: '',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      mediaUrlsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'mediaUrls',
        value: '',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> mediaUrlsIsEmpty() {
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      repostAuthorIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'repostAuthorId',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      repostAuthorIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'repostAuthorId',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> repostAuthorIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'repostAuthorId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      repostAuthorIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'repostAuthorId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      repostAuthorIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'repostAuthorId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> repostAuthorIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'repostAuthorId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      repostAuthorIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'repostAuthorId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      repostAuthorIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'repostAuthorId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      repostAuthorIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'repostAuthorId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> repostAuthorIdMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'repostAuthorId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      repostAuthorIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'repostAuthorId',
        value: '',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      repostAuthorIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'repostAuthorId',
        value: '',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      repostAuthorNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'repostAuthorName',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      repostAuthorNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'repostAuthorName',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      repostAuthorNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'repostAuthorName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      repostAuthorNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'repostAuthorName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      repostAuthorNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'repostAuthorName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      repostAuthorNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'repostAuthorName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      repostAuthorNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'repostAuthorName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      repostAuthorNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'repostAuthorName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      repostAuthorNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'repostAuthorName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      repostAuthorNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'repostAuthorName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      repostAuthorNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'repostAuthorName',
        value: '',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      repostAuthorNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'repostAuthorName',
        value: '',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> repostCountEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'repostCount',
        value: value,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> repostCountLessThan(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> repostCountBetween(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> repostOfIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'repostOf',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> repostOfIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'repostOf',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> repostOfEqualTo(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> repostOfGreaterThan(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> repostOfLessThan(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> repostOfBetween(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> repostOfStartsWith(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> repostOfEndsWith(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> repostOfContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'repostOf',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> repostOfMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'repostOf',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> repostOfIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'repostOf',
        value: '',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> repostOfIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'repostOf',
        value: '',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> shareCountEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'shareCount',
        value: value,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> shareCountGreaterThan(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> shareCountLessThan(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> shareCountBetween(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> syncStatusEqualTo(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> syncStatusGreaterThan(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> syncStatusLessThan(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> syncStatusBetween(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> syncStatusStartsWith(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> syncStatusEndsWith(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> syncStatusContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'syncStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> syncStatusMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'syncStatus',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> syncStatusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'syncStatus',
        value: '',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition>
      syncStatusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'syncStatus',
        value: '',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> updatedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'updatedAt',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> updatedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'updatedAt',
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> updatedAtEqualTo(
      DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> updatedAtGreaterThan(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> updatedAtLessThan(
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

  QueryBuilder<PostLite, PostLite, QAfterFilterCondition> updatedAtBetween(
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

extension PostLiteQueryObject
    on QueryBuilder<PostLite, PostLite, QFilterCondition> {}

extension PostLiteQueryLinks
    on QueryBuilder<PostLite, PostLite, QFilterCondition> {}

extension PostLiteQuerySortBy on QueryBuilder<PostLite, PostLite, QSortBy> {
  QueryBuilder<PostLite, PostLite, QAfterSortBy> sortByAuthorId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authorId', Sort.asc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> sortByAuthorIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authorId', Sort.desc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> sortByAuthorName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authorName', Sort.asc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> sortByAuthorNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authorName', Sort.desc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> sortByAuthorPhotoUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authorPhotoUrl', Sort.asc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> sortByAuthorPhotoUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authorPhotoUrl', Sort.desc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> sortByBookmarkCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bookmarkCount', Sort.asc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> sortByBookmarkCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bookmarkCount', Sort.desc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> sortByCaption() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'caption', Sort.asc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> sortByCaptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'caption', Sort.desc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> sortByCommentCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'commentCount', Sort.asc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> sortByCommentCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'commentCount', Sort.desc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> sortByCommunityId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'communityId', Sort.asc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> sortByCommunityIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'communityId', Sort.desc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> sortById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> sortByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> sortByLikeCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'likeCount', Sort.asc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> sortByLikeCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'likeCount', Sort.desc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> sortByLocalUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localUpdatedAt', Sort.asc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> sortByLocalUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localUpdatedAt', Sort.desc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> sortByRepostAuthorId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'repostAuthorId', Sort.asc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> sortByRepostAuthorIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'repostAuthorId', Sort.desc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> sortByRepostAuthorName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'repostAuthorName', Sort.asc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> sortByRepostAuthorNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'repostAuthorName', Sort.desc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> sortByRepostCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'repostCount', Sort.asc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> sortByRepostCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'repostCount', Sort.desc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> sortByRepostOf() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'repostOf', Sort.asc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> sortByRepostOfDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'repostOf', Sort.desc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> sortByShareCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'shareCount', Sort.asc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> sortByShareCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'shareCount', Sort.desc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> sortBySyncStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncStatus', Sort.asc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> sortBySyncStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncStatus', Sort.desc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension PostLiteQuerySortThenBy
    on QueryBuilder<PostLite, PostLite, QSortThenBy> {
  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenByAuthorId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authorId', Sort.asc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenByAuthorIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authorId', Sort.desc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenByAuthorName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authorName', Sort.asc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenByAuthorNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authorName', Sort.desc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenByAuthorPhotoUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authorPhotoUrl', Sort.asc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenByAuthorPhotoUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authorPhotoUrl', Sort.desc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenByBookmarkCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bookmarkCount', Sort.asc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenByBookmarkCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bookmarkCount', Sort.desc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenByCaption() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'caption', Sort.asc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenByCaptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'caption', Sort.desc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenByCommentCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'commentCount', Sort.asc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenByCommentCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'commentCount', Sort.desc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenByCommunityId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'communityId', Sort.asc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenByCommunityIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'communityId', Sort.desc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenByIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.asc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenByIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.desc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenByLikeCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'likeCount', Sort.asc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenByLikeCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'likeCount', Sort.desc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenByLocalUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localUpdatedAt', Sort.asc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenByLocalUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localUpdatedAt', Sort.desc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenByRepostAuthorId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'repostAuthorId', Sort.asc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenByRepostAuthorIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'repostAuthorId', Sort.desc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenByRepostAuthorName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'repostAuthorName', Sort.asc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenByRepostAuthorNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'repostAuthorName', Sort.desc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenByRepostCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'repostCount', Sort.asc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenByRepostCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'repostCount', Sort.desc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenByRepostOf() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'repostOf', Sort.asc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenByRepostOfDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'repostOf', Sort.desc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenByShareCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'shareCount', Sort.asc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenByShareCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'shareCount', Sort.desc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenBySyncStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncStatus', Sort.asc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenBySyncStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncStatus', Sort.desc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<PostLite, PostLite, QAfterSortBy> thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension PostLiteQueryWhereDistinct
    on QueryBuilder<PostLite, PostLite, QDistinct> {
  QueryBuilder<PostLite, PostLite, QDistinct> distinctByAuthorId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'authorId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PostLite, PostLite, QDistinct> distinctByAuthorName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'authorName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PostLite, PostLite, QDistinct> distinctByAuthorPhotoUrl(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'authorPhotoUrl',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PostLite, PostLite, QDistinct> distinctByBookmarkCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'bookmarkCount');
    });
  }

  QueryBuilder<PostLite, PostLite, QDistinct> distinctByCaption(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'caption', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PostLite, PostLite, QDistinct> distinctByCommentCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'commentCount');
    });
  }

  QueryBuilder<PostLite, PostLite, QDistinct> distinctByCommunityId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'communityId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PostLite, PostLite, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<PostLite, PostLite, QDistinct> distinctById(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PostLite, PostLite, QDistinct> distinctByLikeCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'likeCount');
    });
  }

  QueryBuilder<PostLite, PostLite, QDistinct> distinctByLocalUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'localUpdatedAt');
    });
  }

  QueryBuilder<PostLite, PostLite, QDistinct> distinctByMediaThumbUrls() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'mediaThumbUrls');
    });
  }

  QueryBuilder<PostLite, PostLite, QDistinct> distinctByMediaTypes() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'mediaTypes');
    });
  }

  QueryBuilder<PostLite, PostLite, QDistinct> distinctByMediaUrls() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'mediaUrls');
    });
  }

  QueryBuilder<PostLite, PostLite, QDistinct> distinctByRepostAuthorId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'repostAuthorId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PostLite, PostLite, QDistinct> distinctByRepostAuthorName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'repostAuthorName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PostLite, PostLite, QDistinct> distinctByRepostCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'repostCount');
    });
  }

  QueryBuilder<PostLite, PostLite, QDistinct> distinctByRepostOf(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'repostOf', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PostLite, PostLite, QDistinct> distinctByShareCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'shareCount');
    });
  }

  QueryBuilder<PostLite, PostLite, QDistinct> distinctBySyncStatus(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'syncStatus', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PostLite, PostLite, QDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension PostLiteQueryProperty
    on QueryBuilder<PostLite, PostLite, QQueryProperty> {
  QueryBuilder<PostLite, int, QQueryOperations> isarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isarId');
    });
  }

  QueryBuilder<PostLite, String, QQueryOperations> authorIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'authorId');
    });
  }

  QueryBuilder<PostLite, String?, QQueryOperations> authorNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'authorName');
    });
  }

  QueryBuilder<PostLite, String?, QQueryOperations> authorPhotoUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'authorPhotoUrl');
    });
  }

  QueryBuilder<PostLite, int, QQueryOperations> bookmarkCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'bookmarkCount');
    });
  }

  QueryBuilder<PostLite, String?, QQueryOperations> captionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'caption');
    });
  }

  QueryBuilder<PostLite, int, QQueryOperations> commentCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'commentCount');
    });
  }

  QueryBuilder<PostLite, String?, QQueryOperations> communityIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'communityId');
    });
  }

  QueryBuilder<PostLite, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<PostLite, String, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<PostLite, int, QQueryOperations> likeCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'likeCount');
    });
  }

  QueryBuilder<PostLite, DateTime, QQueryOperations> localUpdatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'localUpdatedAt');
    });
  }

  QueryBuilder<PostLite, List<String>, QQueryOperations>
      mediaThumbUrlsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'mediaThumbUrls');
    });
  }

  QueryBuilder<PostLite, List<String>, QQueryOperations> mediaTypesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'mediaTypes');
    });
  }

  QueryBuilder<PostLite, List<String>, QQueryOperations> mediaUrlsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'mediaUrls');
    });
  }

  QueryBuilder<PostLite, String?, QQueryOperations> repostAuthorIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'repostAuthorId');
    });
  }

  QueryBuilder<PostLite, String?, QQueryOperations> repostAuthorNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'repostAuthorName');
    });
  }

  QueryBuilder<PostLite, int, QQueryOperations> repostCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'repostCount');
    });
  }

  QueryBuilder<PostLite, String?, QQueryOperations> repostOfProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'repostOf');
    });
  }

  QueryBuilder<PostLite, int, QQueryOperations> shareCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'shareCount');
    });
  }

  QueryBuilder<PostLite, String, QQueryOperations> syncStatusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'syncStatus');
    });
  }

  QueryBuilder<PostLite, DateTime?, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}
