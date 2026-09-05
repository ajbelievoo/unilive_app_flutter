/// Type-aware OCR parser for Indian government ID cards.
///
/// Extracts `fullName`, `dob` (YYYY-MM-DD), `idNumber`, and `address` from
/// the raw text returned by Google ML Kit text recognition. The `cardType`
/// hint tunes the ID number regex (aadhaar, pan, voterId, passport,
/// drivingLicense, other).
library kyc_ocr_parser;

import 'package:belive/utils/log.dart';

class KycOcrParser {
  /// Parse raw OCR text into a structured map.
  ///
  /// [cardType] is one of aadhaar, pan, voterId, passport, drivingLicense,
  /// other. If null or 'other', the parser tries to auto-detect from keywords.
  /// [logTag] is optional and used for debug logging.
  static Map<String, String> parse(String text, {String? cardType, String logTag = 'KycOcrParser'}) {
    final lines = _cleanOcrLines(text);
    final detectedType = _detectCardType(text, cardType);

    final idNumber = _extractIdNumber(text, lines, detectedType);
    final dob = _extractDob(text, lines);
    final fullName = _extractName(text, lines, idNumber, dob);
    final address = _extractAddress(text, lines);

    Log.d(logTag, 'Parsed ($detectedType): name=$fullName, dob=$dob, '
        'id=$idNumber, address=$address');

    return {
      'fullName': fullName,
      'dob': dob,
      'idNumber': idNumber,
      'address': address,
    };
  }

