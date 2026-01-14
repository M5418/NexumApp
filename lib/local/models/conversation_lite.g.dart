// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_lite.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetConversationLiteCollection on Isar {
  IsarCollection<ConversationLite> get conversationLites => this.collection();
}

const ConversationLiteSchema = CollectionSchema(
  name: r'ConversationLite',
  id: -4173845629391827110,
  properties: {
    r'id': PropertySchema(
      id: 0,
      name: r'id',
      type: IsarType.string,
    ),
    r'lastMessageAt': PropertySchema(
      id: 1,
      name: r'lastMessageAt',
      type: IsarType.dateTime,
    ),
    r'lastMessageSenderId': PropertySchema(
      id: 2,
      name: r'lastMessageSenderId',
      type: IsarType.string,
    ),
    r'lastMessageText': PropertySchema(
      id: 3,
      name: r'lastMessageText',
      type: IsarType.string,
    ),
    r'lastMessageType': PropertySchema(
      id: 4,
      name: r'lastMessageType',
      type: IsarType.string,
    ),
    r'localUpdatedAt': PropertySchema(
      id: 5,
      name: r'localUpdatedAt',
      type: IsarType.dateTime,
    ),
    r'memberIds': PropertySchema(
      id: 6,
      name: r'memberIds',
      type: IsarType.stringList,
    ),
    r'muted': PropertySchema(
      id: 7,
      name: r'muted',
      type: IsarType.bool,
    ),
    r'otherUserId': PropertySchema(
      id: 8,
      name: r'otherUserId',
      type: IsarType.string,
    ),
    r'otherUserName': PropertySchema(
      id: 9,
      name: r'otherUserName',
      type: IsarType.string,
    ),
    r'otherUserPhotoUrl': PropertySchema(
      id: 10,
      name: r'otherUserPhotoUrl',
      type: IsarType.string,
    ),
    r'syncStatus': PropertySchema(
      id: 11,
      name: r'syncStatus',
      type: IsarType.string,
    ),
    r'unreadCount': PropertySchema(
      id: 12,
      name: r'unreadCount',
      type: IsarType.long,
    ),
    r'updatedAt': PropertySchema(
      id: 13,
      name: r'updatedAt',
      type: IsarType.dateTime,
    )
  },
  estimateSize: _conversationLiteEstimateSize,
  serialize: _conversationLiteSerialize,
  deserialize: _conversationLiteDeserialize,
  deserializeProp: _conversationLiteDeserializeProp,
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
  getId: _conversationLiteGetId,
  getLinks: _conversationLiteGetLinks,
  attach: _conversationLiteAttach,
  version: '3.1.0+1',
);

int _conversationLiteEstimateSize(
  ConversationLite object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.id.length * 3;
  {
    final value = object.lastMessageSenderId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.lastMessageText;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.lastMessageType;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.memberIds.length * 3;
  {
    for (var i = 0; i < object.memberIds.length; i++) {
      final value = object.memberIds[i];
      bytesCount += value.length * 3;
    }
  }
  {
    final value = object.otherUserId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.otherUserName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.otherUserPhotoUrl;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.syncStatus.length * 3;
  return bytesCount;
}

void _conversationLiteSerialize(
  ConversationLite object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.id);
  writer.writeDateTime(offsets[1], object.lastMessageAt);
  writer.writeString(offsets[2], object.lastMessageSenderId);
  writer.writeString(offsets[3], object.lastMessageText);
  writer.writeString(offsets[4], object.lastMessageType);
  writer.writeDateTime(offsets[5], object.localUpdatedAt);
  writer.writeStringList(offsets[6], object.memberIds);
  writer.writeBool(offsets[7], object.muted);
  writer.writeString(offsets[8], object.otherUserId);
  writer.writeString(offsets[9], object.otherUserName);
  writer.writeString(offsets[10], object.otherUserPhotoUrl);
  writer.writeString(offsets[11], object.syncStatus);
  writer.writeLong(offsets[12], object.unreadCount);
  writer.writeDateTime(offsets[13], object.updatedAt);
}

ConversationLite _conversationLiteDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ConversationLite();
  object.id = reader.readString(offsets[0]);
  object.lastMessageAt = reader.readDateTimeOrNull(offsets[1]);
  object.lastMessageSenderId = reader.readStringOrNull(offsets[2]);
  object.lastMessageText = reader.readStringOrNull(offsets[3]);
  object.lastMessageType = reader.readStringOrNull(offsets[4]);
  object.localUpdatedAt = reader.readDateTime(offsets[5]);
  object.memberIds = reader.readStringList(offsets[6]) ?? [];
  object.muted = reader.readBool(offsets[7]);
  object.otherUserId = reader.readStringOrNull(offsets[8]);
  object.otherUserName = reader.readStringOrNull(offsets[9]);
  object.otherUserPhotoUrl = reader.readStringOrNull(offsets[10]);
  object.syncStatus = reader.readString(offsets[11]);
  object.unreadCount = reader.readLong(offsets[12]);
  object.updatedAt = reader.readDateTimeOrNull(offsets[13]);
  return object;
}

