// Stub file for Isar on web platform
// Isar is not supported on web, so we provide empty stubs

class Isar {
  static Future<Isar> open(
    List<dynamic> schemas, {
    String? directory,
    String name = 'default',
    bool inspector = false,
  }) async {
    throw UnsupportedError('Isar is not supported on web');
  }

  Future<void> close() async {}
  Future<void> writeTxn<T>(Future<T> Function() callback) async {}
  T txnSync<T>(T Function() callback) => throw UnsupportedError('Isar is not supported on web');
}

class IsarCollection<T> {
  Future<void> put(T object) async {}
  Future<void> putAll(List<T> objects) async {}
  T? getSync(int id) => null;
  int countSync() => 0;
}

// Schema stubs
class CollectionSchema<T> {
  const CollectionSchema({
    required this.name,
    required this.id,
    required this.properties,
    required this.estimateSize,
    required this.serialize,
    required this.deserialize,
    required this.deserializeProp,
    this.indexes,
    this.links,
    this.embeddedSchemas,
    this.getId,
    this.getLinks,
    this.setId,
  });

  final String name;
  final int id;
  final Map<String, dynamic> properties;
  final int Function(T, List<int>, Map<Type, List<int>>, Map<String, int>) estimateSize;
  final void Function(T, dynamic, List<int>, Map<Type, List<int>>, Map<String, int>) serialize;
  final T Function(int, dynamic, List<int>, Map<Type, List<int>>) deserialize;
  final dynamic Function(int, int, dynamic, List<int>) deserializeProp;
  final List<dynamic>? indexes;
  final Map<String, dynamic>? links;
  final Map<Type, dynamic>? embeddedSchemas;
  final int? Function(T)? getId;
  final Map<String, dynamic> Function(T)? getLinks;
  final void Function(T, int)? setId;
}

// Annotation stubs
class Collection {
  const Collection();
}

class Id {
  const Id();
}

class Index {
  const Index({
    this.name,
    this.composite = const [],
    this.unique = false,
    this.caseSensitive = true,
    this.type = IndexType.value,
  });

  final String? name;
  final List<CompositeIndex> composite;
  final bool unique;
  final bool caseSensitive;
  final IndexType type;
}

class CompositeIndex {
  const CompositeIndex(this.property);
  final String property;
}

enum IndexType { value, hash, hashElements }

// Query stubs
class Query<T> {}

class QueryBuilder<T, R, S> {
  QueryBuilder<T, R, S> sortByCreatedAtDesc() => this;
  QueryBuilder<T, R, S> limit(int limit) => this;
  List<T> findAllSync() => [];
  Stream<List<T>> watch({bool fireImmediately = false}) => Stream.value([]);
}

extension IsarCollectionExt<T> on IsarCollection<T> {
  QueryBuilder<T, T, dynamic> where() => QueryBuilder<T, T, dynamic>();
  QueryBuilder<T, T, dynamic> filter() => QueryBuilder<T, T, dynamic>();
}
