import 'package:flutter/foundation.dart';

/// Web-specific database stub that provides graceful fallback behavior.
/// On Web, all local database operations are no-ops since WebSQL is not supported.
/// The app relies entirely on Supabase for data persistence on Web.
class WebDatabaseStub {
  static final WebDatabaseStub instance = WebDatabaseStub._init();
  
  WebDatabaseStub._init();
  
  /// Always returns false on Web - local DB is not supported
  bool get isLocalDbSupported => false;
  
  /// Log warning and return empty list
  Future<List<Map<String, dynamic>>> query(String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    debugPrint('⚠️ WebDatabaseStub: query($table) - Web uses Supabase only');
    return [];
  }
  
  /// Log warning and return 0
  Future<int> insert(String table, Map<String, dynamic> values) async {
    debugPrint('⚠️ WebDatabaseStub: insert($table) - Web uses Supabase only');
    return 0;
  }
  
  /// Log warning and return 0
  Future<int> update(String table, Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    debugPrint('⚠️ WebDatabaseStub: update($table) - Web uses Supabase only');
    return 0;
  }
  
  /// Log warning and return 0
  Future<int> delete(String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    debugPrint('⚠️ WebDatabaseStub: delete($table) - Web uses Supabase only');
    return 0;
  }
}
