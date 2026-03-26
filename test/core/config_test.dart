import 'package:test/test.dart';
import 'package:quill_keys/src/core/config.dart';
import 'package:quill_keys/src/core/key_matcher.dart';
import 'package:quill_keys/src/core/mode.dart';

void main() {
  group('QuillConfig', () {
    test('fromToml parses normal mode bindings', () {
      const toml = '''
[normal]
j = "scroll-down"
k = "scroll-up"
"<Escape>" = "normal-mode"
''';
      final config = QuillConfig.fromToml(toml);
      final normalBindings = config.bindings[const NormalMode()];
      expect(normalBindings, isNotNull);
      expect(normalBindings![KeyChord.parse('j')], equals('scroll-down'));
      expect(normalBindings[KeyChord.parse('k')], equals('scroll-up'));
      expect(normalBindings[KeyChord.parse('<Escape>')], equals('normal-mode'));
    });

    test('fromToml parses multiple modes with chords', () {
      const toml = '''
[normal]
gt = "next-tab"
"gT" = "prev-tab"
f = "hint-activate"

[insert]
"<Escape>" = "normal-mode"
''';
      final config = QuillConfig.fromToml(toml);

      final normalBindings = config.bindings[const NormalMode()];
      expect(normalBindings, isNotNull);
      expect(normalBindings![KeyChord.parse('gt')], equals('next-tab'));
      expect(normalBindings[KeyChord.parse('gT')], equals('prev-tab'));
      expect(normalBindings[KeyChord.parse('f')], equals('hint-activate'));

      final insertBindings = config.bindings[const InsertMode()];
      expect(insertBindings, isNotNull);
      expect(insertBindings![KeyChord.parse('<Escape>')], equals('normal-mode'));
    });

    test('fromToml parses settings', () {
      const toml = '''
[settings]
chord_timeout_ms = 800
hint_chars = "fjdksla"
''';
      final config = QuillConfig.fromToml(toml);
      expect(config.chordTimeout, equals(const Duration(milliseconds: 800)));
      expect(config.hintChars, equals('fjdksla'));
    });

    test('merge overlays bindings', () {
      final base = QuillConfig(
        bindings: {
          const NormalMode(): {
            KeyChord.parse('j'): 'scroll-down',
            KeyChord.parse('k'): 'scroll-up',
          },
        },
      );

      final overlay = QuillConfig(
        bindings: {
          const NormalMode(): {
            KeyChord.parse('j'): 'custom-down', // conflicts — overlay wins
            KeyChord.parse('gg'): 'go-top',    // new binding — added
          },
          const InsertMode(): {
            KeyChord.parse('<Escape>'): 'normal-mode', // new mode — added
          },
        },
      );

      final merged = base.merge(overlay);
      final normal = merged.bindings[const NormalMode()]!;

      // overlay wins on conflict
      expect(normal[KeyChord.parse('j')], equals('custom-down'));
      // base's non-conflicting binding preserved
      expect(normal[KeyChord.parse('k')], equals('scroll-up'));
      // overlay's new binding added
      expect(normal[KeyChord.parse('gg')], equals('go-top'));

      // new mode from overlay present
      final insert = merged.bindings[const InsertMode()];
      expect(insert, isNotNull);
      expect(insert![KeyChord.parse('<Escape>')], equals('normal-mode'));
    });

    test('fromToml empty section does not crash', () {
      const toml = '[normal]\n';
      final config = QuillConfig.fromToml(toml);
      // An empty [normal] section should not crash and should produce no
      // bindings for NormalMode (or an empty map, depending on impl).
      final normalBindings = config.bindings[const NormalMode()];
      // Either absent or empty — both are acceptable.
      expect(normalBindings == null || normalBindings.isEmpty, isTrue);
    });
  });
}
