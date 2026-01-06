import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/safety_window.dart';

/// Service for managing enforced flow alarms and reminders
/// Plays audible alerts when flow windows begin and repeats until user acknowledges
class FlowAlarmService {
  static final FlowAlarmService instance = FlowAlarmService._init();
  
  FlowAlarmService._init();
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _reminderTimer;
  bool _isAlarmActive = false;
  String? _activeWindowId;
  
  // Reminder interval in minutes
  static const int reminderIntervalMinutes = 2;
  
  bool get isAlarmActive => _isAlarmActive;
  String? get activeWindowId => _activeWindowId;
  
  /// Check if alarm is supported on this platform
  static bool get isPlatformSupported {
    if (kIsWeb) return true; // Web can play audio
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (e) {
      return true; // Web
    }
  }

  /// Trigger alarm for a flow window starting
  Future<void> triggerFlowAlarm(SafetyWindow window) async {
    if (_isAlarmActive) {
      // Already alarming for this or another window
      if (_activeWindowId == window.id) return;
      // New window takes precedence
      await stopAlarm();
    }
    
    _isAlarmActive = true;
    _activeWindowId = window.id;
    
    debugPrint('🔔 Flow alarm triggered for: ${window.name}');
    
    // Play initial alarm
    await _playAlarmSound();
    
    // Vibrate if possible
    await _vibrate();
    
    // Start reminder timer
    _startReminderTimer(window);
  }
  
  /// Play the alarm sound
  Future<void> _playAlarmSound() async {
    if (!isPlatformSupported) return;
    
    try {
      // Use a system sound or bundled asset
      // For now, use a simple notification tone
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setVolume(1.0);
      
      // Try to play from assets, fallback to system sound
      try {
        await _audioPlayer.play(AssetSource('sounds/flow_reminder.mp3'));
      } catch (e) {
        // Fallback: use system notification sound on Android
        debugPrint('Could not play custom sound, using haptic feedback');
        await HapticFeedback.heavyImpact();
      }
    } catch (e) {
      debugPrint('Error playing alarm: $e');
    }
  }
  
  /// Vibrate the device
  Future<void> _vibrate() async {
    if (kIsWeb) return;
    
    try {
      // Use HapticFeedback as a fallback that works cross-platform
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 200));
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 200));
      await HapticFeedback.heavyImpact();
    } catch (e) {
      debugPrint('Vibration error: $e');
    }
  }
  
  /// Start the reminder timer
  void _startReminderTimer(SafetyWindow window) {
    _reminderTimer?.cancel();
    
    _reminderTimer = Timer.periodic(
      Duration(minutes: reminderIntervalMinutes),
      (timer) async {
        // Check if we're still in the window
        final now = DateTime.now();
        if (!window.isInWindow(now) || !_isAlarmActive) {
          timer.cancel();
          _isAlarmActive = false;
          _activeWindowId = null;
          return;
        }
        
        debugPrint('🔔 Flow reminder for: ${window.name}');
        await _playAlarmSound();
        await _vibrate();
      },
    );
  }
  
  /// Stop the alarm (called when user presses ON IT)
  Future<void> stopAlarm() async {
    _isAlarmActive = false;
    _activeWindowId = null;
    _reminderTimer?.cancel();
    _reminderTimer = null;
    
    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint('Error stopping audio: $e');
    }
    
    debugPrint('🔕 Flow alarm stopped');
  }
  
  /// Acknowledge alarm for a specific window
  Future<void> acknowledgeWindow(String windowId) async {
    if (_activeWindowId == windowId) {
      await stopAlarm();
    }
  }
  
  /// Dispose resources
  void dispose() {
    _reminderTimer?.cancel();
    _audioPlayer.dispose();
  }
}
