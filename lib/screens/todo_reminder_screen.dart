import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import '../models/models.dart';
import '../services/mascot_service.dart';
import '../theme/theme.dart';

/// Full-screen ENFORCED reminder for to-do task alarm
/// 
/// Shows when to-do alarm time is reached
/// User MUST start the task - no dismiss/skip option
class TodoReminderScreen extends StatefulWidget {
  final AdHocTask task;
  final VoidCallback onStartTask;

  const TodoReminderScreen({
    super.key,
    required this.task,
    required this.onStartTask,
  });

  @override
  State<TodoReminderScreen> createState() => _TodoReminderScreenState();
}

class _TodoReminderScreenState extends State<TodoReminderScreen> 
    with SingleTickerProviderStateMixin {
  final _audioPlayer = AudioPlayer();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Define colors - orange background = dark text
  static const Color _bgColor = AppColors.canvasPrimary;
  static const Color _textPrimary = AppColors.textOnCanvas;
  static const Color _textSecondary = AppColors.textOnCanvasSecondary;
  static const Color _accentColor = Color(0xFFE65100); // Deep orange for contrast

  @override
  void initState() {
    super.initState();
    _alertUser();
    _setupAnimation();
  }

  void _setupAnimation() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _alertUser() async {
    // Play notification sound - loop it
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
    } catch (e) {
      debugPrint('[TODO_REMINDER] Sound failed: $e');
    }
    
    // Vibration: continuous pattern
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(pattern: [0, 500, 200, 500, 200, 500], repeat: 0);
    }
  }

  void _stopAlerts() {
    _audioPlayer.stop();
    Vibration.cancel();
  }

  @override
  void dispose() {
    _stopAlerts();
    _pulseController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mascotPath = MascotService.getIdleMascot();
    
    return PopScope(
      canPop: false, // BLOCK back button - ENFORCED
      child: Scaffold(
        backgroundColor: _bgColor,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Mascot with pulse animation
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Image.asset(
                      mascotPath,
                      width: 140,
                      height: 140,
                      fit: BoxFit.contain,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Alarm icon with animation
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _accentColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.alarm_on_rounded,
                        size: 56,
                        color: _accentColor,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Title - dark text on light background
                  Text(
                    'WAKTUNYA!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: _accentColor,
                      letterSpacing: 2,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Task name - dark panel with light text
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: AppColors.panelDecoration(borderRadius: 16),
                    child: Text(
                      widget.task.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textOnPanel,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  if (widget.task.description != null && widget.task.description!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      widget.task.description!,
                      style: TextStyle(
                        fontSize: 14,
                        color: _textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  
                  const SizedBox(height: 48),
                  
                  // Start button - ONLY option
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: FilledButton.icon(
                      onPressed: () {
                        _stopAlerts();
                        widget.onStartTask();
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 28),
                      label: const Text(
                        'MULAI SEKARANG',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _accentColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Note - dark text on orange-tinted container
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
                          color: _accentColor,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Task ini tidak bisa dilewati. Kamu sudah berkomitmen!',
                            style: TextStyle(
                              fontSize: 13,
                              color: _textPrimary,
                              fontWeight: FontWeight.w500,
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
