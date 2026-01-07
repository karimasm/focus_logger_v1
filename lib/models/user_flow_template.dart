import 'package:uuid/uuid.dart';

/// Represents a user-editable flow template step
/// These are stored in the database and can be modified by the user
class UserFlowStep {
  final String id;
  final String flowTemplateId;
  final int stepOrder;
  final String ifCondition;
  final String thenAction;
  final String activityName;
  final String? description;
  final int? estimatedMinutes;
  final bool isOptional;      // Step can be skipped
  final bool canSkipToEnd;    // Flow can end at this step

  UserFlowStep({
    String? id,
    required this.flowTemplateId,
    required this.stepOrder,
    required this.ifCondition,
    required this.thenAction,
    required this.activityName,
    this.description,
    this.estimatedMinutes,
    this.isOptional = false,
    this.canSkipToEnd = false,
  }) : id = id ?? const Uuid().v4();

  String get fullPrompt => 'IF $ifCondition THEN $thenAction';

  UserFlowStep copyWith({
    String? id,
    String? flowTemplateId,
    int? stepOrder,
    String? ifCondition,
    String? thenAction,
    String? activityName,
    String? description,
    int? estimatedMinutes,
    bool? isOptional,
    bool? canSkipToEnd,
  }) {
    return UserFlowStep(
      id: id ?? this.id,
      flowTemplateId: flowTemplateId ?? this.flowTemplateId,
      stepOrder: stepOrder ?? this.stepOrder,
      ifCondition: ifCondition ?? this.ifCondition,
      thenAction: thenAction ?? this.thenAction,
      activityName: activityName ?? this.activityName,
      description: description ?? this.description,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      isOptional: isOptional ?? this.isOptional,
      canSkipToEnd: canSkipToEnd ?? this.canSkipToEnd,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'flow_template_id': flowTemplateId,
      'step_order': stepOrder,
      'if_condition': ifCondition,
      'then_action': thenAction,
      'activity_name': activityName,
      'description': description,
      'estimated_minutes': estimatedMinutes,
      'is_optional': isOptional,
      'can_skip_to_end': canSkipToEnd,
    };
  }

  factory UserFlowStep.fromMap(Map<String, dynamic> map) {
    return UserFlowStep(
      id: map['id'] as String,
      flowTemplateId: map['flow_template_id'] as String,
      stepOrder: map['step_order'] as int,
      ifCondition: map['if_condition'] as String,
      thenAction: map['then_action'] as String,
      activityName: map['activity_name'] as String,
      description: map['description'] as String?,
      estimatedMinutes: map['estimated_minutes'] as int?,
      isOptional: map['is_optional'] as bool? ?? false,
      canSkipToEnd: map['can_skip_to_end'] as bool? ?? false,
    );
  }
}

/// User-editable flow template 
/// Stored in database, distinct from predefined flows
class UserFlowTemplate {
  final String id;
  final String name;
  final String category; // e.g., "Prayer", "Routine", "Recovery"
  final String? linkedSafetyWindowId; // Optional link to safety window for auto-trigger
  final String initialPrompt;
  final List<UserFlowStep> steps;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserFlowTemplate({
    String? id,
    required this.name,
    required this.category,
    this.linkedSafetyWindowId,
    required this.initialPrompt,
    this.steps = const [],
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : 
    id = id ?? const Uuid().v4(),
    createdAt = createdAt ?? DateTime.now().toUtc(),
    updatedAt = updatedAt ?? DateTime.now().toUtc();

  UserFlowTemplate copyWith({
    String? id,
    String? name,
    String? category,
    String? linkedSafetyWindowId,
    String? initialPrompt,
    List<UserFlowStep>? steps,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserFlowTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      linkedSafetyWindowId: linkedSafetyWindowId ?? this.linkedSafetyWindowId,
      initialPrompt: initialPrompt ?? this.initialPrompt,
      steps: steps ?? this.steps,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'linked_safety_window_id': linkedSafetyWindowId,
      'initial_prompt': initialPrompt,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory UserFlowTemplate.fromMap(Map<String, dynamic> map, List<UserFlowStep> steps) {
    return UserFlowTemplate(
      id: map['id'] as String,
      name: map['name'] as String,
      category: map['category'] as String,
      linkedSafetyWindowId: map['linked_safety_window_id'] as String?,
      initialPrompt: map['initial_prompt'] as String,
      steps: steps,
      isActive: (map['is_active'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
