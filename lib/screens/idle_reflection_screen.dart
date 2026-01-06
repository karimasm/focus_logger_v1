import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import '../data/data.dart';
import '../models/models.dart';
import '../services/user_service.dart';
import '../services/mascot_service.dart';

/// Full-screen blocking reflection popup
/// 
/// Shows when user is idle ≥30 min without running activity
/// Uses shy_duck_idle mascot asset
class IdleReflectionScreen extends StatefulWidget {
  final Duration idleDuration;
  final VoidCallback onComplete;

  const IdleReflectionScreen({
    super.key,
    required this.idleDuration,
    required this.onComplete,
  });

  @override
  State<IdleReflectionScreen> createState() => _IdleReflectionScreenState();
}

class _IdleReflectionScreenState extends State<IdleReflectionScreen> 
    with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final _audioPlayer = AudioPlayer();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _alertUser();
    _setupAnimation();
    
    // Auto-focus text field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _setupAnimation() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _alertUser() async {
    // Vibration: short-short-long pattern
    final hasVibrator = await Vibration.hasVibrator() ?? false;
    if (hasVibrator) {
      Vibration.vibrate(pattern: [0, 100, 100, 100, 100, 300]);
    }
    
    // System beep
    try {
      await _audioPlayer.play(AssetSource('sounds/notification_beep.mp3'));
    } catch (e) {
      // Fallback: use system sound via audio player
      debugPrint('[IDLE] Beep failed: $e');
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _pulseController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _saveReflection() async {
    if (_isSaving) return;
    
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tulis sesuatu sebelum menyimpan'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final memo = MemoEntry(
        activityId: 'idle-reflection',
        timestamp: DateTime.now(),
        text: '[Idle ${_formatDuration(widget.idleDuration)}] $text',
        source: MemoSource.idleReflection,
        userId: UserService().currentUserId,
      );

      await dataRepository.insertMemoEntry(memo);
      
      debugPrint('[IDLE_REFLECTION] Saved: $text');
      
      widget.onComplete();
    } catch (e) {
      debugPrint('[IDLE_REFLECTION] Error saving: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _skip() {
    widget.onComplete();
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}j ${d.inMinutes % 60}m';
    }
    return '${d.inMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mascotPath = MascotService.getIdleMascot();
    
    return PopScope(
      canPop: false, // Block back button
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                
                // Shy duck mascot with animation
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Image.asset(
                    mascotPath!,
                    width: 180,
                    height: 180,
                    fit: BoxFit.contain,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Question
                Text(
                  'Kelihatannya kamu idle cukup lama.',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  'Tadi kamu ngapain?',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 8),
                
                // Idle duration info
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Idle ${_formatDuration(widget.idleDuration)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Text field
                TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  maxLines: 5,
                  minLines: 3,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saveReflection(),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Tulis aktivitas atau pikiranmu...',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _saveReflection,
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Simpan & Lanjutkan',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Skip button
                TextButton(
                  onPressed: _skip,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