P _conversationLiteDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readDateTime(offset)) as P;
    case 6:
      return (reader.readStringList(offset) ?? []) as P;
    case 7:
      return (reader.readBool(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readStringOrNull(offset)) as P;
    case 10:
      return (reader.readStringOrNull(offset)) as P;
    case 11:
      return (reader.readString(offset)) as P;
    case 12:
      return (reader.readLong(offset)) as P;
    case 13:
      return (reader.readDateTimeOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _conversationLiteGetId(ConversationLite object) {
  return object.isarId;
}

List<IsarLinkBase<dynamic>> _conversationLiteGetLinks(ConversationLite object) {
  return [];
}

void _conversationLiteAttach(
    IsarCollection<dynamic> col, Id id, ConversationLite object) {}

extension ConversationLiteByIndex on IsarCollection<ConversationLite> {
  Future<ConversationLite?> getById(String id) {
    return getByIndex(r'id', [id]);
  }

  ConversationLite? getByIdSync(String id) {
    return getByIndexSync(r'id', [id]);
  }

  Future<bool> deleteById(String id) {
    return deleteByIndex(r'id', [id]);
  }

  bool deleteByIdSync(String id) {
    return deleteByIndexSync(r'id', [id]);
  }

  Future<List<ConversationLite?>> getAllById(List<String> idValues) {
    final values = idValues.map((e) => [e]).toList();
    return getAllByIndex(r'id', values);
  }

  List<ConversationLite?> getAllByIdSync(List<String> idValues) {
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

  Future<Id> putById(ConversationLite object) {
    return putByIndex(r'id', object);
  }

  Id putByIdSync(ConversationLite object, {bool saveLinks = true}) {
    return putByIndexSync(r'id', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllById(List<ConversationLite> objects) {
    return putAllByIndex(r'id', objects);
  }

  List<Id> putAllByIdSync(List<ConversationLite> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'id', objects, saveLinks: saveLinks);
  }
}

extension ConversationLiteQueryWhereSort
    on QueryBuilder<ConversationLite, ConversationLite, QWhere> {
  QueryBuilder<ConversationLite, ConversationLite, QAfterWhere> anyIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterWhere> anyUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'updatedAt'),
      );
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterWhere>
      anyLocalUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'localUpdatedAt'),
      );
    });
  }
}

