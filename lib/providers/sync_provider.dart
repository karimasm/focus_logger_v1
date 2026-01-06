import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sync_service.dart';

/// Sync event types exposed through provider
export '../services/sync_service.dart' show SyncEvent;

/// Provider for managing sync state and exposing it to UI
class SyncProvider extends ChangeNotifier {
  final SyncService _syncService = SyncService();
  final Connectivity _connectivity = Connectivity();
  
  // Sync state
  SyncState _state = SyncState.idle;
  DateTime? _lastSyncTime;
  String? _lastError;
  bool _isOnline = true;
  int _pendingChangesCount = 0;
  
  // Getters
  SyncState get state => _state;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get lastError => _lastError;
  bool get isOnline => _isOnline;
  bool get isSyncing => _state == SyncState.syncing;
  int get pendingChangesCount => _pendingChangesCount;
  bool get hasQueuedChanges => _pendingChangesCount > 0;
  
  String get statusText {
    switch (_state) {
      case SyncState.syncing:
        return 'Syncing…';
      case SyncState.success:
        if (_lastSyncTime != null) {
          return 'Last synced: ${_formatTime(_lastSyncTime!)}';
        }
        return 'Synced';
      case SyncState.error:
        return _lastError ?? 'Sync failed';
      case SyncState.offline:
        if (_pendingChangesCount > 0) {
          return 'Offline ($_pendingChangesCount queued)';
        }
        return 'Offline (will sync later)';
      case SyncState.idle:
        if (_lastSyncTime != null) {
          return 'Last synced: ${_formatTime(_lastSyncTime!)}';
        }
        return 'Ready to sync';
    }
  }
  
  /// Detailed status for the sync button
  String get detailedStatus {
    if (_state == SyncState.syncing) {
      return 'Syncing…';
    }
    
    final parts = <String>[];
    
    if (_lastSyncTime != null) {
      parts.add('Last synced: ${_formatTime(_lastSyncTime!)}');
    }
    
    if (!_isOnline) {
      parts.add('Currently offline');
    }
    
    if (_pendingChangesCount > 0) {
      parts.add('$_pendingChangesCount changes queued');
    }
    
    if (parts.isEmpty) {
      return 'Ready to sync';
    }
    
    return parts.join('\n');
  }
  
  SyncProvider() {
    _init();
  }

  Future<void> _init() async {
    // Load last sync time from preferences
    final prefs = await SharedPreferences.getInstance();
    final lastSyncStr = prefs.getString('last_sync_time');
    if (lastSyncStr != null) {
      _lastSyncTime = DateTime.tryParse(lastSyncStr);
    }
    
    // Check connectivity
    await _checkConnectivity();
    
    // Listen for connectivity changes
    _connectivity.onConnectivityChanged.listen((results) {
      _isOnline = results.any((r) => r != ConnectivityResult.none);
      if (!_isOnline) {
        _state = SyncState.offline;
      } else if (_state == SyncState.offline) {
        _state = SyncState.idle;
        // Auto-sync when coming back online
        syncNow(event: SyncEvent.appOpened);
      }
      notifyListeners();
    });
    
    // Listen for sync service updates
    _syncService.addListener(_onSyncServiceUpdate);
    
    notifyListeners();
  }
  
  void _onSyncServiceUpdate() {
    _pendingChangesCount = _syncService.pendingChangesCount;
    notifyListeners();
  }
  
  Future<void> _checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = results.any((r) => r != ConnectivityResult.none);
    if (!_isOnline) {
      _state = SyncState.offline;
    }
  }
  
  /// Trigger a sync for a specific event
  /// This is the preferred method for event-based syncing
  Future<void> triggerEventSync(SyncEvent event) async {
    await _syncService.triggerSync(event);
  }
  
  /// Manually trigger a sync ("Sync Now" button)
  /// Uses fullSync() to pull entire dataset and ensure consistent state
  Future<void> syncNow({SyncEvent event = SyncEvent.manualSync}) async {
    if (_state == SyncState.syncing) return;
    
    await _checkConnectivity();
    if (!_isOnline) {
      _state = SyncState.offline;
      notifyListeners();
      return;
    }
    
    _state = SyncState.syncing;
    _lastError = null;
    notifyListeners();
    
    try {
      // Use fullSync for manual "Sync Now" to ensure complete data refresh
      await _syncService.fullSync();
      
      _state = SyncState.success;
      _lastSyncTime = DateTime.now();
      
      // Save last sync time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sync_time', _lastSyncTime!.toIso8601String());
      
      // Update pending count
      _pendingChangesCount = _syncService.pendingChangesCount;
      
    } catch (e) {
      _state = SyncState.error;
      _lastError = e.toString();
      debugPrint('Sync error: $e');
    }
    
    notifyListeners();
    
    // Reset to idle after a short delay
    Future.delayed(const Duration(seconds: 3), () {
      if (_state == SyncState.success) {
        _state = SyncState.idle;
        notifyListeners();
      }
    });
  }

  
  /// Called when app is opened or resumed
  /// Triggers sync and checks for global running activity
  Future<void> onAppResumed() async {
    await _checkConnectivity();
    if (_isOnline) {
      await syncNow(event: SyncEvent.appOpened);
      
      // Resolve any running activity conflicts
      await _syncService.resolveRunningActivityConflicts();
    }
  }
  
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 1) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
  
  @override
  void dispose() {
    _syncService.removeListener(_onSyncServiceUpdate);
    super.dispose();
  }
}

enum SyncState {
  idle,
  syncing,
  success,
  error,
  offline,
}
