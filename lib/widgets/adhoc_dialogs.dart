import 'package:flutter/material.dart';

/// Dialog shown when an ad-hoc task is completed
/// Asks user whether to continue with the previously paused activity
class AdHocCompletionDialog extends StatelessWidget {
  final String taskName;
  final String? previousActivityName;
  final VoidCallback onContinuePrevious;
  final VoidCallback onStayPaused;
  final VoidCallback onDismiss;

  const AdHocCompletionDialog({
    super.key,
    required this.taskName,
    this.previousActivityName,
    required this.onContinuePrevious,
    required this.onStayPaused,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('Task Completed')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"$taskName" has been completed.',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          if (previousActivityName != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Continue "$previousActivityName"?',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (previousActivityName != null) ...[
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onStayPaused();
            },
            child: const Text('Stay Paused'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onContinuePrevious();
            },
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('ON IT'),
          ),
        ] else ...[
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              onDismiss();
            },
            child: const Text('OK'),
          ),
        ],
      ],
    );
  }

  /// Show the dialog
  static Future<void> show({
    required BuildContext context,
    required String taskName,
    String? previousActivityName,
    required VoidCallback onContinuePrevious,
    required VoidCallback onStayPaused,
    required VoidCallback onDismiss,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AdHocCompletionDialog(
        taskName: taskName,
        previousActivityName: previousActivityName,
        onContinuePrevious: onContinuePrevious,
        onStayPaused: onStayPaused,
        onDismiss: onDismiss,
      ),
    );
  }
}

/// Dialog for selecting pause reason when staying paused
class PauseReasonDialog extends StatefulWidget {
  final Function(String reason, String? customReason) onSubmit;

  const PauseReasonDialog({
    super.key,
    required this.onSubmit,
  });

  @override
  State<PauseReasonDialog> createState() => _PauseReasonDialogState();
}

class _PauseReasonDialogState extends State<PauseReasonDialog> {
  String _selectedReason = 'Break';
  final _customController = TextEditingController();

  final _reasons = [
    'Break',
    'Meeting',
    'Lunch',
    'Prayer',
    'Phone call',
    'Other',
  ];

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pause Reason'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Why are you pausing?'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _reasons.map((reason) {
              final isSelected = _selectedReason == reason;
              return ChoiceChip(
                label: Text(reason),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedReason = reason;
                  });
                },
              );
            }).toList(),
          ),
          if (_selectedReason == 'Other') ...[
            const SizedBox(height: 16),
            TextField(
              controller: _customController,
              decoration: const InputDecoration(
                hintText: 'Enter reason...',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            widget.onSubmit(
              _selectedReason,
              _selectedReason == 'Other' ? _customController.text : null,
            );
          },
          child: const Text('Pause'),
        ),
      ],
    );
  }

  static Future<void> show({
    required BuildContext context,
    required Function(String reason, String? customReason) onSubmit,
  }) {
    return showDialog(
      context: context,
      builder: (context) => PauseReasonDialog(onSubmit: onSubmit),
    );
  }
}
