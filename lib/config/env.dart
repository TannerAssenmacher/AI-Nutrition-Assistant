class Env {
  // Compile-time values provided via --dart-define or --dart-define-from-file
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );
  static const String edamamApiId = String.fromEnvironment(
    'EDAMAM_API_ID',
    defaultValue: '',
  );
  static const String edamamApiKey = String.fromEnvironment(
    'EDAMAM_API_KEY',
    defaultValue: '',
  );
  static const String openAiApiKey = String.fromEnvironment(
    'OPENAI_API_KEY',
    defaultValue: '',
  );

  static const String googleApiKeyWeb = String.fromEnvironment(
    'GOOGLE_API_KEY_WEB',
    defaultValue: '',
  );
  static const String googleApiKeyAndroid = String.fromEnvironment(
    'GOOGLE_API_KEY_ANDROID',
    defaultValue: '',
  );
  static const String googleApiKeyIos = String.fromEnvironment(
    'GOOGLE_API_KEY_IOS',
    defaultValue: '',
  );
  static const String googleApiKeyMacos = String.fromEnvironment(
    'GOOGLE_API_KEY_MACOS',
    defaultValue: '',
  );

  static String require(String value, String name) {
    if (value.isEmpty) {
      throw StateError('Missing env var $name (pass via --dart-define)');
    }
    return value;
  }
}
