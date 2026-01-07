/// Represents a simple, low mental-load task
class NobrainerTask {
  final int? id;
  final String title;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime createdAt;
  final int sortOrder;

  NobrainerTask({
    this.id,
    required this.title,
    this.isCompleted = false,
    this.completedAt,
    DateTime? createdAt,
    this.sortOrder = 0,
  }) : createdAt = createdAt ?? DateTime.now().toUtc();

  NobrainerTask copyWith({
    int? id,
    String? title,
    bool? isCompleted,
    DateTime? completedAt,
    DateTime? createdAt,
    int? sortOrder,
  }) {
    return NobrainerTask(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted ? 1 : 0,
      'completedAt': completedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'sortOrder': sortOrder,
    };
  }

  factory NobrainerTask.fromMap(Map<String, dynamic> map) {
    return NobrainerTask(
      id: map['id'] as int?,
      title: map['title'] as String,
      isCompleted: (map['isCompleted'] as int?) == 1,
      completedAt: map['completedAt'] != null 
          ? DateTime.parse(map['completedAt'] as String) 
          : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
      sortOrder: map['sortOrder'] as int? ?? 0,
    );
  }

  @override
  String toString() {
    return 'NobrainerTask(id: $id, title: $title, isCompleted: $isCompleted)';
  }
}
