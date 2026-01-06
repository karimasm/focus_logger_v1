import 'package:shared_preferences/shared_preferences.dart';
import '../data/data.dart';
import '../models/user_flow_template.dart';

/// Service untuk seed default flows ke database
/// Ini berjalan sekali saat pertama kali app diinstall
class FlowSeederService {
  static const String _seededKey = 'flows_seeded_v2';
  
  /// Check if default flows need to be seeded
  static Future<bool> needsSeeding() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_seededKey) ?? false);
  }
  
  /// Seed default flows to database
  static Future<void> seedDefaultFlows() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if already seeded
    if (prefs.getBool(_seededKey) == true) {
      return;
    }
    
    // Get existing templates to avoid duplicates
    final existingTemplates = await dataRepository.getAllUserFlowTemplates();
    final existingIds = existingTemplates.map((t) => t.id).toSet();
    
    // Convert predefined flows to UserFlowTemplates
    final defaultTemplates = _getDefaultTemplates();
    
    for (final template in defaultTemplates) {
      if (!existingIds.contains(template.id)) {
        await dataRepository.insertUserFlowTemplate(template);
      }
    }
    
    // Mark as seeded
    await prefs.setBool(_seededKey, true);
  }
  
  /// Helper to create steps
  static UserFlowStep _step(
    String id, 
    String flowId, 
    int order,
    String ifCond, 
    String thenAct, 
    String actName, 
    {String? desc, int? mins}
  ) {
    return UserFlowStep(
      id: id,
      flowTemplateId: flowId,
      stepOrder: order,
      ifCondition: ifCond,
      thenAction: thenAct,
      activityName: actName,
      description: desc,
      estimatedMinutes: mins,
    );
  }
  
  /// Get default flow templates
  static List<UserFlowTemplate> _getDefaultTemplates() {
    return [
      // Subuh Routine
      UserFlowTemplate(
        id: 'subuh_flow',
        name: 'Subuh Routine',
        category: 'prayer',
        linkedSafetyWindowId: 'window_subuh',
        initialPrompt: 'Wake up and pray Subuh',
        steps: [
          _step('subuh_prayer', 'subuh_flow', 1, 
            'time is in Subuh window', 'pray Subuh', 'Sholat Subuh',
            desc: 'Perform your Subuh prayer', mins: 10),
          _step('subuh_movement', 'subuh_flow', 2,
            'you are done praying', 'move your body', 'Morning Movement',
            desc: 'Light physical activity to wake up', mins: 5),
        ],
        isActive: true,
      ),
      
      // Dzuhur Routine
      UserFlowTemplate(
        id: 'dzuhur_flow',
        name: 'Dzuhur Routine',
        category: 'prayer',
        linkedSafetyWindowId: 'window_dzuhur',
        initialPrompt: 'Time for Dzuhur prayer',
        steps: [
          _step('dzuhur_prayer', 'dzuhur_flow', 1,
            'time is in Dzuhur window', 'pray Dzuhur', 'Sholat Dzuhur',
            desc: 'Perform your Dzuhur prayer', mins: 10),
          _step('dzuhur_lunch', 'dzuhur_flow', 2,
            'you are done praying', 'have lunch or take a nap', 'Lunch / Nap',
            desc: 'Rest and recharge', mins: 45),
          _step('dzuhur_return', 'dzuhur_flow', 3,
            'you finished lunch/nap', 'return to work', 'Return to Work',
            desc: 'Transition back to work mode at 13:30', mins: 5),
        ],
        isActive: true,
      ),
      
      // Ashar Routine
      UserFlowTemplate(
        id: 'ashar_flow',
        name: 'Ashar Routine',
        category: 'prayer',
        linkedSafetyWindowId: 'window_ashar',
        initialPrompt: 'Time for Ashar prayer',
        steps: [
          _step('ashar_prayer', 'ashar_flow', 1,
            'time is in Ashar window', 'pray Ashar', 'Sholat Ashar',
            desc: 'Perform your Ashar prayer', mins: 10),
          _step('ashar_return', 'ashar_flow', 2,
            'you are done praying', 'return to work', 'Return to Work',
            desc: 'Continue your afternoon work session', mins: 5),
        ],
        isActive: true,
      ),
      
      // Magrib Routine
      UserFlowTemplate(
        id: 'magrib_flow',
        name: 'Magrib Routine',
        category: 'prayer',
        linkedSafetyWindowId: 'window_magrib',
        initialPrompt: 'Time for Magrib prayer',
        steps: [
          _step('magrib_prayer', 'magrib_flow', 1,
            'time is in Magrib window', 'pray Magrib', 'Sholat Magrib',
            desc: 'Perform your Magrib prayer', mins: 10),
          _step('magrib_dinner', 'magrib_flow', 2,
            'you are done praying', 'have dinner', 'Dinner',
            desc: 'Evening meal time', mins: 30),
          _step('magrib_quran', 'magrib_flow', 3,
            'you finished dinner', 'write 1 Al-Quran verse', 'Quran - One Verse',
            desc: 'Manual handwriting / copying of one verse', mins: 15),
        ],
        isActive: true,
      ),
      
      // Isya Routine
      UserFlowTemplate(
        id: 'isya_flow',
        name: 'Isya Routine',
        category: 'prayer',
        linkedSafetyWindowId: 'window_isya',
        initialPrompt: 'Time for Isya prayer',
        steps: [
          _step('isya_prayer', 'isya_flow', 1,
            'time is in Isya window', 'pray Isya', 'Sholat Isya',
            desc: 'Perform your Isya prayer', mins: 10),
          _step('isya_skincare', 'isya_flow', 2,
            'you are done praying', 'do your skincare routine', 'Skincare Routine',
            desc: 'Evening skincare', mins: 10),
          _step('isya_planning', 'isya_flow', 3,
            'you finished skincare', 'set tasks for tomorrow', 'Tomorrow Planning',
            desc: 'Small planning set for next day', mins: 10),
        ],
        isActive: true,
      ),
      
      // Sleep Discipline
      UserFlowTemplate(
        id: 'sleep_flow',
        name: 'Sleep Discipline',
        category: 'sleep',
        linkedSafetyWindowId: 'window_sleep',
        initialPrompt: 'Time to prepare for sleep',
        steps: [
          _step('sleep_prepare', 'sleep_flow', 1,
            'time is in Sleep window', 'prepare for tomorrow', 'Prepare Tomorrow',
            desc: 'Clear desk, layout items, mental unload', mins: 10),
          _step('sleep_winddown', 'sleep_flow', 2,
            'you prepared everything', 'wind down', 'Wind-Down',
            desc: 'Light reflection, calm your mind', mins: 10),
          _step('sleep_sleep', 'sleep_flow', 3,
            'you are calm', 'go to sleep', 'Sleep',
            desc: 'Time to rest', mins: 5),
        ],
        isActive: true,
      ),
      
      // Distraction Recovery
      UserFlowTemplate(
        id: 'distraction_recovery',
        name: 'Distraction Recovery',
        category: 'recovery',
        linkedSafetyWindowId: null,
        initialPrompt: "You were distracted. Let's get back on track.",
        steps: [
          _step('recovery_recall', 'distraction_recovery', 1,
            'you were distracted', 'recall what you were doing', 'Focus Recovery',
            desc: 'Take a moment to remember your previous task', mins: 2),
        ],
        isActive: true,
      ),
    ];
  }
}
