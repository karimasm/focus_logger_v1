import 'package:flutter/material.dart';
import '../models/models.dart';
import '../data/data.dart';
import '../services/user_service.dart';

/// Lightweight energy check dialog shown after completing a task
/// Non-blocking - can be skipped
class EnergyCheckDialog extends StatelessWidget {
  final String? activityId;
  final String? taskId;
  final String taskName;
  final VoidCallback? onCompleted;

  const EnergyCheckDialog({
    super.key,
    this.activityId,
    this.taskId,
    required this.taskName,
    this.onCompleted,
  });

  static Future<void> show(
    BuildContext context, {
    String? activityId,
    String? taskId,
    required String taskName,
    VoidCallback? onCompleted,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => EnergyCheckDialog(
        activityId: activityId,
        taskId: taskId,
        taskName: taskName,
        onCompleted: onCompleted,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Text(
              'How do you feel?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              taskName,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            
            // Energy level buttons (5 levels - responsive layout)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: EnergyLevel.values.map((level) {
                return _EnergyButton(
                  level: level,
                  onTap: () => _recordEnergy(context, level),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 16),
            
            // Skip button
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onCompleted?.call();
              },
              child: Text(
                'Skip',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _recordEnergy(BuildContext context, EnergyLevel level) async {
    final energyCheck = EnergyCheck(
      activityId: activityId,
      taskId: taskId,
      level: level,
    );
    
    // Use dataRepository instead of DatabaseHelper for web compatibility
    await dataRepository.insertEnergyCheck(energyCheck);
    
    if (context.mounted) {
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${level.emoji} Energy logged: ${level.displayName}'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    
    onCompleted?.call();
  }
}

class _EnergyButton extends StatelessWidget {
  final EnergyLevel level;
  final VoidCallback onTap;

  const _EnergyButton({
    required this.level,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: _getBackgroundColor(),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getBorderColor(),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                level.emoji,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(height: 2),
              Text(
                '${level.value}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _getTextColor(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (level) {
      case EnergyLevel.veryLow:
        return Colors.red.shade100;
      case EnergyLevel.low:
        return Colors.orange.shade100;
      case EnergyLevel.medium:
        return Colors.amber.shade100;
      case EnergyLevel.high:
        return Colors.lightGreen.shade100;
      case EnergyLevel.veryHigh:
        return Colors.green.shade100;
    }
  }

  Color _getBorderColor() {
    switch (level) {
      case EnergyLevel.veryLow:
        return Colors.red.shade300;
      case EnergyLevel.low:
        return Colors.orange.shade300;
      case EnergyLevel.medium:
        return Colors.amber.shade300;
      case EnergyLevel.high:
        return Colors.lightGreen.shade300;
      case EnergyLevel.veryHigh:
        return Colors.green.shade300;
    }
  }

  Color _getTextColor() {
    switch (level) {
      case EnergyLevel.veryLow:
        return Colors.red.shade700;
      case EnergyLevel.low:
        return Colors.orange.shade700;
      case EnergyLevel.medium:
        return Colors.amber.shade700;
      case EnergyLevel.high:
        return Colors.lightGreen.shade700;
      case EnergyLevel.veryHigh:
        return Colors.green.shade700;
    }
  }
}
