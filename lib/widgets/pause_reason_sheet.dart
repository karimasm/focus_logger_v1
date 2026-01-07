import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../services/mascot_service.dart';
import 'safe_bottom_sheet.dart';

class PauseReasonSheet extends StatefulWidget {
  const PauseReasonSheet({super.key});

  @override
  State<PauseReasonSheet> createState() => _PauseReasonSheetState();
}

class _PauseReasonSheetState extends State<PauseReasonSheet> {
  PauseReason? _selectedReason;
  final _customReasonController = TextEditingController();

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }

  void _pause() {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a reason')),
      );
      return;
    }

    final customReason = _selectedReason == PauseReason.other
        ? _customReasonController.text.trim()
        : null;

    context.read<ActivityProvider>().pauseActivity(
          _selectedReason!,
          customReason: customReason,
        );
    Navigator.pop(context);
    
    // Show distraction duck modal if distraction selected
    if (_selectedReason == PauseReason.distraction) {
      _showDistractionDuckModal();
    }
  }
  
  void _showDistractionDuckModal() {
    showDialog(
      context: context,
      builder: (context) => const DistractionDuckDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return SafeBottomSheet(
      title: 'Pause Activity',
      actions: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton.icon(
            onPressed: _pause,
            icon: const Icon(Icons.pause_rounded),
            label: const Text('Pause'),
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Why are you pausing?',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          // Reason options
          ...PauseReason.values.map((reason) => _ReasonOption(
                reason: reason,
                isSelected: _selectedReason == reason,
                onTap: () {
                  setState(() {
                    _selectedReason = reason;
                  });
                },
              )),

          // Custom reason input
          if (_selectedReason == PauseReason.other) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _customReasonController,
              autofocus: true,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'What happened?',
                hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Dialog showing angry_duck_knife when distraction is selected
class DistractionDuckDialog extends StatelessWidget {
  const DistractionDuckDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mascotPath = MascotService.getDistractionMascot();
    
    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Angry duck with knife
            Image.asset(
              mascotPath,
              width: 150,
              height: 150,
              fit: BoxFit.contain,
            ),
            
            const SizedBox(height: 16),
            
            Text(
              'Hey! Focus! 🔪',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'Distraksi memang terjadi. Take a breath, lalu coba kembali fokus ya.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _ReasonOption extends StatelessWidget {
  final PauseReason reason;
  final bool isSelected;
  final VoidCallback onTap;

  const _ReasonOption({
    required this.reason,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  _getIcon(),
                  color: isSelected
                      ? colorScheme.onPrimaryContainer
                      : _getColor(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    reason.displayName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w600 : null,
                      // FIX: Use proper text color for dark backgrounds
                      color: isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: colorScheme.primary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (reason) {
      case PauseReason.distraction:
        return Icons.notifications_active_outlined;
      case PauseReason.breakRest:
        return Icons.coffee_outlined;
      case PauseReason.taskSwitching:
        return Icons.swap_horiz_rounded;
      case PauseReason.adHocTask:
        return Icons.task_alt_rounded;
      case PauseReason.other:
        return Icons.more_horiz_rounded;
    }
  }

  Color _getColor() {
    switch (reason) {
      case PauseReason.distraction:
        return Colors.red;
      case PauseReason.breakRest:
        return Colors.blue;
      case PauseReason.taskSwitching:
        return Colors.orange;
      case PauseReason.adHocTask:
        return Colors.purple;
      case PauseReason.other:
        return Colors.grey;
    }
  }
}
