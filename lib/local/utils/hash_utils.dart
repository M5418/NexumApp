/// Fast string hash for Isar ID generation.
/// Uses FNV-1a hash algorithm for consistent, fast hashing.
int fastHash(String string) {
  var hash = 0xcbf29ce484222325;
  for (var i = 0; i < string.length; i++) {
    final codeUnit = string.codeUnitAt(i);
    hash ^= codeUnit >> 8;
    hash *= 0x100000001b3;
    hash ^= codeUnit & 0xFF;
    hash *= 0x100000001b3;
  }
  return hash;
}
