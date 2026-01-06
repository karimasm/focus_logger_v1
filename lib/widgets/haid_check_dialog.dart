import 'package:flutter/material.dart';

/// Dialog shown during prayer flow window when Haid Mode is active.
/// Uses Indonesian language as per requirements.
/// 
/// Options:
/// - "Masih haid" → Skip prayer, status = skipped_due_to_haid
/// - "Sudah selesai" → Deactivate Haid Mode, continue normal flow
class HaidCheckDialog extends StatelessWidget {
  final VoidCallback onStillMenstruating;
  final VoidCallback onFinished;

  const HaidCheckDialog({
    super.key,
    required this.onStillMenstruating,
    required this.onFinished,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.favorite_rounded,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Haid Mode Aktif',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main question in Indonesian
          Text(
            'Apakah kamu masih haid?',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          // Explanation
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Jika masih haid, sholat akan dilewatkan hari ini.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // "Still menstruating" button
        OutlinedButton(
          onPressed: () {
            Navigator.pop(context);
            onStillMenstruating();
          },
          child: const Text('Masih haid'),
        ),
        // "Finished" button
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            onFinished();
          },
          child: const Text('Sudah selesai'),
        ),
      ],
    );
  }

  /// Show the dialog and return the result
  static Future<void> show({
    required BuildContext context,
    required VoidCallback onStillMenstruating,
    required VoidCallback onFinished,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => HaidCheckDialog(
        onStillMenstruating: onStillMenstruating,
        onFinished: onFinished,
      ),
    );
  }
}
