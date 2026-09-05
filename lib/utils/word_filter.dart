/// Simple word filter for chat comments and live messages.
/// Masks banned words with asterisks. Used by chat + live room comments.
class WordFilter {
  WordFilter._();

  /// Default banned words list. Backend can override via settings in future.
  static const List<String> defaultBannedWords = [
    'fuck', 'shit', 'bitch', 'asshole', 'bastard', 'dick', 'pussy',
    'motherfucker', 'cunt', 'whore', 'slut', 'nigger', 'faggot',
    'bhosdi', 'bhosdike', 'chutiya', 'madarchod', 'behenchod',
    'lauda', 'lodu', 'gandu', 'harami', 'kutta', 'kamina',
  ];

  /// Check if text contains any banned word.
  static bool containsBanned(String text) {
    final lower = text.toLowerCase();
    return defaultBannedWords.any((w) => lower.contains(w));
  }

  /// Mask banned words in text with asterisks (preserves length).
  static String filter(String text) {
    var result = text;
    for (final word in defaultBannedWords) {
      final pattern = RegExp(RegExp.escape(word), caseSensitive: false);
      result = result.replaceAllMapped(pattern, (m) => '*' * m.group(0)!.length);
    }
    return result;
  }
}
