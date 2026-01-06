import '../models/activity.dart';

/// Service for determining which mascot asset to display based on activity state.
/// 
/// Mascot Rules:
/// - capy_weight_lift: Deep Work / Workout activities
/// - weekend_duck_float: Break / Weekend / Rest / Leisure activities
/// - capy_on_flying_duck: Travel / Commute activities
/// - potato_duck_prayer_break: Prayer flow windows
/// - shy_duck_idle: Idle reflection prompt (30 min no activity)
/// - angry_duck_knife: Distraction/pause reflection
/// - cleaning: Cleaning / Household activities
class MascotService {
  static const String _basePath = 'assets/mascots/';
  
  // Asset file names
  static const String deepWorkMascot = '${_basePath}capy_weight_lift.png';
  static const String weekendMascot = '${_basePath}weekend_duck_float.png';
  static const String travelMascot = '${_basePath}capy_on_flying_duck.png';
  static const String prayerMascot = '${_basePath}potato_duck_prayer_break.png';
  static const String idleMascot = '${_basePath}shy_duck_idle.png';
  static const String distractionMascot = '${_basePath}angry_duck_knife.png';
  static const String cleaningMascot = '${_basePath}cleaning.png';
  
  /// Get the appropriate mascot asset for an activity.
  /// Returns null if no specific mascot applies.
  static String? getMascotAsset(Activity activity) {
    final name = activity.name.toLowerCase();
    final category = activity.category.toLowerCase();
    final now = DateTime.now();
    final isWeekend = now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
    
    // Deep Work / Workout → capy_weight_lift
    if (_isDeepWorkOrWorkout(name, category)) {
      return deepWorkMascot;
    }
    
    // Prayer flow → potato_duck_prayer_break
    if (_isPrayerFlow(activity)) {
      return prayerMascot;
    }
    
    // Cleaning / Household → cleaning.png
    if (_isCleaningOrHousehold(name, category)) {
      return cleaningMascot;
    }
    
    // Travel / Commute → capy_on_flying_duck
    if (_isTravelOrCommute(name, category)) {
      return travelMascot;
    }
    
    // Break / Weekend / Rest / Leisure → weekend_duck_float
    if (_isBreakOrRestOrLeisure(name, category, isWeekend)) {
      return weekendMascot;
    }
    
    // No specific mascot for this activity
    return null;
  }
  
  /// Check if activity is Deep Work or Workout
  static bool _isDeepWorkOrWorkout(String name, String category) {
    const deepWorkKeywords = ['deep work', 'deepwork', 'fokus', 'focus'];
    const workoutKeywords = ['workout', 'exercise', 'gym', 'olahraga', 'fitness'];
    
    for (final keyword in deepWorkKeywords) {
      if (name.contains(keyword) || category.contains(keyword)) {
        return true;
      }
    }
    
    for (final keyword in workoutKeywords) {
      if (name.contains(keyword) || category.contains(keyword)) {
        return true;
      }
    }
    
    return false;
  }
  
  /// Check if activity is a prayer flow
  static bool _isPrayerFlow(Activity activity) {
    if (activity.guidedFlowId == null) return false;
    
    final flowId = activity.guidedFlowId!.toLowerCase();
    const prayerKeywords = ['prayer', 'sholat', 'salat', 'ibadah', 'dzikir', 'quran'];
    
    for (final keyword in prayerKeywords) {
      if (flowId.contains(keyword)) {
        return true;
      }
    }
    
    // Also check activity name/category for prayer-related content
    final name = activity.name.toLowerCase();
    final category = activity.category.toLowerCase();
    
    for (final keyword in prayerKeywords) {
      if (name.contains(keyword) || category.contains(keyword)) {
        return true;
      }
    }
    
    return false;
  }
  
  /// Check if activity is Travel or Commute
  static bool _isTravelOrCommute(String name, String category) {
    const travelKeywords = [
      'travel', 'commute', 'on the way', 'perjalanan', 
      'jalan', 'berangkat', 'pulang', 'transit', 'driving',
      'naik', 'ke kantor', 'ke rumah'
    ];
    
    for (final keyword in travelKeywords) {
      if (name.contains(keyword) || category.contains(keyword)) {
        return true;
      }
    }
    
    // Check if category is explicitly "Commute"
    if (category == 'commute') {
      return true;
    }
    
    return false;
  }
  
  /// Check if activity is Cleaning or Household
  static bool _isCleaningOrHousehold(String name, String category) {
    const cleaningKeywords = [
      'cleaning', 'clean', 'bersih', 'cuci', 'laundry',
      'nyapu', 'ngepel', 'household', 'rumah tangga', 'merapikan'
    ];
    
    for (final keyword in cleaningKeywords) {
      if (name.contains(keyword) || category.contains(keyword)) {
        return true;
      }
    }
    
    // Check if category is explicitly "Cleaning"
    if (category == 'cleaning') {
      return true;
    }
    
    return false;
  }
  
  /// Check if activity is Break, Rest, or Leisure
  static bool _isBreakOrRestOrLeisure(String name, String category, bool isWeekend) {
    const breakKeywords = [
      'break', 'rest', 'istirahat', 'santai', 'relax',
      'chill', 'rehat', 'tidur', 'sleep', 'nap',
      'leisure', 'fun', 'game', 'hiburan', 'nonton', 'watch'
    ];
    
    // Weekend automatically gets weekend mascot if no other mascot applies
    if (isWeekend) {
      return true;
    }
    
    // Check for break/rest/leisure keywords
    for (final keyword in breakKeywords) {
      if (name.contains(keyword) || category.contains(keyword)) {
        return true;
      }
    }
    
    // Check if category is explicitly "Break" or "Leisure"
    if (category == 'break' || category == 'leisure') {
      return true;
    }
    
    return false;
  }
  
  /// Get mascot for idle reflection prompt
  static String getIdleMascot() => idleMascot;
  
  /// Get mascot for distraction/pause reflection
  static String getDistractionMascot() => distractionMascot;
  
  /// Get mascot for prayer flow window
  static String getPrayerMascot() => prayerMascot;
  
  /// Get mascot for cleaning activities
  static String getCleaningMascot() => cleaningMascot;
  
  /// Get mascot for commute/travel
  static String getCommuteMascot() => travelMascot;
  
  /// Get mascot for leisure activities
  static String getLeisureMascot() => weekendMascot;
}
