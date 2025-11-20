/// Diagnostic logger for Firestore operations
/// Helps identify permission issues, auth problems, and data access errors
library;

import 'package:flutter/foundation.dart' show debugPrint;

class FirestoreLogger {
  static void logQuery(String collection, String operation, {String? filter}) {
    final filterStr = filter != null ? ' (filter: $filter)' : '';
    debugPrint('🔵 Firestore Query: $collection.$operation$filterStr');
  }

  static void logSuccess(String collection, String operation, {int? count, String? details}) {
    final countStr = count != null ? ' ($count items)' : '';
    final detailsStr = details != null ? ' - $details' : '';
    debugPrint('✅ $collection.$operation success$countStr$detailsStr');
  }

  static void logError(String collection, String operation, dynamic error, {String? hint}) {
    debugPrint('❌ $collection.$operation ERROR: $error');
    if (hint != null) {
      debugPrint('💡 Hint: $hint');
    }
    
    // Parse common errors
    final errorStr = error.toString();
    if (errorStr.contains('permission-denied')) {
      debugPrint('🔍 Permission denied - Check:');
      debugPrint('   1) Firestore rules for $collection collection');
      debugPrint('   2) User authentication status');
      debugPrint('   3) Document-level permissions');
    } else if (errorStr.contains('not-found')) {
      debugPrint('🔍 Document not found - Document may not exist');
    } else if (errorStr.contains('failed-precondition')) {
      debugPrint('🔍 Index missing - Create composite index in Firebase Console');
    }
  }

  static void logAuthCheck(String? uid, String operation) {
    if (uid == null) {
      debugPrint('⚠️  No authenticated user for $operation');
    } else {
      
    }
  }
}
