import 'package:flutter/foundation.dart';

/// Service for managing user identity.
/// 
/// SINGLE-USER MODE:
/// - All devices share ONE fixed global user ID
/// - No login required
/// - Ready for future multi-user transition
/// 
/// When multi-user is needed, change this to use Supabase Auth.
class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  /// FIXED GLOBAL USER ID for single-user mode
  /// All devices will use this same ID
  /// 
  /// Format: UUID v4 (fixed, not random)
  /// When switching to multi-user: replace with auth.currentUser.id
  static const String _globalUserId = '00000000-0000-0000-0000-000000000001';

  /// Get current user ID - always returns fixed global ID
  String? get currentUserId => _globalUserId;

  /// Check if user is authenticated - always true in single-user mode
  bool get isAuthenticated => true;

  /// Get current user email - not applicable in single-user mode
  String? get currentUserEmail => 'single-user@focus-logger.local';

  /// Check if anonymous - true in single-user mode
  bool get isAnonymous => true;

  // =================================================================
  // FUTURE: Multi-user methods (disabled for now)
  // =================================================================
  
  /// Sign up - disabled in single-user mode
  Future<void> signUp({required String email, required String password}) async {
    debugPrint('[USER] signUp disabled in single-user mode');
  }

  /// Sign in - disabled in single-user mode
  Future<void> signIn({required String email, required String password}) async {
    debugPrint('[USER] signIn disabled in single-user mode');
  }

  /// Sign out - disabled in single-user mode
  Future<void> signOut() async {
    debugPrint('[USER] signOut disabled in single-user mode');
  }
}
