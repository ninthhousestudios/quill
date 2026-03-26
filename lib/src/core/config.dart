import 'package:toml/toml.dart';

import 'key_matcher.dart';
import 'mode.dart';

/// Configuration for a [KeyMatcher]: bindings, chord timeout, and hint chars.
class QuillConfig {
  final Map<QuillMode, Map<KeyChord, String>> bindings;
  final Duration chordTimeout;
  final String hintChars;

  const QuillConfig({
    this.bindings = const {},
    this.chordTimeout = const Duration(milliseconds: 1500),
    this.hintChars = 'asdfghjkl',
  });

  /// Parse a TOML string into a [QuillConfig].
  ///
  /// Recognised top-level tables:
  /// - `[settings]` — `chord_timeout_ms` (int), `hint_chars` (string)
  /// - `[normal]`   — key → action name bindings for [NormalMode]
  /// - `[insert]`   — key → action name bindings for [InsertMode]
  /// - `[hint]`     — key → action name bindings for [HintMode]
  ///
  /// Unknown section names are silently skipped.
  factory QuillConfig.fromToml(String tomlString) {
    final doc = TomlDocument.parse(tomlString).toMap();

    // --- settings ---
    Duration chordTimeout = const Duration(milliseconds: 1500);
    String hintChars = 'asdfghjkl';

    final settings = doc['settings'];
    if (settings is Map) {
      final timeoutMs = settings['chord_timeout_ms'];
      if (timeoutMs is int) {
        chordTimeout = Duration(milliseconds: timeoutMs);
      }
      final chars = settings['hint_chars'];
      if (chars is String) {
        hintChars = chars;
      }
    }

    // --- mode sections ---
    const modeNames = {
      'normal': NormalMode(),
      'insert': InsertMode(),
      'hint': HintMode(),
    };

    final bindings = <QuillMode, Map<KeyChord, String>>{};

    for (final entry in modeNames.entries) {
      final section = doc[entry.key];
      if (section is! Map) continue;

      final modeBindings = <KeyChord, String>{};
      for (final kv in section.entries) {
        final key = kv.key;
        final value = kv.value;
        if (key is String && value is String) {
          modeBindings[KeyChord.parse(key)] = value;
        }
      }
      if (modeBindings.isNotEmpty) {
        bindings[entry.value] = modeBindings;
      }
    }

    return QuillConfig(
      bindings: bindings,
      chordTimeout: chordTimeout,
      hintChars: hintChars,
    );
  }

  /// Return a new [QuillConfig] where [other]'s values overlay this config.
  ///
  /// - Bindings: for each mode in [other], its chords are merged on top of
  ///   this config's chords for that mode. [other] wins on conflicts.
  /// - [chordTimeout]: [other]'s value is used if it differs from the default.
  /// - [hintChars]: [other]'s value is used if it differs from the default.
  QuillConfig merge(QuillConfig other) {
    // Merge bindings: start with a deep copy of this, then overlay other.
    final merged = <QuillMode, Map<KeyChord, String>>{
      for (final entry in bindings.entries)
        entry.key: Map<KeyChord, String>.of(entry.value),
    };

    for (final entry in other.bindings.entries) {
      final mode = entry.key;
      if (merged.containsKey(mode)) {
        merged[mode]!.addAll(entry.value);
      } else {
        merged[mode] = Map<KeyChord, String>.of(entry.value);
      }
    }

    const defaultTimeout = Duration(milliseconds: 1500);
    const defaultHintChars = 'asdfghjkl';

    return QuillConfig(
      bindings: merged,
      chordTimeout:
          other.chordTimeout != defaultTimeout ? other.chordTimeout : chordTimeout,
      hintChars: other.hintChars != defaultHintChars ? other.hintChars : hintChars,
    );
  }
}
