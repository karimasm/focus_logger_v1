import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../services/services.dart';
import 'safe_bottom_sheet.dart';

class StartActivitySheet extends StatefulWidget {
  const StartActivitySheet({super.key});

  @override
  State<StartActivitySheet> createState() => _StartActivitySheetState();
}

class _StartActivitySheetState extends State<StartActivitySheet> {
  final _controller = TextEditingController();
  final _voiceService = VoiceInputService.instance;
  bool _isListening = false;
  String _partialResult = '';

  @override
  void dispose() {
    _controller.dispose();
    _voiceService.stopListening();
    super.dispose();
  }

  void _startListening() async {
    final initialized = await _voiceService.initialize();
    if (!initialized) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice input not available')),
        );
      }
      return;
    }

    setState(() {
      _isListening = true;
      _partialResult = '';
    });

    await _voiceService.startListening(
      onResult: (result) {
        final parsed = VoiceInputService.parseActivityPhrase(result);
        setState(() {
          _controller.text = parsed ?? result;
          _isListening = false;
          _partialResult = '';
        });
      },
      onPartialResult: (partial) {
        setState(() {
          _partialResult = partial;
        });
      },
      onComplete: () {
        setState(() {
          _isListening = false;
        });
      },
    );
  }

  void _stopListening() async {
    await _voiceService.stopListening();
    setState(() {
      _isListening = false;
    });
  }

  void _startActivity() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an activity name')),
      );
      return;
    }

    context.read<ActivityProvider>().startActivity(name);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return SafeBottomSheet(
      title: 'Start Activity',
      actions: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton.icon(
            onPressed: _startActivity,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start Tracking'),
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'What are you working on?',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          // Activity name input
          TextField(
            controller: _controller,
            autofocus: true,
            style: TextStyle(color: colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'e.g., Working on project',
              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              // Voice input only on supported platforms (Android, iOS, Web)
              suffixIcon: VoiceInputService.isPlatformSupported 
                ? IconButton(
                    onPressed: _isListening ? _stopListening : _startListening,
                    icon: Icon(
                      _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                      color: _isListening
                          ? colorScheme.error
                          : colorScheme.primary,
                    ),
                  )
                : null,
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _startActivity(),
          ),

          // Voice listening indicator
          if (_isListening || _partialResult.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  if (_isListening)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isListening
                          ? (_partialResult.isEmpty
                              ? 'Listening... (${_voiceService.currentLanguageName})'
                              : _partialResult)
                          : _partialResult,
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  if (_isListening)
                    TextButton(
                      onPressed: () {
                        _voiceService.toggleLanguage();
                        setState(() {});
                      },
                      child: Text(
                        _voiceService.currentLocale.startsWith('id')
                            ? 'EN'
                            : 'ID',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Quick suggestions
          Text(
            'Quick Start',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickSuggestion(
                label: 'Deep Work',
                onTap: () => _controller.text = 'Deep Work',
              ),
              _QuickSuggestion(
                label: 'Meeting',
                onTap: () => _controller.text = 'Meeting',
              ),
              _QuickSuggestion(
                label: 'Reading',
                onTap: () => _controller.text = 'Reading',
              ),
              _QuickSuggestion(
                label: 'Learning',
                onTap: () => _controller.text = 'Learning',
              ),
              _QuickSuggestion(
                label: 'Admin Tasks',
                onTap: () => _controller.text = 'Admin Tasks',
              ),
              _QuickSuggestion(
                label: 'Commute',
                onTap: () => _controller.text = 'Commute',
              ),
              _QuickSuggestion(
                label: 'Cleaning',
                onTap: () => _controller.text = 'Cleaning',
              ),
              _QuickSuggestion(
                label: 'Leisure',
                onTap: () => _controller.text = 'Leisure',
              ),
            ],
          ),
        ],
      ),
    );
  }
}


class _QuickSuggestion extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickSuggestion({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
    );
  }
}
