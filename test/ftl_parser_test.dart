import 'package:flutter_test/flutter_test.dart';

import '../tool/ftl_parser.dart';

void main() {
  group('FtlParser', () {
    const parser = FluentParser();

    test('parses simple message without arguments', () {
      const ftl = 'welcome = Welcome to our app';
      final result = parser.parse(ftl);
      expect(result['welcome']?.arguments, isEmpty);
    });

    test('parses message with simple variable', () {
      const ftl = r'hello = Hello, { $name }!';
      final result = parser.parse(ftl);
      expect(result['hello']?.arguments, hasLength(1));
      expect(result['hello']?.arguments.first.name, 'name');
      expect(result['hello']?.arguments.first.type, 'Object?');
    });

    test('parses message with multiple variables', () {
      const ftl = r'msg = { $user } has { $count } messages.';
      final result = parser.parse(ftl);
      final args = result['msg']?.arguments ?? [];
      expect(args, hasLength(2));
      expect(args.any((a) => a.name == 'user'), isTrue);
      expect(args.any((a) => a.name == 'count'), isTrue);
    });

    test('infers num type for NUMBER function', () {
      const ftl = r'user-count = { NUMBER($count) } users';
      final result = parser.parse(ftl);
      final arg = result['user-count']?.arguments.first;
      expect(arg?.name, 'count');
      expect(arg?.type, 'num');
    });

    test('infers DateTime type for DATETIME function', () {
      const ftl = r'date = Today is { DATETIME($today) }';
      final result = parser.parse(ftl);
      final arg = result['date']?.arguments.first;
      expect(arg?.name, 'today');
      expect(arg?.type, 'DateTime');
    });

    test('parses select expression (plural) correctly', () {
      const ftl = r'''
user-count-complex =
    { $count ->
        [one] 1 user
       *[other] { $count } users
    }
''';
      final result = parser.parse(ftl);
      final args = result['user-count-complex']?.arguments ?? [];
      expect(args, hasLength(1));
      expect(args.first.name, 'count');
      expect(args.first.type, 'Object?');
    });

    test('infers specific type even if variable is also used generally', () {
      const ftl = r'''
mixed = 
    { $count -> 
        [one] One 
       *[other] { NUMBER($count) } 
    }
''';
      final result = parser.parse(ftl);
      final arg = result['mixed']?.arguments.first;
      expect(arg?.name, 'count');
      expect(arg?.type, 'num');
    });

    test('handles term references with arguments', () {
      const ftl = r'''
-brand-name = Lispinto
msg = Welcome to { -brand-name($version) }
''';
      final result = parser.parse(ftl);
      final args = result['msg']?.arguments ?? [];
      expect(args, hasLength(1));
      expect(args.first.name, 'version');
    });

    test('handles nested select expressions', () {
      const ftl = r'''
nested = 
    { $gender ->
        [male] { $count ->
            [one] He has one message
           *[other] He has { $count } messages
        }
       *[other] They have messages
    }
''';
      final result = parser.parse(ftl);
      final args = result['nested']?.arguments ?? [];
      expect(args.any((a) => a.name == 'gender'), isTrue);
      expect(args.any((a) => a.name == 'count'), isTrue);
      expect(args, hasLength(2));
    });

    test('handles function references with positional variable args', () {
      const ftl = r'custom = { MY_FUNC($var1, $var2) }';
      final result = parser.parse(ftl);
      final args = result['custom']?.arguments ?? [];
      expect(args, hasLength(2));
      expect(args.any((a) => a.name == 'var1'), isTrue);
      expect(args.any((a) => a.name == 'var2'), isTrue);
    });
  });
}
