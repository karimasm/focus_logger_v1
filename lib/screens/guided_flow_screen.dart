import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../models/models.dart';

/// Fullscreen guided flow screen - no escape, no skip
class GuidedFlowScreen extends StatelessWidget {
  const GuidedFlowScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GuidedFlowProvider>(
      builder: (context, provider, child) {
        // If no flow is active, show nothing (shouldn't happen)
        if (!provider.isFlowActive) {
          return const SizedBox.shrink();
        }

        return PopScope(
          // Prevent back navigation during guided flow
          canPop: false,
          child: Scaffold(
            backgroundColor: const Color(0xFF1A1A2E),
            body: SafeArea(
              child: _buildFlowContent(context, provider),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFlowContent(BuildContext context, GuidedFlowProvider provider) {
    switch (provider.state) {
      case GuidedFlowState.waiting:
        return _WaitingState(provider: provider);
      case GuidedFlowState.inProgress:
        return _InProgressState(provider: provider);
      case GuidedFlowState.completing:
      case GuidedFlowState.idle:
        return const SizedBox.shrink();
    }
  }
}

/// Shows the IF-THEN prompt with "ON IT" button
class _WaitingState extends StatelessWidget {
  final GuidedFlowProvider provider;

  const _WaitingState({required this.provider});

  @override
  Widget build(BuildContext context) {
    final step = provider.currentStep;
    final isFirstStep = provider.currentStepIndex == 0;
    final template = provider.activeTemplate!;

    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Flow type icon
          Icon(
            _getCategoryIcon(template.category),
            size: 48,
            color: _getCategoryColor(template.category),
          ),
          const SizedBox(height: 16),
          
          // Flow name
          Text(
            template.name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.6),
              letterSpacing: 2,
            ),
          ),
          
          // Safety window time remaining
          if (provider.windowTimeRemaining != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${provider.windowTimeRemaining!.inMinutes} min remaining',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          
          // Distraction recovery context
          if (provider.showingDistractionRecovery && 
              provider.previousActivityBeforeDistraction != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    'Previous Task:',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    provider.previousActivityBeforeDistraction!.name,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 24),

          // Step indicator
          if (template.steps.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  template.steps.length,
                  (index) => Container(
                    width: index == provider.currentStepIndex ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: index <= provider.currentStepIndex
                          ? const Color(0xFF4CAF50)
                          : Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),

          // Main prompt
          if (isFirstStep) ...[
            // Initial prompt for first step
            Text(
              template.initialPrompt,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            // IF-THEN prompt for subsequent steps
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    'IF',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[400],
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    step!.ifCondition,
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'THEN',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[400],
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    step.thenAction,
                    style: const TextStyle(
                      fontSize: 28,
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],

          // Description if available
          if (step?.description != null && step!.description!.isNotEmpty) ...[
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                step.description!,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],

          const SizedBox(height: 48),

          // ON IT button - the only action available
          SizedBox(
            width: double.infinity,
            height: 72,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.heavyImpact();
                provider.startCurrentStep();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 8,
              ),
              child: const Text(
                'ON IT',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),
          Text(
            'Tap when you start',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'prayer':
        return Icons.self_improvement_rounded;
      case 'routine':
        return Icons.schedule_rounded;
      case 'recovery':
        return Icons.psychology_rounded;
      case 'sleep':
        return Icons.bedtime_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'prayer':
        return const Color(0xFF4CAF50);
      case 'routine':
        return const Color(0xFF2196F3);
      case 'recovery':
        return const Color(0xFFFF9800);
      case 'sleep':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF2196F3);
    }
  }
}

/// Shows the activity in progress with "DONE" button
class _InProgressState extends StatelessWidget {
  final GuidedFlowProvider provider;

  const _InProgressState({required this.provider});

  @override
  Widget build(BuildContext context) {
    final step = provider.currentStep;

    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Activity name
          Text(
            step?.activityName ?? 'Activity',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Description if available
          if (step?.description != null)
            Text(
              step!.description!,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),

          const SizedBox(height: 48),

          // Timer display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Text(
                  'IN PROGRESS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.6),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  provider.formattedStepElapsed,
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w300,
                    color: Color(0xFF4CAF50),
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 48),

          // Question
          Text(
            'Are you done?',
            style: TextStyle(
              fontSize: 20,
              color: Colors.white.withOpacity(0.8),
            ),
          ),

          const SizedBox(height: 24),

          // DONE button
          SizedBox(
            width: double.infinity,
            height: 72,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.heavyImpact();
                provider.completeCurrentStep();
                
                // Check if flow is complete
                if (provider.currentStepIndex >= provider.activeTemplate!.steps.length) {
                  // Flow complete, navigate back
                  Navigator.of(context).pop();
                  _showCompletionMessage(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 8,
              ),
              child: const Text(
                'DONE',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Remaining steps indicator
          if (provider.activeTemplate!.steps.length > provider.currentStepIndex + 1)
            Text(
              '${provider.activeTemplate!.steps.length - provider.currentStepIndex - 1} more step(s) after this',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
        ],
      ),
    );
  }

  void _showCompletionMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('Routine completed! Great job! 🎉'),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

/// Overlay widget that checks for active guided flows and shows the screen
class GuidedFlowOverlay extends StatelessWidget {
  final Widget child;

  const GuidedFlowOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<GuidedFlowProvider>(
      builder: (context, provider, _) {
        if (provider.isFlowActive) {
          return const GuidedFlowScreen();
        }
        return child;
      },
    );
  }
}
