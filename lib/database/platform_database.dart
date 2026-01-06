import 'package:flutter/foundation.dart';

/// Platform-specific database access abstraction.
/// 
/// On Android/Linux: Uses SQLite via sqflite/sqflite_common_ffi
/// On Web: Uses Supabase directly (no local persistence)
/// 
/// Use [isPlatformLocalDbSupported] to check before attempting local DB operations.
class PlatformDatabase {
  static final PlatformDatabase instance = PlatformDatabase._init();
  
  PlatformDatabase._init();
  
  /// Returns true if the current platform supports local SQLite database.
  /// Web does not support SQLite and must use Supabase directly.
  bool get isPlatformLocalDbSupported => !kIsWeb;
  
  /// Returns true if running on Web platform
  bool get isWeb => kIsWeb;
  
  /// Returns true if running on desktop (Linux/Windows/macOS)
  bool get isDesktop {
    if (kIsWeb) return false;
    // Note: We can't import dart:io on Web, so this is handled via conditional imports
    return _isDesktopPlatform;
  }
  
  // This will be set by the platform-specific initialization
  static bool _isDesktopPlatform = false;
  
  /// Initialize platform detection (call from main.dart)
  static void initPlatform({required bool isDesktop}) {
    _isDesktopPlatform = isDesktop;
  }
}

/// Export for easy checking
bool get isPlatformLocalDbSupported => PlatformDatabase.instance.isPlatformLocalDbSupported;
bool get isWebPlatform => PlatformDatabase.instance.isWeb;
