import 'sync_model.dart';

/// Represents a single step in an IF-THEN guided flow
class GuidedStep {
  final String id;
  final String ifCondition; // The IF part: "IF you are done praying"
  final String thenAction;  // The THEN part: "THEN move your body"
  final String activityName; // Name for the activity log
  final String? description; // Optional longer description
  final List<String> suggestions; // Optional action suggestions
  final Duration? estimatedDuration; // Optional expected duration
  final String? nextStepId; // For flow chaining
  final bool isOptional;    // Step can be skipped
  final bool canSkipToEnd;  // Flow can end at this step

  const GuidedStep({
    required this.id,
    required this.ifCondition,
    required this.thenAction,
    required this.activityName,
    this.description,
    this.suggestions = const [],
    this.estimatedDuration,
    this.nextStepId,
    this.isOptional = false,
    this.canSkipToEnd = false,
  });

  String get fullPrompt => 'IF $ifCondition THEN $thenAction';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ifCondition': ifCondition,
      'thenAction': thenAction,
      'activityName': activityName,
      'description': description,
      'suggestions': suggestions.join('|'),
      'estimatedDuration': estimatedDuration?.inSeconds,
      'nextStepId': nextStepId,
      'isOptional': isOptional,
      'canSkipToEnd': canSkipToEnd,
    };
  }

  factory GuidedStep.fromMap(Map<String, dynamic> map) {
    return GuidedStep(
      id: map['id'] as String,
      ifCondition: map['ifCondition'] as String,
      thenAction: map['thenAction'] as String,
      activityName: map['activityName'] as String,
      description: map['description'] as String?,
      suggestions: (map['suggestions'] as String?)?.split('|') ?? [],
      estimatedDuration: map['estimatedDuration'] != null
          ? Duration(seconds: map['estimatedDuration'] as int)
          : null,
      nextStepId: map['nextStepId'] as String?,
      isOptional: map['isOptional'] as bool? ?? false,
      canSkipToEnd: map['canSkipToEnd'] as bool? ?? false,
    );
  }

  /// Create from Supabase database format
  factory GuidedStep.fromSupabase(Map<String, dynamic> map) {
    return GuidedStep(
      id: map['id'] as String,
      ifCondition: map['if_condition'] as String,
      thenAction: map['then_action'] as String,
      activityName: map['activity_name'] as String,
      description: map['description'] as String?,
      suggestions: (map['suggestions'] as String?)?.split('|') ?? [],
      estimatedDuration: map['estimated_seconds'] != null
          ? Duration(seconds: map['estimated_seconds'] as int)
          : null,
      nextStepId: map['next_step_id'] as String?,
      isOptional: map['is_optional'] as bool? ?? false,
      canSkipToEnd: map['can_skip_to_end'] as bool? ?? false,
    );
  }

  /// Convert to Supabase format
  Map<String, dynamic> toSupabaseMap(String flowId, int stepOrder) {
    return {
      'id': id,
      'flow_id': flowId,
      'step_order': stepOrder,
      'if_condition': ifCondition,
      'then_action': thenAction,
      'activity_name': activityName,
      'description': description,
      'suggestions': suggestions.isNotEmpty ? suggestions.join('|') : null,
      'estimated_seconds': estimatedDuration?.inSeconds,
      'next_step_id': nextStepId,
      'is_optional': isOptional,
      'can_skip_to_end': canSkipToEnd,
    };
  }
}

/// Flow type for categorization
enum FlowType {
  prayer('Prayer'),
  routine('Routine'),
  recovery('Recovery'),
  sleep('Sleep');

  final String displayName;
  const FlowType(this.displayName);

  static FlowType fromString(String value) {
    return FlowType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => FlowType.routine,
    );
  }
}

/// Represents an IF-THEN guided flow with multiple steps
class GuidedFlow {
  final String id;
  final String name; // e.g., "Subuh Routine"
  final String safetyWindowId; // Reference to safety window
  final String initialPrompt; // The first message shown to user
  final List<GuidedStep> steps;
  final FlowType flowType;
  final bool isActive;
  final DateTime? lastTriggered;
  final DateTime? lastCompleted;

