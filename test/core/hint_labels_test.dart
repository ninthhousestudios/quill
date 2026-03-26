import 'package:test/test.dart';
import 'package:quill_keys/src/core/hint_labels.dart';

void main() {
  group('HintLabelGenerator', () {
    const gen = HintLabelGenerator();

    test('few items returns single chars', () {
      expect(gen.generate(3), equals(['a', 's', 'd']));
    });

    test('exactly charset size returns all single chars', () {
      final labels = gen.generate(9);
      expect(labels, equals(['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l']));
    });

    test('more than charset expands to two chars', () {
      final labels = gen.generate(12);
      expect(labels.length, equals(12));
      expect(labels.toSet().length, equals(12), reason: 'all labels must be unique');

      // Some should be single-char, some two-char
      final singles = labels.where((l) => l.length == 1).toList();
      final doubles = labels.where((l) => l.length == 2).toList();
      expect(singles, isNotEmpty, reason: 'should have some single-char labels');
      expect(doubles, isNotEmpty, reason: 'should have some two-char labels');

      _expectNoPrefixConflicts(labels);
    });

    test('all labels unique for large count', () {
      final labels = gen.generate(50);
      expect(labels.length, equals(50));
      expect(labels.toSet().length, equals(50), reason: 'all 50 labels must be unique');
      _expectNoPrefixConflicts(labels);
    });

    test('custom chars respected', () {
      final custom = HintLabelGenerator(chars: 'abc');
      expect(custom.generate(3), equals(['a', 'b', 'c']));
    });

    test('generate(0) returns empty list', () {
      expect(gen.generate(0), isEmpty);
    });

    test('generate(1) returns first char', () {
      expect(gen.generate(1), equals(['a']));
    });
  });
}

/// Verifies that no label in [labels] is a prefix of any other label.
void _expectNoPrefixConflicts(List<String> labels) {
  final set = labels.toSet();
  for (final label in labels) {
    for (int len = 1; len < label.length; len++) {
      final prefix = label.substring(0, len);
      expect(
        set.contains(prefix),
        isFalse,
        reason: '"$prefix" is both a label and a prefix of "$label"',
      );
    }
  }
}
