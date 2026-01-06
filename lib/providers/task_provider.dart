import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/models.dart';

/// Provider for managing no-brainer tasks
class TaskProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<NobrainerTask> _tasks = [];
  
  List<NobrainerTask> get tasks => _tasks;
  List<NobrainerTask> get pendingTasks => _tasks.where((t) => !t.isCompleted).toList();
  List<NobrainerTask> get completedTasks => _tasks.where((t) => t.isCompleted).toList();

  TaskProvider() {
    loadTasks();
  }

  Future<void> loadTasks() async {
    _tasks = await _db.getAllNobrainerTasks();
    notifyListeners();
  }

  Future<void> addTask(String title) async {
    final task = NobrainerTask(
      title: title,
      sortOrder: _tasks.length,
    );
    await _db.insertNobrainerTask(task);
    await loadTasks();
  }

  Future<void> toggleTaskCompletion(int taskId) async {
    final task = _tasks.firstWhere((t) => t.id == taskId);
    final updated = task.copyWith(
      isCompleted: !task.isCompleted,
      completedAt: !task.isCompleted ? DateTime.now() : null,
    );
    await _db.updateNobrainerTask(updated);
    await loadTasks();
  }

  Future<void> deleteTask(int taskId) async {
    await _db.deleteNobrainerTask(taskId);
    await loadTasks();
  }

  Future<void> clearCompletedTasks() async {
    for (final task in completedTasks) {
      await _db.deleteNobrainerTask(task.id!);
    }
    await loadTasks();
  }

  Future<void> reorderTask(int oldIndex, int newIndex) async {
    final pending = pendingTasks;
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final task = pending.removeAt(oldIndex);
    pending.insert(newIndex, task);
    
    for (int i = 0; i < pending.length; i++) {
      final updated = pending[i].copyWith(sortOrder: i);
      await _db.updateNobrainerTask(updated);
    }
    await loadTasks();
  }
}
