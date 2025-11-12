/// Diagnostic logger for Firestore operations
/// Helps identify permission issues, auth problems, and data access errors
library;

class FirestoreLogger {
  static void logQuery(String collection, String operation, {String? filter}) {
    final filterStr = filter != null ? ' (filter: $filter)' : '';
    print('🔵 Firestore Query: $collection.$operation$filterStr');
  }

  static void logSuccess(String collection, String operation, {int? count, String? details}) {
    final countStr = count != null ? ' ($count items)' : '';
    final detailsStr = details != null ? ' - $details' : '';
    print('✅ $collection.$operation success$countStr$detailsStr');
  }

  static void logError(String collection, String operation, dynamic error, {String? hint}) {
    print('❌ $collection.$operation ERROR: $error');
    if (hint != null) {
      print('💡 Hint: $hint');
    }
    
    // Parse common errors
    final errorStr = error.toString();
    if (errorStr.contains('permission-denied')) {
      print('🔍 Permission denied - Check:');
      print('   1) Firestore rules for $collection collection');
      print('   2) User authentication status');
      print('   3) Document-level permissions');
    } else if (errorStr.contains('not-found')) {
      print('🔍 Document not found - Document may not exist');
    } else if (errorStr.contains('failed-precondition')) {
      print('🔍 Index missing - Create composite index in Firebase Console');
    }
  }

  static void logAuthCheck(String? uid, String operation) {
    if (uid == null) {
      print('⚠️  No authenticated user for $operation');
    } else {
      print('🔐 Auth OK (uid: ${uid.substring(0, 8)}...) for $operation');
    }
  }
}
