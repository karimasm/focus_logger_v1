import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:permission_handler/permission_handler.dart';

/// Platform-aware voice input service
/// Supports voice input on Android, iOS, and Web
/// Gracefully disables on Linux/Desktop to prevent crashes
class VoiceInputService {
  static final VoiceInputService instance = VoiceInputService._init();
  
  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String _currentLocale = 'id_ID'; // Default to Indonesian
  List<LocaleName> _availableLocales = [];
  
  VoiceInputService._init();

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String get currentLocale => _currentLocale;
  List<LocaleName> get availableLocales => _availableLocales;

  /// Check if voice input is supported on this platform
  static bool get isPlatformSupported {
    if (kIsWeb) {
      // Web may support speech recognition in some browsers
      return true;
    }
    
    try {
      // Android and iOS support speech
      if (Platform.isAndroid || Platform.isIOS) {
        return true;
      }
      // Linux, Windows, macOS - not supported (would crash)
      return false;
    } catch (e) {
      // If Platform throws, we're on web
      return true;
    }
  }

  /// Initialize the speech recognition service
  Future<bool> initialize() async {
    // Early exit for unsupported platforms
    if (!isPlatformSupported) {
      debugPrint('Voice input not supported on this platform');
      return false;
    }
    
    if (_isInitialized) return true;
    
    // Request microphone permission (only on mobile)
    if (!kIsWeb) {
      try {
        final status = await Permission.microphone.request();
        if (!status.isGranted) {
          debugPrint('Microphone permission denied');
          return false;
        }
      } catch (e) {
        debugPrint('Permission handler error: $e');
        return false;
      }
    }

    try {
      _isInitialized = await _speech.initialize(
        onStatus: (status) {
          debugPrint('Speech status: $status');
          _isListening = status == 'listening';
        },
        onError: (error) {
          debugPrint('Speech error: ${error.errorMsg}');
          _isListening = false;
        },
        debugLogging: kDebugMode,
      );

      if (_isInitialized) {
        _availableLocales = await _speech.locales();
        
        // Try to find Indonesian locale
        final indonesian = _availableLocales.where(
          (l) => l.localeId.startsWith('id') || l.localeId.contains('ID'),
        );
        if (indonesian.isNotEmpty) {
          _currentLocale = indonesian.first.localeId;
        }
        
        debugPrint('Speech initialized with ${_availableLocales.length} locales');
        debugPrint('Using locale: $_currentLocale');
      }
    } catch (e) {
      debugPrint('Speech initialization error: $e');
      _isInitialized = false;
    }

    return _isInitialized;
  }

  /// Set the recognition locale
  void setLocale(String localeId) {
    if (_availableLocales.any((l) => l.localeId == localeId)) {
      _currentLocale = localeId;
    }
  }

  /// Toggle between Indonesian and English
  void toggleLanguage() {
    if (_currentLocale.startsWith('id') || _currentLocale.contains('ID')) {
      // Switch to English
      final english = _availableLocales.where(
        (l) => l.localeId.startsWith('en'),
      );
      if (english.isNotEmpty) {
        _currentLocale = english.first.localeId;
      }
    } else {
      // Switch to Indonesian
      final indonesian = _availableLocales.where(
        (l) => l.localeId.startsWith('id') || l.localeId.contains('ID'),
      );
      if (indonesian.isNotEmpty) {
        _currentLocale = indonesian.first.localeId;
      }
    }
  }

  /// Start listening for voice input
  Future<void> startListening({
    required Function(String) onResult,
    Function(String)? onPartialResult,
    Function()? onComplete,
    Duration listenFor = const Duration(seconds: 30),
  }) async {
    if (!isPlatformSupported) {
      debugPrint('Voice input not supported on this platform');
      return;
    }
    
    if (!_isInitialized) {
      final success = await initialize();
      if (!success) {
        debugPrint('Failed to initialize speech recognition');
        return;
      }
    }

    if (_isListening) {
      await stopListening();
    }

    _isListening = true;

    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        if (result.finalResult) {
          onResult(result.recognizedWords);
          onComplete?.call();
        } else {
          onPartialResult?.call(result.recognizedWords);
        }
      },
      localeId: _currentLocale,
      listenFor: listenFor,
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      cancelOnError: true,
      listenMode: ListenMode.confirmation,
    );
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }
  }

  /// Cancel listening
  Future<void> cancelListening() async {
    if (_isListening) {
      await _speech.cancel();
      _isListening = false;
    }
  }

  /// Parse common activity phrases
  /// Recognizes patterns like "Mulai belajar" or "Start working"
  static String? parseActivityPhrase(String text) {
    final lowerText = text.toLowerCase().trim();
    
    // Indonesian patterns
    final indonesianPatterns = [
      RegExp(r'^mulai\s+(.+)$'),  // "Mulai belajar"
      RegExp(r'^kerjakan\s+(.+)$'),  // "Kerjakan tugas"
      RegExp(r'^lakukan\s+(.+)$'),  // "Lakukan olahraga"
    ];

    // English patterns
    final englishPatterns = [
      RegExp(r'^start\s+(.+)$'),  // "Start working"
      RegExp(r'^begin\s+(.+)$'),  // "Begin studying"
      RegExp(r'^do\s+(.+)$'),  // "Do exercise"
    ];

    for (final pattern in [...indonesianPatterns, ...englishPatterns]) {
      final match = pattern.firstMatch(lowerText);
      if (match != null) {
        return _capitalizeFirst(match.group(1)!);
      }
    }

    // If no pattern matched, return the text as-is (capitalized)
    return _capitalizeFirst(text.trim());
  }

  static String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Get the current language display name
  String get currentLanguageName {
    if (_currentLocale.startsWith('id') || _currentLocale.contains('ID')) {
      return 'Bahasa Indonesia';
    } else if (_currentLocale.startsWith('en')) {
      return 'English';
    }
    return _currentLocale;
  }

  /// Dispose resources
  void dispose() {
    _speech.stop();
    _speech.cancel();
  }
}
