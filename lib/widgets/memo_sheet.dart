import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../services/services.dart';

class MemoSheet extends StatefulWidget {
  final Activity activity;

  const MemoSheet({super.key, required this.activity});

  @override
  State<MemoSheet> createState() => _MemoSheetState();
}

class _MemoSheetState extends State<MemoSheet> {
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
        // For memos, we append text if not empty, or replace if empty?
        // Usually safer to just append or replace. Valid question for user but I'll assume replace/append logic.
        // Actually, parseActivityPhrase is for starting activities. For memos, we just want raw text.
        // And maybe capitalized.
        
        final currentText = _controller.text;
        final newText = currentText.isEmpty 
            ? _capitalizeFirst(result)
            : '$currentText ${_capitalizeFirst(result)}';

        setState(() {
          _controller.text = newText;
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
      // Short listen duration for quick notes
      listenFor: const Duration(seconds: 30),
    );
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  void _stopListening() async {
    await _voiceService.stopListening();
    setState(() {
      _isListening = false;
    });
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      context.read<MemoProvider>().addMemo(
        activityId: widget.activity.id,
        text: text,
      );
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Memo added'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.note_add_rounded, size: 24),
              const SizedBox(width: 12),
              Text(
                'Add Memo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Add a note to "${widget.activity.name}" without stopping it.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          
          // Text input with voice button
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'What do you want to note?',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              // Voice input button - only show on supported platforms
              if (VoiceInputService.isPlatformSupported) ...[
                const SizedBox(width: 12),
                Material(
                  color: _isListening
                      ? Colors.red
                      : Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: _isListening ? _stopListening : _startListening,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                            size: 28,
                            color: _isListening
                                ? Colors.white
                                : Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isListening ? 'Stop' : 'Voice',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _isListening
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          
          // Voice listening indicator
          if (_isListening || _partialResult.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
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
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
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
          
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submit,
              label: const Text('Add Note'),
              icon: const Icon(Icons.check_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

