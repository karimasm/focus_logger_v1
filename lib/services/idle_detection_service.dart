import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Idle detection service for monitoring user activity.
/// 
/// PHASE 2 IMPLEMENTATION:
/// - Tracks when the last activity was running
/// - Detects idle periods > 30 minutes
/// - Triggers idle prompt on app resume
/// - Creates unlabeled blocks for idle periods
class IdleDetectionService {
  static final IdleDetectionService _instance = IdleDetectionService._internal();
  factory IdleDetectionService() => _instance;
  IdleDetectionService._internal();
  
  /// Idle threshold in minutes
  static const int idleThresholdMinutes = 30;
  static const Duration idleThreshold = Duration(minutes: idleThresholdMinutes);
  
  /// Last time an activity was running or stopped
  DateTime? _lastActivityTime;
  
  /// Timer for periodic idle checks while app is in foreground
  Timer? _idleCheckTimer;
  
  /// Callback when idle is detected
  VoidCallback? onIdleDetected;
  
  /// Flag to track if we already prompted for this idle period
  bool _hasPromptedForCurrentIdle = false;
  
  // Getters
  DateTime? get lastActivityTime => _lastActivityTime;
  bool get hasPromptedForCurrentIdle => _hasPromptedForCurrentIdle;
  
  /// Check if user has been idle for more than threshold
  bool get isIdle {
    if (_lastActivityTime == null) return false;
    final elapsed = DateTime.now().difference(_lastActivityTime!);
    return elapsed >= idleThreshold;
  }
  
  /// Get the idle duration if currently idle
  Duration get idleDuration {
    if (_lastActivityTime == null) return Duration.zero;
    return DateTime.now().difference(_lastActivityTime!);
  }
  
  /// Initialize the service
  Future<void> init() async {
    await _loadLastActivityTime();
    
    // If never set before, initialize to now (first app launch)
    if (_lastActivityTime == null) {
      _lastActivityTime = DateTime.now();
      await _saveLastActivityTime();
    }
    
    _startIdleCheckTimer();
  }
  
  /// Load last activity time from shared preferences
  Future<void> _loadLastActivityTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTimeStr = prefs.getString('last_activity_time');
      if (lastTimeStr != null) {
        _lastActivityTime = DateTime.tryParse(lastTimeStr);
      }
    } catch (e) {
      debugPrint('[IDLE] Error loading last activity time: $e');
    }
  }
  
  /// Save last activity time to shared preferences
  Future<void> _saveLastActivityTime() async {
    if (_lastActivityTime == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_activity_time', _lastActivityTime!.toIso8601String());
    } catch (e) {
      debugPrint('Error saving last activity time: $e');
    }
  }
  
  /// Start the periodic idle check timer
  void _startIdleCheckTimer() {
    _idleCheckTimer?.cancel();
    // Check every 5 minutes while app is in foreground
    _idleCheckTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _checkIdle();
    });
  }
  
  /// Check for idle state and trigger callback if needed
  void _checkIdle() {
    if (isIdle && !_hasPromptedForCurrentIdle) {
      _hasPromptedForCurrentIdle = true;
      onIdleDetected?.call();
    }
  }
  
  /// Called when an activity starts
  void onActivityStarted() {
    _lastActivityTime = DateTime.now();
    _hasPromptedForCurrentIdle = false;
    _saveLastActivityTime();
  }
  
  /// Called when an activity stops
  void onActivityStopped() {
    _lastActivityTime = DateTime.now();
    _hasPromptedForCurrentIdle = false;
    _saveLastActivityTime();
  }
  
  /// Mark that we've prompted for current idle period (prevents duplicate prompts)
  void markAsPrompted() {
    _hasPromptedForCurrentIdle = true;
  }
  
  /// Called when app resumes from background
  /// Returns true if idle prompt should be shown
  bool onAppResumed() {
    if (isIdle && !_hasPromptedForCurrentIdle) {
      _hasPromptedForCurrentIdle = true;
      return true;
    }
    return false;
  }
  
  /// Reset idle tracking after user labels the idle period
  void onIdleLabeled() {
    _lastActivityTime = DateTime.now();
    _hasPromptedForCurrentIdle = false;
    _saveLastActivityTime();
  }
  
  /// Dispose the service
  void dispose() {
    _idleCheckTimer?.cancel();
  }
}
