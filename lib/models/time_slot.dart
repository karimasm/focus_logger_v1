import 'sync_model.dart'; // Just for UuidHelper if needed, though not implementing SyncableModel yet

/// Represents an auto-generated 30-minute time slot
class TimeSlot {
  final String id;
  final DateTime slotStart;
  final DateTime slotEnd;
  final String? activityId; // Linked activity if any (UUID)
  final String label; // 'Unlabeled' if no activity
  final bool isEdited; // User edited this slot

  TimeSlot({
    String? id,
    required this.slotStart,
    required this.slotEnd,
    this.activityId,
    this.label = 'Unlabeled',
    this.isEdited = false,
  }) : id = id ?? UuidHelper.generate();

  bool get hasActivity => activityId != null;

  String get timeRange {
    String format(DateTime dt) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${format(slotStart)} - ${format(slotEnd)}';
  }

  TimeSlot copyWith({
    String? id,
    DateTime? slotStart,
    DateTime? slotEnd,
    String? activityId,
    String? label,
    bool? isEdited,
  }) {
    return TimeSlot(
      id: id ?? this.id,
      slotStart: slotStart ?? this.slotStart,
      slotEnd: slotEnd ?? this.slotEnd,
      activityId: activityId ?? this.activityId,
      label: label ?? this.label,
      isEdited: isEdited ?? this.isEdited,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'slotStart': slotStart.toIso8601String(),
      'slotEnd': slotEnd.toIso8601String(),
      'activityId': activityId,
      'label': label,
      'isEdited': isEdited ? 1 : 0,
    };
  }

  factory TimeSlot.fromMap(Map<String, dynamic> map) {
    return TimeSlot(
      id: map['id'] as String,
      slotStart: DateTime.parse(map['slotStart'] as String),
      slotEnd: DateTime.parse(map['slotEnd'] as String),
      activityId: map['activityId'] as String?,
      label: map['label'] as String? ?? 'Unlabeled',
      isEdited: (map['isEdited'] as int?) == 1,
    );
  }

  @override
  String toString() {
    return 'TimeSlot(id: $id, slotStart: $slotStart, slotEnd: $slotEnd, label: $label)';
  }
}
