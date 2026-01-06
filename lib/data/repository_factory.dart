import 'package:flutter/foundation.dart';
import 'repositories/data_repository.dart';
import 'repositories/cloud_data_repository.dart';

/// Factory for getting the DataRepository.
/// 
/// CUT-OVER TO USER-SCOPED MODEL:
/// - ALL platforms now use CloudDataRepository
/// - Server is single source of truth
/// - No local-first logic
/// - No device-scoped sessions
class RepositoryFactory {
  static final RepositoryFactory instance = RepositoryFactory._init();
  
  RepositoryFactory._init();
  
  /// Get repository - always CloudDataRepository (server-authoritative)
  DataRepository get repository {
    // CUT-OVER: All platforms use cloud now
    debugPrint('[REPOSITORY] Using CloudDataRepository (server-authoritative)');
    return CloudDataRepository.instance;
  }
  
  /// Local DB is deprecated - always returns false
  bool get supportsLocalDb => false;
  
  /// Check if running on Web
  bool get isWeb => kIsWeb;
}

/// Convenience getter for easy access
DataRepository get dataRepository => RepositoryFactory.instance.repository;
