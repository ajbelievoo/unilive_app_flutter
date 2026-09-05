import 'package:flutter_test/flutter_test.dart';
import 'package:belive/models/json_annotation_helper.dart';

void main() {
  group('parseString', () {
    test('parses string correctly', () {
      expect(parseString('hello'), 'hello');
    });

    test('parses int as string', () {
      expect(parseString(42), '42');
    });

    test('parses double as string', () {
      expect(parseString(3.14), '3.14');
    });

    test('parses null as null (default)', () {
      expect(parseString(null), isNull);
    });
  });

  group('parseInt', () {
    test('parses int correctly', () {
      expect(parseInt(42, 0), 42);
    });

    test('parses string as int', () {
      expect(parseInt('100', 0), 100);
    });

    test('parses double as int', () {
      expect(parseInt(3.14, 0), 3);
    });

    test('parses null as default', () {
      expect(parseInt(null, 5), 5);
    });

    test('parses invalid string as default', () {
      expect(parseInt('abc', 10), 10);
    });
  });

  group('parseBool', () {
    test('parses bool correctly', () {
      expect(parseBool(true), true);
      expect(parseBool(false), false);
    });

    test('parses string "true" as true', () {
      expect(parseBool('true'), true);
      expect(parseBool('True'), true);
    });

    test('parses string "false" as false', () {
      expect(parseBool('false'), false);
    });

    test('parses int 1 as true, 0 as false', () {
      expect(parseBool(1), true);
      expect(parseBool(0), false);
    });

    test('parses null as false', () {
      expect(parseBool(null), false);
    });
  });

  group('parseDouble', () {
    test('parses double correctly', () {
      expect(parseDouble(3.14), 3.14);
    });

    test('parses int as double', () {
      expect(parseDouble(42), 42.0);
    });

    test('parses string as double', () {
      expect(parseDouble('3.14'), 3.14);
    });

    test('parses null as 0', () {
      expect(parseDouble(null), 0.0);
    });
  });

  group('parseList', () {
    test('parses list of maps correctly', () {
      final json = [
        {'value': 1},
        {'value': 2},
      ];
      final result = parseList<int>(json, (e) => e['value'] as int);
      expect(result, [1, 2]);
    });

    test('parses empty list', () {
      expect(parseList([], (e) => e), []);
    });

    test('parses null as empty list', () {
      expect(parseList(null, (e) => e), []);
    });

    test('skips non-map elements', () {
      final json = [1, 'two', {'value': 3}];
      final result = parseList<int>(json, (e) => e['value'] as int);
      expect(result, [3]);
    });
  });
}
