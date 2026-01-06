import 'package:uuid/uuid.dart';
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

  const GuidedStep({
    required this.id,
    required this.ifCondition,
    required this.thenAction,
    required this.activityName,
    this.description,
    this.suggestions = const [],
    this.estimatedDuration,
    this.nextStepId,
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
    );
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
    createdAt = createdAt ?? DateTime.now(),
    updatedAt = updatedAt ?? DateTime.now();

  bool get isCompleted => stepsCompleted >= totalSteps && !wasAbandoned && !wasMissed && !wasSkippedHaid;
  
  /// Check if flow was skipped due to Haid Mode
  bool get isSkippedDueToHaid => wasSkippedHaid;

  Duration get duration {
    final end = completedAt ?? DateTime.now();
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

/// All predefined guided flows for prayer and daily routines
class PredefinedFlows {
  // ==================== SUBUH FLOW ====================
  static final subuhFlow = GuidedFlow(
    id: 'subuh_flow',
    name: 'Subuh Routine',
    safetyWindowId: 'window_subuh',
    initialPrompt: 'Wake up and pray Subuh',
    flowType: FlowType.prayer,
    steps: [
      const GuidedStep(
        id: 'subuh_prayer',
        ifCondition: 'time is in Subuh window',
        thenAction: 'pray Subuh',
        activityName: 'Sholat Subuh (guided)',
        description: 'Perform your Subuh prayer',
        estimatedDuration: Duration(minutes: 10),
      ),
      const GuidedStep(
        id: 'subuh_movement',
        ifCondition: 'you are done praying',
        thenAction: 'move your body',
        activityName: 'Morning Movement (guided)',
        description: 'Light physical activity to wake up',
        suggestions: ['Shake your body', 'Stretch', 'Skipping', 'Short walk'],
        estimatedDuration: Duration(minutes: 5),
      ),
    ],
  );

  // ==================== DZUHUR FLOW ====================
  static final dzuhurFlow = GuidedFlow(
    id: 'dzuhur_flow',
    name: 'Dzuhur Routine',
    safetyWindowId: 'window_dzuhur',
    initialPrompt: 'Time for Dzuhur prayer',
    flowType: FlowType.prayer,
    steps: [
      const GuidedStep(
        id: 'dzuhur_prayer',
        ifCondition: 'time is in Dzuhur window',
        thenAction: 'pray Dzuhur',
        activityName: 'Sholat Dzuhur (guided)',
        description: 'Perform your Dzuhur prayer',
        estimatedDuration: Duration(minutes: 10),
      ),
      const GuidedStep(
        id: 'dzuhur_lunch',
        ifCondition: 'you are done praying',
        thenAction: 'have lunch or take a nap',
        activityName: 'Lunch / Nap (guided)',
        description: 'Rest and recharge',
        suggestions: ['Eat lunch', 'Take a short nap', 'Light rest'],
        estimatedDuration: Duration(minutes: 45),
      ),
      const GuidedStep(
        id: 'dzuhur_return',
        ifCondition: 'you finished lunch/nap',
        thenAction: 'return to work',
        activityName: 'Return to Work (guided)',
        description: 'Transition back to work mode at 13:30',
        estimatedDuration: Duration(minutes: 5),
      ),
    ],
  );

  // ==================== ASHAR FLOW ====================
  static final asharFlow = GuidedFlow(
    id: 'ashar_flow',
    name: 'Ashar Routine',
    safetyWindowId: 'window_ashar',
    initialPrompt: 'Time for Ashar prayer',
    flowType: FlowType.prayer,
    steps: [
      const GuidedStep(
        id: 'ashar_prayer',
        ifCondition: 'time is in Ashar window',
        thenAction: 'pray Ashar',
        activityName: 'Sholat Ashar (guided)',
        description: 'Perform your Ashar prayer',
        estimatedDuration: Duration(minutes: 10),
      ),
      const GuidedStep(
        id: 'ashar_return',
        ifCondition: 'you are done praying',
        thenAction: 'return to work',
        activityName: 'Return to Work (guided)',
        description: 'Continue your afternoon work session',
        estimatedDuration: Duration(minutes: 5),
      ),
    ],
  );

  // ==================== MAGRIB FLOW ====================
  static final magribFlow = GuidedFlow(
    id: 'magrib_flow',
    name: 'Magrib Routine',
    safetyWindowId: 'window_magrib',
    initialPrompt: 'Time for Magrib prayer',
    flowType: FlowType.prayer,
    steps: [
      const GuidedStep(
        id: 'magrib_prayer',
        ifCondition: 'time is in Magrib window',
        thenAction: 'pray Magrib',
        activityName: 'Sholat Magrib (guided)',
        description: 'Perform your Magrib prayer',
        estimatedDuration: Duration(minutes: 10),
      ),
      const GuidedStep(
        id: 'magrib_dinner',
        ifCondition: 'you are done praying',
        thenAction: 'have dinner',
        activityName: 'Dinner (guided)',
        description: 'Evening meal time',
        estimatedDuration: Duration(minutes: 30),
      ),
      const GuidedStep(
        id: 'magrib_quran',
        ifCondition: 'you finished dinner',
        thenAction: 'write 1 Al-Quran verse',
        activityName: 'Quran - One Verse (guided)',
        description: 'Manual handwriting / copying of one verse',
        suggestions: ['Copy by hand', 'Reflect on meaning'],
        estimatedDuration: Duration(minutes: 15),
      ),
    ],
  );

  // ==================== ISYA FLOW ====================
  static final isyaFlow = GuidedFlow(
    id: 'isya_flow',
    name: 'Isya Routine',
    safetyWindowId: 'window_isya',
    initialPrompt: 'Time for Isya prayer',
    flowType: FlowType.prayer,
    steps: [
      const GuidedStep(
        id: 'isya_prayer',
        ifCondition: 'time is in Isya window',
        thenAction: 'pray Isya',
        activityName: 'Sholat Isya (guided)',
        description: 'Perform your Isya prayer',
        estimatedDuration: Duration(minutes: 10),
      ),
      const GuidedStep(
        id: 'isya_skincare',
        ifCondition: 'you are done praying',
        thenAction: 'do your skincare routine',
        activityName: 'Skincare Routine (guided)',
        description: 'Evening skincare',
        estimatedDuration: Duration(minutes: 10),
      ),
      const GuidedStep(
        id: 'isya_planning',
        ifCondition: 'you finished skincare',
        thenAction: 'set tasks for tomorrow',
        activityName: 'Tomorrow Planning (guided)',
        description: 'Small planning set for next day',
        suggestions: ['Review today', 'Set 3 priorities', 'Prepare materials'],
        estimatedDuration: Duration(minutes: 10),
      ),
    ],
  );

  // ==================== SLEEP FLOW ====================
  static final sleepFlow = GuidedFlow(
    id: 'sleep_flow',
    name: 'Sleep Discipline',
    safetyWindowId: 'window_sleep',
    initialPrompt: 'Time to prepare for sleep',
    flowType: FlowType.sleep,
    steps: [
      const GuidedStep(
        id: 'sleep_prepare',
        ifCondition: 'time is in Sleep window',
        thenAction: 'prepare for tomorrow',
        activityName: 'Prepare Tomorrow (guided)',
        description: 'Clear desk, layout items, mental unload',
        suggestions: ['Clear desk', 'Set out clothes', 'Pack bag'],
        estimatedDuration: Duration(minutes: 10),
      ),
      const GuidedStep(
        id: 'sleep_winddown',
        ifCondition: 'you prepared everything',
        thenAction: 'wind down',
        activityName: 'Wind-Down (guided)',
        description: 'Light reflection, calm your mind',
        suggestions: ['Deep breathing', 'Light reading', 'Gratitude'],
        estimatedDuration: Duration(minutes: 10),
      ),
      const GuidedStep(
        id: 'sleep_sleep',
        ifCondition: 'you are calm',
        thenAction: 'go to sleep',
        activityName: 'Sleep (guided)',
        description: 'Time to rest',
        estimatedDuration: Duration(minutes: 5),
      ),
    ],
  );

  // ==================== DISTRACTION RECOVERY FLOW ====================
  static final distractionRecoveryFlow = GuidedFlow(
    id: 'distraction_recovery',
    name: 'Distraction Recovery',
    safetyWindowId: '', // No window - triggered by pause resume
    initialPrompt: 'You were distracted. Let\'s get back on track.',
    flowType: FlowType.recovery,
    steps: [
      const GuidedStep(
        id: 'recovery_recall',
        ifCondition: 'you were distracted',
        thenAction: 'recall what you were doing',
        activityName: 'Focus Recovery (guided)',
        description: 'Take a moment to remember your previous task',
        suggestions: ['Review last activity', 'Check notes', 'Set intention'],
        estimatedDuration: Duration(minutes: 2),
      ),
    ],
  );

  static List<GuidedFlow> get all => [
    subuhFlow,
    dzuhurFlow,
    asharFlow,
    magribFlow,
    isyaFlow,
    sleepFlow,
  ];

  /// Get flow by ID
  static GuidedFlow? getById(String id) {
    if (id == 'distraction_recovery') return distractionRecoveryFlow;
    return all.firstWhere((f) => f.id == id, orElse: () => subuhFlow);
  }

  /// Get flow for a safety window
  static GuidedFlow? getForWindow(String windowId) {
    try {
      return all.firstWhere((f) => f.safetyWindowId == windowId);
    } catch (_) {
      return null;
    }
  }
}