  const GuidedFlow({
    required this.id,
    required this.name,
    required this.safetyWindowId,
    required this.initialPrompt,
    required this.steps,
    this.flowType = FlowType.routine,
    this.isActive = true,
    this.lastTriggered,
    this.lastCompleted,
  });

  GuidedFlow copyWith({
    String? id,
    String? name,
    String? safetyWindowId,
    String? initialPrompt,
    List<GuidedStep>? steps,
    FlowType? flowType,
    bool? isActive,
    DateTime? lastTriggered,
    DateTime? lastCompleted,
  }) {
    return GuidedFlow(
      id: id ?? this.id,
      name: name ?? this.name,
      safetyWindowId: safetyWindowId ?? this.safetyWindowId,
      initialPrompt: initialPrompt ?? this.initialPrompt,
      steps: steps ?? this.steps,
      flowType: flowType ?? this.flowType,
      isActive: isActive ?? this.isActive,
      lastTriggered: lastTriggered ?? this.lastTriggered,
      lastCompleted: lastCompleted ?? this.lastCompleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'safetyWindowId': safetyWindowId,
      'initialPrompt': initialPrompt,
      'flowType': flowType.name,
      'isActive': isActive ? 1 : 0,
      'lastTriggered': lastTriggered?.toIso8601String(),
      'lastCompleted': lastCompleted?.toIso8601String(),
    };
  }

  factory GuidedFlow.fromMap(Map<String, dynamic> map, List<GuidedStep> steps) {
    return GuidedFlow(
      id: map['id'] as String,
      name: map['name'] as String,
      safetyWindowId: map['safetyWindowId'] as String,
      initialPrompt: map['initialPrompt'] as String,
      steps: steps,
      flowType: FlowType.fromString(map['flowType'] as String? ?? 'routine'),
      isActive: (map['isActive'] as int?) == 1,
      lastTriggered: map['lastTriggered'] != null
          ? DateTime.parse(map['lastTriggered'] as String)
          : null,
      lastCompleted: map['lastCompleted'] != null
          ? DateTime.parse(map['lastCompleted'] as String)
          : null,
    );
  }

  /// Create from Supabase database format
  factory GuidedFlow.fromSupabase(Map<String, dynamic> map, List<GuidedStep> steps) {
    return GuidedFlow(
      id: map['id'] as String,
      name: map['name'] as String,
      safetyWindowId: map['safety_window_id'] as String? ?? '',
      initialPrompt: map['initial_prompt'] as String? ?? '',
      steps: steps,
      flowType: FlowType.fromString(map['flow_type'] as String? ?? 'routine'),
      isActive: map['is_active'] as bool? ?? true,
      lastTriggered: null,
      lastCompleted: null,
    );
  }

  /// Convert to Supabase format for insert/update
  Map<String, dynamic> toSupabaseMap({String? userId}) {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'safety_window_id': safetyWindowId.isEmpty ? null : safetyWindowId,
      'initial_prompt': initialPrompt,
      'flow_type': flowType.name,
      'is_active': isActive,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}

/// Represents the current state of an active guided flow execution
enum GuidedFlowState {
  idle,        // No flow active
  waiting,     // Showing initial prompt, waiting for "ON IT"
  inProgress,  // User tapped "ON IT", activity running
  completing,  // Showing "Are you done?" for current step
}

/// Log entry for a guided flow execution
class GuidedFlowLog implements SyncableModel {
  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final String? deviceId;
  @override
  final SyncStatus syncStatus;

  final String? userId;

  final String flowId;
  final String flowName;
  final DateTime triggeredAt;
  final DateTime? completedAt;
  final int stepsCompleted;
  final int totalSteps;
  final bool wasAbandoned;
  final bool wasMissed; // Window passed without confirmation
  final bool wasSkippedHaid; // Skipped due to Haid Mode active

  GuidedFlowLog({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deviceId,
    this.syncStatus = SyncStatus.pending,
    this.userId,
    required this.flowId,
    required this.flowName,
    required this.triggeredAt,
    this.completedAt,
    this.stepsCompleted = 0,
    required this.totalSteps,
    this.wasAbandoned = false,
    this.wasMissed = false,
    this.wasSkippedHaid = false,
  }) : 
    id = id ?? UuidHelper.generate(),
    createdAt = createdAt ?? DateTime.now().toUtc(),
    updatedAt = updatedAt ?? DateTime.now().toUtc();

