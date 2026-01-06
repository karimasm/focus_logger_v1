/// Defines a time window during which a guided flow can be triggered
/// Flows only activate within these hard-bound safety hours
class SafetyWindow {
  final String id;
  final String name;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final String linkedFlowId;
  final bool isActive;

  const SafetyWindow({
    required this.id,
    required this.name,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.linkedFlowId,
    this.isActive = true,
  });

  /// Check if current time is within this safety window
  bool isInWindow(DateTime now) {
    if (!isActive) return false;
    
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = startHour * 60 + startMinute;
    final endMinutes = endHour * 60 + endMinute;
    
    return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
  }

  /// Check if the window has passed for today
  bool hasPassed(DateTime now) {
    final currentMinutes = now.hour * 60 + now.minute;
    final endMinutes = endHour * 60 + endMinute;
    return currentMinutes > endMinutes;
  }

  /// Get time remaining in window (returns null if not in window)
  Duration? timeRemaining(DateTime now) {
    if (!isInWindow(now)) return null;
    
    final endTime = DateTime(now.year, now.month, now.day, endHour, endMinute);
    return endTime.difference(now);
  }

  String get formattedWindow {
    final startStr = '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}';
    final endStr = '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';
    return '$startStr – $endStr';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'startHour': startHour,
      'startMinute': startMinute,
      'endHour': endHour,
      'endMinute': endMinute,
      'linkedFlowId': linkedFlowId,
      'isActive': isActive ? 1 : 0,
    };
  }

  factory SafetyWindow.fromMap(Map<String, dynamic> map) {
    return SafetyWindow(
      id: map['id'] as String,
      name: map['name'] as String,
      startHour: map['startHour'] as int,
      startMinute: map['startMinute'] as int,
      endHour: map['endHour'] as int,
      endMinute: map['endMinute'] as int,
      linkedFlowId: map['linkedFlowId'] as String,
      isActive: (map['isActive'] as int?) == 1,
    );
  }
}

/// Predefined safety windows for Islamic prayer times and daily rituals
class PredefinedSafetyWindows {
  static const subuh = SafetyWindow(
    id: 'window_subuh',
    name: 'Subuh',
    startHour: 5,
    startMinute: 0,
    endHour: 5,
    endMinute: 30,
    linkedFlowId: 'subuh_flow',
  );

  static const dzuhur = SafetyWindow(
    id: 'window_dzuhur',
    name: 'Dzuhur',
    startHour: 12,
    startMinute: 0,
    endHour: 13,
    endMinute: 0,
    linkedFlowId: 'dzuhur_flow',
  );

  static const ashar = SafetyWindow(
    id: 'window_ashar',
    name: 'Ashar',
    startHour: 15,
    startMinute: 0,
    endHour: 16,
    endMinute: 0,
    linkedFlowId: 'ashar_flow',
  );

  static const magrib = SafetyWindow(
    id: 'window_magrib',
    name: 'Magrib',
    startHour: 18,
    startMinute: 30,
    endHour: 18,
    endMinute: 50,
    linkedFlowId: 'magrib_flow',
  );

  static const isya = SafetyWindow(
    id: 'window_isya',
    name: 'Isya',
    startHour: 19,
    startMinute: 30,
    endHour: 20,
    endMinute: 0,
    linkedFlowId: 'isya_flow',
  );

  static const sleep = SafetyWindow(
    id: 'window_sleep',
    name: 'Sleep / Wind-down',
    startHour: 23,
    startMinute: 0,
    endHour: 23,
    endMinute: 30,
    linkedFlowId: 'sleep_flow',
  );

  static List<SafetyWindow> get all => [
    subuh,
    dzuhur,
    ashar,
    magrib,
    isya,
    sleep,
  ];

  /// Get the current active window (if any)
  static SafetyWindow? getCurrentWindow(DateTime now) {
    for (final window in all) {
      if (window.isInWindow(now)) {
        return window;
      }
    }
    return null;
  }

  /// Get windows that have passed today without completion
  static List<SafetyWindow> getMissedWindows(DateTime now, Set<String> completedFlowIds) {
    return all.where((w) => w.hasPassed(now) && !completedFlowIds.contains(w.linkedFlowId)).toList();
  }
}
