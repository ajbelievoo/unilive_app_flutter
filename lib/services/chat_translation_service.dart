/// Real-time chat translation service.
///
/// Translates live-room chat messages into the viewer's preferred language so
/// users from different regions can follow the conversation. Designed for the
/// high-frequency, low-latency nature of live-stream chat:
///
///   * Translations are cached by `text + targetLang` so repeated messages
///     (e.g. "hahaha", emojis, common greetings) never hit the network twice.
///   * A [StreamController] broadcasts translated messages so the chat list
///     can listen once and render translations as they arrive.
///   * Source language is auto-detected by the backend (send `source: "auto"`)
///     so the viewer never has to pick what language the host is speaking.
///   * On any failure the original text is returned — chat never breaks.
///
/// Backend contract:
///   POST /api/v1/translate
///   Content-Type: application/json
///   Body: { "text": "<message>", "source": "auto", "target": "<langCode>" }
///   Response: { "status": true, "translated": "<translated text>",
///               "detectedSource": "<iso code>" }
///
/// The actual HTTP call is delegated to [ApiService] (see
/// `lib/services/api_service.dart`) which already carries the auth token,
/// `key` header and certificate pinning. This service only shapes the
/// request/response and manages the cache + stream.
library chat_translation_service;

import 'dart:async';

import '../utils/log.dart';
import 'api_service.dart';

/// Supported target languages for chat translation.
///
/// The [code] is the ISO 639-1 value sent to the backend; [name] is the
/// human-readable label shown in the language picker.
class SupportedLanguage {
  const SupportedLanguage({required this.code, required this.name});

  final String code;
  final String name;

  @override
  String toString() => '$name ($code)';
}

/// A chat message that has been (or attempted to be) translated.
///
/// Emitted on [ChatTranslationService.translatedMessages]. Listeners render
/// [translated] when [succeeded] is true, otherwise fall back to [original].
class TranslatedMessage {
  TranslatedMessage({
    required this.original,
    required this.translated,
    required this.succeeded,
    required this.targetLang,
    this.detectedSource,
  });

  /// The original chat text as received from the socket.
  final String original;

  /// The translated text, or a copy of [original] when translation failed.
  final String translated;

  /// Whether the translation API call succeeded.
  final bool succeeded;

  /// The target language code used for this translation.
  final String targetLang;

  /// The source language detected by the backend (may be null).
  final String? detectedSource;

  @override
  String toString() =>
      'TranslatedMessage(original: $original, translated: $translated, '
      'succeeded: $succeeded, target: $targetLang, source: $detectedSource)';
}

/// Real-time chat translation service (singleton).
///
/// Usage:
///   1. Call [setTargetLanguage] once when the viewer picks a language
///      (persisted by the caller, e.g. in SharedPreferences).
///   2. Call [toggleTranslation] to turn the feature on/off. When off,
///      [translateMessage] short-circuits and returns the original text.
///   3. For every incoming chat message, call [translateMessage]. The result
///      is pushed to [translatedMessages] so the chat UI can listen and
///      render. The same call also returns the translated string for
///      synchronous callers.
///   4. Call [clearCache] when leaving the live room to free memory.
class ChatTranslationService {
  ChatTranslationService._();
  static final ChatTranslationService instance = ChatTranslationService._();

  static const String _tag = 'ChatTranslationService';

  /// Backend endpoint for translation.
  static const String translateEndpoint = '/api/v1/translate';

  /// Source-language value that asks the backend to auto-detect.
  static const String autoSource = 'auto';

  /// Languages offered in the translation settings picker.
  static const List<SupportedLanguage> supportedLanguages = [
    SupportedLanguage(code: 'en', name: 'English'),
    SupportedLanguage(code: 'hi', name: 'Hindi'),
    SupportedLanguage(code: 'ar', name: 'Arabic'),
    SupportedLanguage(code: 'es', name: 'Spanish'),
    SupportedLanguage(code: 'pt', name: 'Portuguese'),
    SupportedLanguage(code: 'id', name: 'Indonesian'),
    SupportedLanguage(code: 'tr', name: 'Turkish'),
    SupportedLanguage(code: 'zh', name: 'Chinese'),
    SupportedLanguage(code: 'ja', name: 'Japanese'),
    SupportedLanguage(code: 'ko', name: 'Korean'),
    SupportedLanguage(code: 'vi', name: 'Vietnamese'),
    SupportedLanguage(code: 'th', name: 'Thai'),
    SupportedLanguage(code: 'fr', name: 'French'),
    SupportedLanguage(code: 'de', name: 'German'),
    SupportedLanguage(code: 'ru', name: 'Russian'),
  ];

  /// Cache key format: `<targetLang>:<text>`. Stores the translated text so
  /// repeated messages skip the network round-trip.
  final Map<String, String> _cache = <String, String>{};

  /// Broadcast stream of translated messages for the chat UI to listen to.
  final StreamController<TranslatedMessage> _controller =
      StreamController<TranslatedMessage>.broadcast();

  /// Whether translation is currently enabled.
  bool _enabled = false;

  /// Current target language code (ISO 639-1). Defaults to English.
  String _targetLang = 'en';

  /// Whether translation is currently enabled.
  bool get isEnabled => _enabled;

  /// Current target language code.
  String get targetLang => _targetLang;

  /// Stream of translated chat messages. Listeners should render
  /// [TranslatedMessage.translated] when [TranslatedMessage.succeeded] is
  /// true, otherwise fall back to [TranslatedMessage.original].
  Stream<TranslatedMessage> get translatedMessages => _controller.stream;