  bool get isCompleted => stepsCompleted >= totalSteps && !wasAbandoned && !wasMissed && !wasSkippedHaid;
  
  /// Check if flow was skipped due to Haid Mode
  bool get isSkippedDueToHaid => wasSkippedHaid;

  Duration get duration {
    final end = completedAt ?? DateTime.now().toUtc();
    return end.difference(triggeredAt);
  }

  GuidedFlowLog copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? deviceId,
    SyncStatus? syncStatus,
    String? userId,
    String? flowId,
    String? flowName,
    DateTime? triggeredAt,
    DateTime? completedAt,
    int? stepsCompleted,
    int? totalSteps,
    bool? wasAbandoned,
    bool? wasMissed,
    bool? wasSkippedHaid,
  }) {
    return GuidedFlowLog(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
      syncStatus: syncStatus ?? SyncStatus.pending,
      userId: userId ?? this.userId,
      flowId: flowId ?? this.flowId,
      flowName: flowName ?? this.flowName,
      triggeredAt: triggeredAt ?? this.triggeredAt,
      completedAt: completedAt ?? this.completedAt,
      stepsCompleted: stepsCompleted ?? this.stepsCompleted,
      totalSteps: totalSteps ?? this.totalSteps,
      wasAbandoned: wasAbandoned ?? this.wasAbandoned,
      wasMissed: wasMissed ?? this.wasMissed,
      wasSkippedHaid: wasSkippedHaid ?? this.wasSkippedHaid,
    );
  }

  @override
  GuidedFlowLog copyWithStatus(SyncStatus status) {
    return copyWith(syncStatus: status, updatedAt: updatedAt);
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'device_id': deviceId,
      'sync_status': syncStatus.index,
      'flow_id': flowId,
      'flow_name': flowName,
      'triggered_at': triggeredAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'steps_completed': stepsCompleted,
      'total_steps': totalSteps,
      'was_abandoned': wasAbandoned ? 1 : 0,
      'was_missed': wasMissed ? 1 : 0,
      'was_skipped_haid': wasSkippedHaid ? 1 : 0,
    };
  }

  @override
  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'device_id': deviceId,
      'user_id': userId,
      'flow_id': flowId,
      'flow_name': flowName,
      'triggered_at': triggeredAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'steps_completed': stepsCompleted,
      'total_steps': totalSteps,
      'was_abandoned': wasAbandoned ? 1 : 0,
      'was_missed': wasMissed ? 1 : 0,
      'was_skipped_haid': wasSkippedHaid ? 1 : 0,
    };
  }

  factory GuidedFlowLog.fromMap(Map<String, dynamic> map) {
    return GuidedFlowLog(
      id: map['id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      deviceId: map['device_id'] as String?,
      syncStatus: SyncStatus.values[map['sync_status'] as int? ?? 1],
      flowId: map['flow_id'] as String,
      flowName: map['flow_name'] as String,
      triggeredAt: DateTime.parse(map['triggered_at'] as String),
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      stepsCompleted: map['steps_completed'] as int? ?? 0,
      totalSteps: map['total_steps'] as int,
      wasAbandoned: (map['was_abandoned'] as int?) == 1,
      wasMissed: (map['was_missed'] as int?) == 1,
      wasSkippedHaid: (map['was_skipped_haid'] as int?) == 1,
    );
  }

  /// Factory for parsing Supabase response
  factory GuidedFlowLog.fromSupabaseMap(Map<String, dynamic> map) {
    return GuidedFlowLog(
      id: map['id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      deviceId: map['device_id'] as String?,
      syncStatus: SyncStatus.synced,
      flowId: map['flow_id'] as String,
      flowName: map['flow_name'] as String,
      triggeredAt: DateTime.parse(map['triggered_at'] as String),
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      stepsCompleted: map['steps_completed'] as int? ?? 0,
      totalSteps: map['total_steps'] as int,
      wasAbandoned: (map['was_abandoned'] as int?) == 1,
      wasMissed: (map['was_missed'] as int?) == 1,
      wasSkippedHaid: (map['was_skipped_haid'] as int?) == 1,
    );
  }
}