extension ConversationLiteQueryWhere
    on QueryBuilder<ConversationLite, ConversationLite, QWhereClause> {
  QueryBuilder<ConversationLite, ConversationLite, QAfterWhereClause>
      isarIdEqualTo(Id isarId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: isarId,
        upper: isarId,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterWhereClause>
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

  QueryBuilder<ConversationLite, ConversationLite, QAfterWhereClause>
      isarIdGreaterThan(Id isarId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: isarId, includeLower: include),
      );
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterWhereClause>
      isarIdLessThan(Id isarId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: isarId, includeUpper: include),
      );
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterWhereClause>
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

  QueryBuilder<ConversationLite, ConversationLite, QAfterWhereClause> idEqualTo(
      String id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'id',
        value: [id],
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterWhereClause>
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

  QueryBuilder<ConversationLite, ConversationLite, QAfterWhereClause>
      updatedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'updatedAt',
        value: [null],
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterWhereClause>
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

  QueryBuilder<ConversationLite, ConversationLite, QAfterWhereClause>
      updatedAtEqualTo(DateTime? updatedAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'updatedAt',
        value: [updatedAt],
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterWhereClause>
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

  QueryBuilder<ConversationLite, ConversationLite, QAfterWhereClause>
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

  QueryBuilder<ConversationLite, ConversationLite, QAfterWhereClause>
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

  QueryBuilder<ConversationLite, ConversationLite, QAfterWhereClause>
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

  QueryBuilder<ConversationLite, ConversationLite, QAfterWhereClause>
      localUpdatedAtEqualTo(DateTime localUpdatedAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'localUpdatedAt',
        value: [localUpdatedAt],
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterWhereClause>
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

  QueryBuilder<ConversationLite, ConversationLite, QAfterWhereClause>
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

  QueryBuilder<ConversationLite, ConversationLite, QAfterWhereClause>
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

  QueryBuilder<ConversationLite, ConversationLite, QAfterWhereClause>
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

extension ConversationLiteQueryFilter
    on QueryBuilder<ConversationLite, ConversationLite, QFilterCondition> {
  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
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

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
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

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
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

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
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

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
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

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
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

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      idContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      idMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'id',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      idIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: '',
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      idIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'id',
        value: '',
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      isarIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isarId',
        value: value,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
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

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
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

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
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

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastMessageAt',
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastMessageAt',
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastMessageAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastMessageAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastMessageAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastMessageAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageSenderIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastMessageSenderId',
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageSenderIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastMessageSenderId',
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageSenderIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastMessageSenderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageSenderIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastMessageSenderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageSenderIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastMessageSenderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageSenderIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastMessageSenderId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageSenderIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'lastMessageSenderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageSenderIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'lastMessageSenderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageSenderIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'lastMessageSenderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageSenderIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'lastMessageSenderId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageSenderIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastMessageSenderId',
        value: '',
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageSenderIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'lastMessageSenderId',
        value: '',
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageTextIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastMessageText',
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageTextIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastMessageText',
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageTextEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastMessageText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageTextGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastMessageText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageTextLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastMessageText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageTextBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastMessageText',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageTextStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'lastMessageText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageTextEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'lastMessageText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageTextContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'lastMessageText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageTextMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'lastMessageText',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageTextIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastMessageText',
        value: '',
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageTextIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'lastMessageText',
        value: '',
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageTypeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastMessageType',
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageTypeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastMessageType',
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageTypeEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastMessageType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageTypeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastMessageType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageTypeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastMessageType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageTypeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastMessageType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'lastMessageType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'lastMessageType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'lastMessageType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'lastMessageType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastMessageType',
        value: '',
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      lastMessageTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'lastMessageType',
        value: '',
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      localUpdatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'localUpdatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
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

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
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

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
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

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      memberIdsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'memberIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      memberIdsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'memberIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      memberIdsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'memberIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      memberIdsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'memberIds',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      memberIdsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'memberIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      memberIdsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'memberIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      memberIdsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'memberIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      memberIdsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'memberIds',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      memberIdsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'memberIds',
        value: '',
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      memberIdsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'memberIds',
        value: '',
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      memberIdsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'memberIds',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      memberIdsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'memberIds',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      memberIdsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'memberIds',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      memberIdsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'memberIds',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      memberIdsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'memberIds',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      memberIdsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'memberIds',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      mutedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'muted',
        value: value,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      otherUserIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'otherUserId',
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      otherUserIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'otherUserId',
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      otherUserIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'otherUserId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      otherUserIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'otherUserId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      otherUserIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'otherUserId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      otherUserIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'otherUserId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      otherUserIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'otherUserId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      otherUserIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'otherUserId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      otherUserIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'otherUserId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      otherUserIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'otherUserId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      otherUserIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'otherUserId',
        value: '',
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      otherUserIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'otherUserId',
        value: '',
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      otherUserNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'otherUserName',
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      otherUserNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'otherUserName',
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      otherUserNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'otherUserName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      otherUserNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'otherUserName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      otherUserNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'otherUserName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      otherUserNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'otherUserName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      otherUserNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'otherUserName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      otherUserNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'otherUserName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      otherUserNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'otherUserName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      otherUserNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'otherUserName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      otherUserNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'otherUserName',
        value: '',
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      otherUserNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'otherUserName',
        value: '',
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      otherUserPhotoUrlIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'otherUserPhotoUrl',
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      otherUserPhotoUrlIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'otherUserPhotoUrl',
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      otherUserPhotoUrlEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'otherUserPhotoUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      otherUserPhotoUrlGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'otherUserPhotoUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      otherUserPhotoUrlLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'otherUserPhotoUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      otherUserPhotoUrlBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'otherUserPhotoUrl',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      otherUserPhotoUrlStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'otherUserPhotoUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      otherUserPhotoUrlEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'otherUserPhotoUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      otherUserPhotoUrlContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'otherUserPhotoUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      otherUserPhotoUrlMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'otherUserPhotoUrl',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      otherUserPhotoUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'otherUserPhotoUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      otherUserPhotoUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'otherUserPhotoUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
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

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
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

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
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

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
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

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
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

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
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

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      syncStatusContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'syncStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      syncStatusMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'syncStatus',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      syncStatusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'syncStatus',
        value: '',
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      syncStatusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'syncStatus',
        value: '',
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      unreadCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'unreadCount',
        value: value,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      unreadCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'unreadCount',
        value: value,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      unreadCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'unreadCount',
        value: value,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      unreadCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'unreadCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      updatedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'updatedAt',
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      updatedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'updatedAt',
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
      updatedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
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

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
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

  QueryBuilder<ConversationLite, ConversationLite, QAfterFilterCondition>
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

extension ConversationLiteQueryObject
    on QueryBuilder<ConversationLite, ConversationLite, QFilterCondition> {}

extension ConversationLiteQueryLinks
    on QueryBuilder<ConversationLite, ConversationLite, QFilterCondition> {}

extension ConversationLiteQuerySortBy
    on QueryBuilder<ConversationLite, ConversationLite, QSortBy> {
  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy> sortById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      sortByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      sortByLastMessageAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastMessageAt', Sort.asc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      sortByLastMessageAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastMessageAt', Sort.desc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      sortByLastMessageSenderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastMessageSenderId', Sort.asc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      sortByLastMessageSenderIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastMessageSenderId', Sort.desc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      sortByLastMessageText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastMessageText', Sort.asc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      sortByLastMessageTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastMessageText', Sort.desc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      sortByLastMessageType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastMessageType', Sort.asc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      sortByLastMessageTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastMessageType', Sort.desc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      sortByLocalUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localUpdatedAt', Sort.asc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      sortByLocalUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localUpdatedAt', Sort.desc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy> sortByMuted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'muted', Sort.asc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      sortByMutedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'muted', Sort.desc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      sortByOtherUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'otherUserId', Sort.asc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      sortByOtherUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'otherUserId', Sort.desc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      sortByOtherUserName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'otherUserName', Sort.asc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      sortByOtherUserNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'otherUserName', Sort.desc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      sortByOtherUserPhotoUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'otherUserPhotoUrl', Sort.asc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      sortByOtherUserPhotoUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'otherUserPhotoUrl', Sort.desc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      sortBySyncStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncStatus', Sort.asc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      sortBySyncStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncStatus', Sort.desc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      sortByUnreadCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unreadCount', Sort.asc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      sortByUnreadCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unreadCount', Sort.desc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension ConversationLiteQuerySortThenBy
    on QueryBuilder<ConversationLite, ConversationLite, QSortThenBy> {
  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      thenByIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.asc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      thenByIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.desc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      thenByLastMessageAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastMessageAt', Sort.asc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      thenByLastMessageAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastMessageAt', Sort.desc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      thenByLastMessageSenderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastMessageSenderId', Sort.asc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      thenByLastMessageSenderIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastMessageSenderId', Sort.desc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      thenByLastMessageText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastMessageText', Sort.asc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      thenByLastMessageTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastMessageText', Sort.desc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      thenByLastMessageType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastMessageType', Sort.asc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      thenByLastMessageTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastMessageType', Sort.desc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      thenByLocalUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localUpdatedAt', Sort.asc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      thenByLocalUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localUpdatedAt', Sort.desc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy> thenByMuted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'muted', Sort.asc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      thenByMutedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'muted', Sort.desc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      thenByOtherUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'otherUserId', Sort.asc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      thenByOtherUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'otherUserId', Sort.desc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      thenByOtherUserName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'otherUserName', Sort.asc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      thenByOtherUserNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'otherUserName', Sort.desc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      thenByOtherUserPhotoUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'otherUserPhotoUrl', Sort.asc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      thenByOtherUserPhotoUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'otherUserPhotoUrl', Sort.desc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      thenBySyncStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncStatus', Sort.asc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      thenBySyncStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncStatus', Sort.desc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      thenByUnreadCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unreadCount', Sort.asc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      thenByUnreadCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unreadCount', Sort.desc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QAfterSortBy>
      thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension ConversationLiteQueryWhereDistinct
    on QueryBuilder<ConversationLite, ConversationLite, QDistinct> {
  QueryBuilder<ConversationLite, ConversationLite, QDistinct> distinctById(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QDistinct>
      distinctByLastMessageAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastMessageAt');
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QDistinct>
      distinctByLastMessageSenderId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastMessageSenderId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QDistinct>
      distinctByLastMessageText({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastMessageText',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QDistinct>
      distinctByLastMessageType({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastMessageType',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QDistinct>
      distinctByLocalUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'localUpdatedAt');
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QDistinct>
      distinctByMemberIds() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'memberIds');
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QDistinct>
      distinctByMuted() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'muted');
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QDistinct>
      distinctByOtherUserId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'otherUserId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QDistinct>
      distinctByOtherUserName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'otherUserName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QDistinct>
      distinctByOtherUserPhotoUrl({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'otherUserPhotoUrl',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QDistinct>
      distinctBySyncStatus({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'syncStatus', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QDistinct>
      distinctByUnreadCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'unreadCount');
    });
  }

  QueryBuilder<ConversationLite, ConversationLite, QDistinct>
      distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension ConversationLiteQueryProperty
    on QueryBuilder<ConversationLite, ConversationLite, QQueryProperty> {
  QueryBuilder<ConversationLite, int, QQueryOperations> isarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isarId');
    });
  }

  QueryBuilder<ConversationLite, String, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ConversationLite, DateTime?, QQueryOperations>
      lastMessageAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastMessageAt');
    });
  }

  QueryBuilder<ConversationLite, String?, QQueryOperations>
      lastMessageSenderIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastMessageSenderId');
    });
  }

  QueryBuilder<ConversationLite, String?, QQueryOperations>
      lastMessageTextProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastMessageText');
    });
  }

  QueryBuilder<ConversationLite, String?, QQueryOperations>
      lastMessageTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastMessageType');
    });
  }

  QueryBuilder<ConversationLite, DateTime, QQueryOperations>
      localUpdatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'localUpdatedAt');
    });
  }

  QueryBuilder<ConversationLite, List<String>, QQueryOperations>
      memberIdsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'memberIds');
    });
  }

  QueryBuilder<ConversationLite, bool, QQueryOperations> mutedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'muted');
    });
  }

  QueryBuilder<ConversationLite, String?, QQueryOperations>
      otherUserIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'otherUserId');
    });
  }

  QueryBuilder<ConversationLite, String?, QQueryOperations>
      otherUserNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'otherUserName');
    });
  }

  QueryBuilder<ConversationLite, String?, QQueryOperations>
      otherUserPhotoUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'otherUserPhotoUrl');
    });
  }

  QueryBuilder<ConversationLite, String, QQueryOperations>
      syncStatusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'syncStatus');
    });
  }

  QueryBuilder<ConversationLite, int, QQueryOperations> unreadCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'unreadCount');
    });
  }

  QueryBuilder<ConversationLite, DateTime?, QQueryOperations>
      updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}