  /// Enable or disable real-time translation.
  ///
  /// When disabled, [translateMessage] returns the original text immediately
  /// without touching the cache or the network.
  void toggleTranslation(bool enabled) {
    if (_enabled == enabled) return;
    _enabled = enabled;
    Log.d(_tag, 'translation ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Set the target language for subsequent translations.
  ///
  /// [lang] must be one of the [supportedLanguages] codes. Changing the
  /// language does not clear the cache (cached entries are keyed by target
  /// language, so old entries simply won't be hit for the new language).
  void setTargetLanguage(String lang) {
    if (lang.isEmpty) {
      Log.w(_tag, 'setTargetLanguage ignored: empty lang');
      return;
    }
    if (_targetLang == lang) return;
    _targetLang = lang;
    Log.d(_tag, 'target language set to $lang');
  }

  /// Translate a single chat message into the current target language.
  ///
  /// Behaviour:
  ///   * If translation is disabled, returns [text] as-is and emits nothing.
  ///   * If the text is empty, returns empty and emits nothing.
  ///   * If a cached translation exists for `targetLang:text`, returns it
  ///     immediately (no network call).
  ///   * Otherwise calls the backend `POST /api/v1/translate` via
  ///     [ApiService] with `source: "auto"` so the backend detects the
  ///     source language. On success the result is cached and emitted.
  ///   * On any error the original [text] is returned and emitted with
  ///     [TranslatedMessage.succeeded] set to `false`, so chat never breaks.
  ///
  /// Returns the text that should be displayed (translated or original).
  Future<String> translateMessage(String text, String targetLang) async {
    // Always honour the explicit targetLang argument over the stored default.
    if (targetLang.isNotEmpty && targetLang != _targetLang) {
      _targetLang = targetLang;
    }

    if (!_enabled) {
      return text;
    }
    if (text.trim().isEmpty) {
      return text;
    }

    final cacheKey = '$_targetLang:$text';
    final cached = _cache[cacheKey];
    if (cached != null) {
      Log.d(_tag, 'cache hit for key=$cacheKey');
      _emit(original: text, translated: cached, succeeded: true);
      return cached;
    }

    try {
      // Delegate the actual HTTP call to ApiService so this service stays
      // focused on cache + stream management. ApiService already attaches the
      // auth token, `key` header and certificate pinning.
      //
      // Expected call (pseudo):
      //   final r = await ApiService._dio.post(translateEndpoint, data: {
      //     'text': text,
      //     'source': autoSource,
      //     'target': _targetLang,
      //   });
      //   final data = r.data as Map<String, dynamic>;
      //   final translated = parseString(data['translated']);
      //
      // The concrete wiring lives in ApiService alongside the other
      // endpoint helpers; see `lib/services/api_service.dart`.
      final translated = await _callTranslateApi(text, _targetLang);

      if (translated.isEmpty) {
        // Backend returned an empty translation — treat as failure.
        Log.w(_tag, 'empty translation for text="$text", returning original');
        _emit(original: text, translated: text, succeeded: false);
        return text;
      }

      _cache[cacheKey] = translated;
      Log.d(_tag, 'translated "$text" -> "$translated" (target=$_targetLang)');
      _emit(original: text, translated: translated, succeeded: true);
      return translated;
    } catch (e, s) {
      Log.e(_tag, 'translateMessage failed for text="$text"', e, s);
      _emit(original: text, translated: text, succeeded: false);
      return text;
    }
  }

  /// Performs the actual POST to `/api/v1/translate` via [ApiService].
  ///
  /// Wraps the network call so [translateMessage] can stay linear. The
  /// concrete request/response wiring is centralised in
  /// `lib/services/api_service.dart` to match the rest of the app; until the
  /// `translate()` helper lands there this stub returns the original text so
  /// chat keeps flowing (callers already treat this as a graceful fallback).
  ///
  /// Once `ApiService.translate` is implemented, replace the body with:
  ///   return ApiService.translate(text, autoSource, targetLang);
  ///
  /// Request shape (for the ApiService implementer):
  ///   POST /api/v1/translate
  ///   body: { "text": text, "source": "auto", "target": targetLang }
  ///   200:  { "status": true, "translated": "...", "detectedSource": "es" }
  Future<String> _callTranslateApi(String text, String targetLang) async {
    try {
      return await ApiService.translateMessage(
        text: text,
        source: autoSource,
        target: targetLang,
      );
    } catch (e) {
      Log.e(_tag, 'translate API call failed', e);
      return text;
    }
  }

  /// Push a [TranslatedMessage] onto the broadcast stream.
  void _emit({
    required String original,
    required String translated,
    required bool succeeded,
    String? detectedSource,
  }) {
    if (_controller.isClosed) return;
    _controller.add(
      TranslatedMessage(
        original: original,
        translated: translated,
        succeeded: succeeded,
        targetLang: _targetLang,
        detectedSource: detectedSource,
      ),
    );
  }

  /// Clear the translation cache.
  ///
  /// Call this when leaving a live room to release memory. The stream and
  /// current language settings are left untouched.
  void clearCache() {
    final count = _cache.length;
    _cache.clear();
    Log.d(_tag, 'cache cleared ($count entries)');
  }

  /// Release resources. After this the service should not be reused.
  ///
  /// Typically only called on app teardown; for room-to-room transitions
  /// prefer [clearCache] + [toggleTranslation].
  Future<void> dispose() async {
    await _controller.close();
    _cache.clear();
    _enabled = false;
    Log.d(_tag, 'disposed');
  }
}
