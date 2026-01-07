import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import '../models/models.dart';
import '../services/mascot_service.dart';
import '../theme/theme.dart';

/// Full-screen blocking reminder for adhoc task alarm
/// 
/// Shows when adhoc alarm time is reached
/// User must acknowledge to continue
class AdhocReminderScreen extends StatefulWidget {
  final AdHocTask task;
  final VoidCallback onAcknowledge;
  final VoidCallback onStop;

  const AdhocReminderScreen({
    super.key,
    required this.task,
    required this.onAcknowledge,
    required this.onStop,
  });

  @override
  State<AdhocReminderScreen> createState() => _AdhocReminderScreenState();
}

class _AdhocReminderScreenState extends State<AdhocReminderScreen> 
    with SingleTickerProviderStateMixin {
  final _audioPlayer = AudioPlayer();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Colors for consistency
  static const Color _bgColor = AppColors.canvasPrimary;
  static const Color _textPrimary = AppColors.textOnCanvas;
  static const Color _textSecondary = AppColors.textOnCanvasSecondary;
  static const Color _accentColor = Color(0xFFE65100);

  @override
  void initState() {
    super.initState();
    _alertUser();
    _setupAnimation();
  }

  void _setupAnimation() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _alertUser() async {
    // Play notification sound
    try {
      await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
    } catch (e) {
      debugPrint('[ADHOC_REMINDER] Sound failed: $e');
    }
    
    // Vibration: pattern
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(pattern: [0, 200, 100, 200, 100, 400]);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = widget.task.executionDuration ?? Duration.zero;
    final mascotPath = MascotService.getIdleMascot();
    
    return PopScope(
      canPop: false, // Block back button
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
                      width: 160,
                      height: 160,
                      fit: BoxFit.contain,
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Alert icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _accentColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.alarm_on_rounded,
                      size: 48,
                      color: _accentColor,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Title - dark text on light background
                  Text(
                    'Waktunya mengerjakan:',
                    style: TextStyle(
                      fontSize: 16,
                      color: _textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 8),
                  
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
                  
                  const SizedBox(height: 16),
                  
                  // Elapsed time
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: _accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _accentColor.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Sudah berjalan',
                          style: TextStyle(
                            fontSize: 12,
                            color: _textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDuration(elapsed),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Buttons
                  Column(
                    children: [
                      // Continue / Acknowledge button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton.icon(
                          onPressed: () {
                            widget.onAcknowledge();
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text(
                            'Lanjutkan',
                            style: TextStyle(fontSize: 16),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: _accentColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Stop button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            widget.onStop();
                            Navigator.of(context).pop();
                          },
                          icon: Icon(Icons.stop_rounded, color: Colors.red.shade700),
                          label: Text(
                            'Selesai',
                            style: TextStyle(fontSize: 16, color: Colors.red.shade700),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.red.shade700),
                          ),
                        ),
                      ),
                    ],
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
