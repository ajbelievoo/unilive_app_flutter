import 'package:flutter/material.dart';

class SocialSpan {
  final String text;
  final SocialSpanType type;
  final String? id;

  SocialSpan(this.text, this.type, {this.id});
}

enum SocialSpanType { text, mention, hashtag, url }

class SocialSpanUtil {
  static List<SocialSpan> parse(String text) {
    final spans = <SocialSpan>[];
    final regex = RegExp(r'(@\w+)|(#\w+)|(https?://\S+)');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(SocialSpan(text.substring(lastEnd, match.start), SocialSpanType.text));
      }
      final matchedText = match.group(0)!;
      if (matchedText.startsWith('@')) {
        spans.add(SocialSpan(matchedText, SocialSpanType.mention));
      } else if (matchedText.startsWith('#')) {
        spans.add(SocialSpan(matchedText, SocialSpanType.hashtag));
      } else {
        spans.add(SocialSpan(matchedText, SocialSpanType.url));
      }
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(SocialSpan(text.substring(lastEnd), SocialSpanType.text));
    }
    return spans;
  }

  static TextSpan buildTextSpan(
    String text, {
    TextStyle? baseStyle,
    TextStyle? mentionStyle,
    TextStyle? hashtagStyle,
    TextStyle? urlStyle,
    void Function(SocialSpan)? onTap,
  }) {
    final spans = parse(text);
    return TextSpan(
      children: spans.map((span) {
        TextStyle? style;
        switch (span.type) {
          case SocialSpanType.mention:
            style = mentionStyle ?? const TextStyle(color: Color(0xFF7E3FF2), fontWeight: FontWeight.w600);
            break;
          case SocialSpanType.hashtag:
            style = hashtagStyle ?? const TextStyle(color: Color(0xFF1DA1F2), fontWeight: FontWeight.w600);
            break;
          case SocialSpanType.url:
            style = urlStyle ?? const TextStyle(color: Color(0xFF1DA1F2), decoration: TextDecoration.underline);
            break;
          case SocialSpanType.text:
            style = baseStyle;
            break;
        }
        return WidgetSpan(
          child: GestureDetector(
            onTap: onTap != null ? () => onTap(span) : null,
            child: Text(span.text, style: style),
          ),
        );
      }).toList(),
    );
  }

  static List<String> extractMentions(String text) {
    final regex = RegExp(r'@(\w+)');
    return regex.allMatches(text).map((m) => m.group(1)!).toList();
  }

  static List<String> extractHashtags(String text) {
    final regex = RegExp(r'#(\w+)');
    return regex.allMatches(text).map((m) => m.group(1)!).toList();
  }
}
