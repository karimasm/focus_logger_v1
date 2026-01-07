import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/theme.dart';

/// Result of conflict resolution
enum ConflictChoice {
  todo,
  flow,
}

/// Full-screen conflict resolution when to-do alarm overlaps with flow window
/// 
/// Shows when a to-do alarm triggers during an active flow window
/// User must choose which one to do
class TodoFlowConflictScreen extends StatelessWidget {
  final AdHocTask todoTask;
  final UserFlowTemplate flowTemplate;
  final SafetyWindow safetyWindow;
  final Function(ConflictChoice) onChoice;

  // Colors for consistency
  static const Color _bgColor = AppColors.canvasPrimary;
  static const Color _textPrimary = AppColors.textOnCanvas;
  static const Color _textSecondary = AppColors.textOnCanvasSecondary;
  static const Color _accentColor = Color(0xFFE65100);

  const TodoFlowConflictScreen({
    super.key,
    required this.todoTask,
    required this.flowTemplate,
    required this.safetyWindow,
    required this.onChoice,
  });

  /// Show conflict dialog and return choice
  static Future<ConflictChoice?> show(
    BuildContext context, {
    required AdHocTask todoTask,
    required UserFlowTemplate flowTemplate,
    required SafetyWindow safetyWindow,
  }) {
    return Navigator.of(context).push<ConflictChoice>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => TodoFlowConflictScreen(
          todoTask: todoTask,
          flowTemplate: flowTemplate,
          safetyWindow: safetyWindow,
          onChoice: (choice) => Navigator.of(context).pop(choice),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Must make a choice
      child: Scaffold(
        backgroundColor: _bgColor,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _accentColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.compare_arrows_rounded,
                      size: 56,
                      color: _accentColor,
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Title - dark text on light background
                  Text(
                    'Ada 2 Event Bentrok!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _accentColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    'Yang mana yang akan kamu kerjakan?',
                    style: TextStyle(
                      fontSize: 14,
                      color: _textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Option 1: To-Do Task
                  _OptionCard(
                    icon: Icons.checklist_rounded,
                    iconColor: Colors.orange.shade700,
                    title: 'To-Do',
                    subtitle: todoTask.title,
                    badge: 'Alarm sekarang!',
                    onTap: () => onChoice(ConflictChoice.todo),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // VS indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'ATAU',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Option 2: Flow
                  _OptionCard(
                    icon: Icons.schedule_rounded,
                    iconColor: Colors.green.shade700,
                    title: 'Flow Rutin',
                    subtitle: flowTemplate.name,
                    badge: safetyWindow.formattedWindow,
                    onTap: () => onChoice(ConflictChoice.flow),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Info note
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _accentColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 20,
                          color: _accentColor,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'To-Do yang tidak dipilih akan diundur alarmnya',
                            style: TextStyle(
                              fontSize: 13,
                              color: _textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: AppColors.panelDecoration(borderRadius: 20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badge!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: iconColor,
                          ),
                        ),
                      ),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textOnPanelSecondary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textOnPanel,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: iconColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