  /// Clean the raw OCR text into sensible, trimmed, non-empty lines.
  static List<String> _cleanOcrLines(String text) {
    return text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && l.length > 2)
        .map((l) => l.replaceAll(RegExp(r'\s+'), ' '))
        .toList();
  }

  /// Detect the card type from the OCR text, falling back to the hint from
  /// the user when no keywords are found.
  static String _detectCardType(String text, String? hint) {
    final lower = text.toLowerCase();
    if (lower.contains('aadhaar') || lower.contains('uidai')) return 'aadhaar';
    if (lower.contains('income tax') && lower.contains('permanent')) return 'pan';
    if (RegExp(r'\b[a-z]{3}\d{7}\b', caseSensitive: false).hasMatch(text)) return 'voterId';
    if (lower.contains('passport') || lower.contains('republic of india')) return 'passport';
    if (lower.contains('driving') ||
        lower.contains('drive') ||
        lower.contains('license') ||
        lower.contains('licence') ||
        RegExp(r'\b[A-Z]{2}\d{2,}').hasMatch(text)) {
      return 'drivingLicense';
    }
    if (hint != null && hint.isNotEmpty && hint != 'other') return hint;
    return 'other';
  }

  /// Extract the ID / document number, picking the card-type-specific pattern
  /// with the highest priority. Never extracts bare labels like "Issued".
  static String _extractIdNumber(String text, List<String> lines, String cardType) {
    // Remove common label words so we don't extract "Issued" or "Number".
    final cleanText = text
        .replaceAll(
          RegExp(r'\b(issued?|number|no\.?|card|id)\s*[:.]', caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ');

    switch (cardType) {
      case 'aadhaar':
        final aadhaarMatch = RegExp(r'\b(\d{4}\s?\d{4}\s?\d{4})\b')
            .firstMatch(cleanText);
        if (aadhaarMatch != null) {
          final aadhaar = aadhaarMatch.group(1)!.replaceAll(' ', '');
          if (aadhaar.length == 12) return aadhaar;
        }
        final aadhaarPlain = RegExp(r'\b(\d{12})\b').firstMatch(cleanText);
        if (aadhaarPlain != null) {
          final aadhaar = aadhaarPlain.group(1)!;
          if (aadhaar.length == 12) return aadhaar;
        }
        break;
      case 'pan':
        final pan = RegExp(r'\b([A-Z]{5}\d{4}[A-Z])\b')
            .firstMatch(cleanText.toUpperCase())
            ?.group(1);
        if (pan != null) return pan;
        break;
      case 'voterId':
        final voter = RegExp(r'\b([A-Z]{3}\d{7})\b')
            .firstMatch(cleanText.toUpperCase())
            ?.group(1);
        if (voter != null) return voter;
        break;
      case 'passport':
        final pp = RegExp(r'\b([A-Z]\d{7,8})\b')
            .firstMatch(cleanText.toUpperCase())
            ?.group(1);
        if (pp != null) return pp;
        break;
      case 'drivingLicense':
        // Indian DL: e.g. UP24 20200009957, HR-02 2020 0001234
        final dl1 = RegExp(r'\b([A-Z]{2}[-\s]?\d{2,3}(?:[-\s]?\d{4,})+)\b')
            .firstMatch(cleanText.toUpperCase())
            ?.group(1)
            ?.replaceAll(RegExp(r'\s+'), ' ');
        if (dl1 != null && dl1.length > 8) return dl1;
        final dl2 = RegExp(r'\b([A-Z]{2}\d{2,}\s*\d{4,})\b')
            .firstMatch(cleanText.toUpperCase())
            ?.group(1)
            ?.replaceAll(RegExp(r'\s+'), ' ');
        if (dl2 != null && dl2.length > 8) return dl2;
        break;
    }

    // Fallback: look for any plausible 6-18 char alphanumeric code, but avoid
    // all-digit phone numbers and short year-only sequences.
    final fallback = RegExp(r'\b([A-Z0-9]{6,18})\b')
        .allMatches(cleanText.toUpperCase())
        .map((m) => m.group(1)!)
        .where((s) => !RegExp(r'^\d{4,10}$').hasMatch(s))
        .where((s) => s.length >= 6)
        .where((s) => !['ISSUED', 'NUMBER', 'NO', 'NO.', 'VALID', 'VALIDITY', 'INDIA']
            .contains(s))
        .firstOrNull;
    return fallback ?? '';
  }

  /// Extract the date of birth, supporting many Indian/ISO formats.
  /// Prefers a DOB near "DOB"/"Date of Birth" label.
  static String _extractDob(String text, List<String> lines) {
    // Try context-aware patterns first: "DOB / Date of Birth / Birth: ...".
    final contextPatterns = [
      RegExp(r'(?:DOB|Date of Birth|Birth|Date/Birth)\s*[:.]?\s*(\d{1,2}[/\.\-]\d{1,2}[/\.\-]\d{2,4})', caseSensitive: false),
      RegExp(r'(?:DOB|Date of Birth|Birth)\s*[:.]?\s*(\d{8})', caseSensitive: false),
    ];
    for (final pattern in contextPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final normalized = _normalizeDob(match.group(1)!);
        if (_isPlausibleDob(normalized)) return normalized;
      }
    }

    // Generic date patterns anywhere in the text.
    final genericPatterns = [
      RegExp(r'\b(\d{1,2}[/\.\-]\d{1,2}[/\.\-]\d{4})\b'),
      RegExp(r'\b(\d{4}[/\.\-]\d{1,2}[/\.\-]\d{1,2})\b'),
      RegExp(r'\b(\d{8})\b'), // DDMMYYYY / YYYYMMDD
    ];
    for (final pattern in genericPatterns) {
      for (final match in pattern.allMatches(text)) {
        final normalized = _normalizeDob(match.group(1)!);
        if (_isPlausibleDob(normalized)) return normalized;
      }
    }

    return '';
  }

  /// True if the normalized date looks like a real DOB.
  static bool _isPlausibleDob(String normalized) {
    if (normalized.isEmpty) return false;
    final parts = normalized.split('-');
    if (parts.length != 3) return false;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return false;
    if (month < 1 || month > 12 || day < 1 || day > 31) return false;
    if (year < 1900 || year > DateTime.now().year - 16) return false;
    // Reject impossible dates like 31 Feb.
    try {
      final d = DateTime(year, month, day);
      if (d.year != year || d.month != month || d.day != day) return false;
    } catch (_) {
      return false;
    }
    return true;
  }

  /// Extract the card holder's full name.
  ///
  /// 1. Look for explicit "Name" / "Full Name" labels.
  /// 2. Otherwise, scan for a 2-6 word alphabetic line that is not a known
  ///    label, not a date, not the idNumber, and looks like a person.
  static String _extractName(String text, List<String> lines, String idNumber, String dob) {
    // Common labels before a name on Indian IDs.
    final namePatterns = [
      RegExp(r'(?:Name|Full Name|नाम|नाम:|Naam)\s*[:.\-]?\s*([A-Za-z][A-Za-z\s\.]{2,})', caseSensitive: false),
      RegExp(r'(?:Name|Full Name)\s*[&@#]?\s*([A-Za-z][A-Za-z\s\.]{2,})', caseSensitive: false),
    ];
    for (final pattern in namePatterns) {
      for (final match in pattern.allMatches(text)) {
        final name = match.group(1)!.trim();
        if (_isNameLike(name)) return _titleCase(name);
      }
    }

    final labelWords = <String>{
      'government', 'india', 'bharat', 'state', 'republic', 'union',
      'identity', 'card', 'certificate', 'license', 'licence',
      'national', 'passport', 'pan', 'aadhaar', 'voter', 'election',
      'driving', 'drive', 'transport', 'ministry', 'department',
      'commission', 'authority', 'issue', 'valid', 'validity',
      'date', 'birth', 'dob', 'sex', 'male', 'female', 'gender',
      'address', 'house', 'street', 'road', 'district', 'pin', 'code',
      'phone', 'mobile', 'father', 'husband', 'son', 'daughter', 'wife',
      'of', 'uidai', 'unique', 'identification', 'number', 'no', 'issued',
      'go', 'logo', 'help', 'www', 'com', 'http', 'gov',
      'transportation', 'vehicle', 'motor', 'automobile',
    };

    // Look at the earliest non-label alphabetic line(s). Names usually appear
    // near the top of the card, before DOB/ID numbers.
    for (final line in lines) {
      if (line.isEmpty) continue;
      if (line.toLowerCase() == line.toUpperCase() && !line.contains(' ')) continue;
      // All-caps names are very common on ID cards.
      final trimmed = line.trim();
      if (trimmed.length < 4) continue;

      final lower = trimmed.toLowerCase();
      if (labelWords.any((w) => lower.contains(w))) continue;

      // Reject if it has a date pattern, the ID number, or looks like an address.
      if (RegExp(r'\b\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4}\b').hasMatch(trimmed)) continue;
      if (RegExp(r'\d{6,}').hasMatch(trimmed) && !trimmed.contains(RegExp(r'[A-Za-z]{4,}'))) continue;

      final words = trimmed.split(RegExp(r'\s+'));
      if (words.length < 2 || words.length > 6) continue;

      // Skip if this line is part of an address section.
      final addrIdx = lines.indexWhere((l) => l.toLowerCase().contains('address') || l.toLowerCase().contains('पत'));
      if (addrIdx != -1 && lines.indexOf(line) >= addrIdx) continue;

      if (_isNameLike(trimmed)) return _titleCase(trimmed);
    }

    return '';
  }

  /// True if the string looks like a person's name.
  static bool _isNameLike(String s) {
    final words = s.trim().split(RegExp(r'\s+'));
    if (words.length < 2 || words.length > 6) return false;
    // Allow middle initials like "A. KUMAR" or "RAJESH K.".
    final letters = words
        .where((w) => w.isNotEmpty)
        .expand((w) => w.replaceAll(RegExp(r'[^A-Za-z]'), '').split(''))
        .join();
    if (letters.length < 4) return false;
    return true;
  }

  /// Extract the address ONLY if the card explicitly has an "Address" label.
  ///
  /// This prevents the bug where the name/DOB/etc. were dumped into the
  /// address field when no address actually existed.
  static String _extractAddress(String text, List<String> lines) {
    final labelPattern = RegExp(
      r'(?:^|\b)(Address|Address:|पत|स्थायी पत|Permanent Address|Current Address)\s*[:.]?',
      caseSensitive: false,
    );
    final matches = labelPattern.allMatches(text).toList();
    if (matches.isEmpty) return '';

    final startMatch = matches.first;
    final label = startMatch.group(0)!;
    final startIdx = lines.indexWhere((l) => l.toLowerCase().contains(label.toLowerCase().trim()));

    if (startIdx != -1) {
      final addrLine = lines[startIdx];
      final afterLabel = addrLine
          .replaceFirstMapped(labelPattern, (m) => '')
          .trim();
      final parts = <String>[
        if (afterLabel.isNotEmpty && !RegExp(r'^\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4}$').hasMatch(afterLabel))
          afterLabel,
        for (int i = startIdx + 1; i < lines.length && i < startIdx + 5; i++)
          if (!_isNoiseLine(lines[i])) lines[i],
      ];
      final address = parts.join(', ').replaceAll(RegExp(r',\s*,+'), ',').trim();
      // If the only content we found is numeric, it's not a real address.
      if (RegExp(r'^[\d\s,./\-]+$').hasMatch(address)) return '';
      return address;
    }

    return '';
  }

  /// True if a line is likely not part of an address (e.g. another label or a date).
  static bool _isNoiseLine(String line) {
    final lower = line.toLowerCase();
    final labels = [
      'name', 'dob', 'date of birth', 'father', 'husband', 'aadhaar', 'pan',
      'voter', 'license', 'licence', 'number', 'no.', 'issued', 'valid',
      'validity', 'signature', 'photo', ' thumb', 'date', 'birth',
    ];
    if (labels.any((l) => lower.contains(l))) return true;
    // Reject lines that are only a date or a number sequence.
    if (RegExp(r'^\s*\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4}\s*$').hasMatch(line)) return true;
    if (RegExp(r'^\s*\d{6,}\s*$').hasMatch(line)) return true;
    return false;
  }

  /// Normalize a date string to YYYY-MM-DD format.
  static String _normalizeDob(String raw) {
    if (raw.length == 8 && !raw.contains(RegExp(r'[/\.\-]'))) {
      // Likely DDMMYYYY / YYYYMMDD with no separators (OCR error).
      if (int.tryParse(raw) != null) {
        final firstTwo = int.tryParse(raw.substring(0, 2));
        if (firstTwo != null && firstTwo > 31) {
          // YYYYMMDD
          return '${raw.substring(0, 4)}-${raw.substring(4, 6)}-${raw.substring(6, 8)}';
        } else {
          // DDMMYYYY
          return '${raw.substring(4, 8)}-${raw.substring(2, 4)}-${raw.substring(0, 2)}';
        }
      }
    }

    final parts = raw.split(RegExp(r'[/\.\-]'));
    if (parts.length != 3) return raw;
    String day, month, year;
    if (parts[0].length == 4) {
      // YYYY-MM-DD
      year = parts[0];
      month = parts[1].padLeft(2, '0');
      day = parts[2].padLeft(2, '0');
    } else {
      // DD-MM-YYYY or DD/MM/YY
      day = parts[0].padLeft(2, '0');
      month = parts[1].padLeft(2, '0');
      year = parts[2].length == 2 ? '19${parts[2]}' : parts[2];
    }
    return '$year-$month-$day';
  }

  /// Convert a string to Title Case (each word capitalized).
  /// Returns true if the string is a valid government ID number.
  ///
  /// This is a lightweight helper for on-device preflight checks before
  /// accepting an OCR result.
  static bool isPlausibleIdNumber(String idNumber, String cardType) {
    if (idNumber.trim().isEmpty) return false;
    switch (cardType) {
      case 'aadhaar':
        return RegExp(r'^\d{12}$').hasMatch(idNumber.replaceAll(' ', ''));
      case 'pan':
        return RegExp(r'^[A-Z]{5}\d{4}[A-Z]$').hasMatch(idNumber.toUpperCase());
      case 'voterId':
        return RegExp(r'^[A-Z]{3}\d{7}$').hasMatch(idNumber.toUpperCase());
      case 'passport':
        return RegExp(r'^[A-Z]\d{7,8}$').hasMatch(idNumber.toUpperCase());
      case 'drivingLicense':
        return idNumber.length >= 8 && idNumber.length <= 24;
      default:
        return idNumber.length >= 6;
    }
  }

  static String _titleCase(String input) {
    return input
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty
            ? w
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }
}
