import 'package:uuid/uuid.dart';

/// Represents a 30-minute time block that wasn't logged
/// Used for awareness-first auto-logging behavior
class UnloggedBlock {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final DateTime createdAt;

  UnloggedBlock({
    String? id,
    required this.startTime,
    required this.endTime,
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now().toUtc();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory UnloggedBlock.fromMap(Map<String, dynamic> map) {
    return UnloggedBlock(
      id: map['id'] as String,
      startTime: DateTime.parse(map['start_time'] as String),
      endTime: DateTime.parse(map['end_time'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
  
  String get formattedTimeRange {
    final startStr = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    final endStr = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
    return '$startStr – $endStr';
  }
  
  UnloggedBlock copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    DateTime? createdAt,
  }) {
    return UnloggedBlock(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
