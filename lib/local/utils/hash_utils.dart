/// FNV-1a hash for generating Isar IDs from string keys.
/// This is used to convert Firestore document IDs to Isar integer IDs.
/// Uses 32-bit safe integers for JavaScript compatibility.
int fastHash(String string) {
  // Use 32-bit hash for JavaScript compatibility
  var hash = 0x811c9dc5;

  for (var i = 0; i < string.length; i++) {
    final codeUnit = string.codeUnitAt(i);
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0x7FFFFFFF; // Keep within 31-bit safe range
  }

  return hash;
}
