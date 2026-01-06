import '../data/data.dart';
import '../models/user_flow_template.dart';

/// Service to access flow templates from database
/// 
/// NOTE: Default flows are now seeded via FlowSeederService at app startup.
/// This class provides utility methods to query templates.
class FlowTemplateSeeder {
  final DataRepository _repo = dataRepository;
  
  /// Get a UserFlowTemplate by its linked safety window ID
  /// Used by the enforcement engine to find which template to execute
  Future<UserFlowTemplate?> getTemplateForWindow(String windowId) async {
    final templates = await _repo.getAllUserFlowTemplates();
    try {
      return templates.firstWhere((t) => t.linkedSafetyWindowId == windowId);
    } catch (_) {
      return null;
    }
  }
  
  /// Get a UserFlowTemplate by its ID
  Future<UserFlowTemplate?> getTemplateById(String templateId) async {
    return await _repo.getUserFlowTemplate(templateId);
  }
  
  /// Get all active templates
  Future<List<UserFlowTemplate>> getAllActiveTemplates() async {
    final templates = await _repo.getAllUserFlowTemplates();
    return templates.where((t) => t.isActive).toList();
  }
  
  /// Get templates by category
  Future<List<UserFlowTemplate>> getTemplatesByCategory(String category) async {
    final templates = await _repo.getAllUserFlowTemplates();
    return templates.where((t) => t.category == category).toList();
  }
}
