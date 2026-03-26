import 'dart:async';

import 'mode.dart';

/// A sequence of key identifiers representing a keybinding chord.
///
/// Simple characters are stored as single-character strings (e.g. `['g', 't']`
/// for the binding `"gt"`). Special keys use descriptive names:
/// `['Escape']`, `['Control', 'x']`, `['Shift', 'a']`.
class KeyChord {
  final List<String> keys;

  const KeyChord(this.keys);

  /// Parse a binding string from TOML config into a [KeyChord].
  ///
  /// Supports:
  /// - Simple characters: `"gt"` → `['g', 't']`
  /// - Special keys in angle brackets: `"<Escape>"` → `['Escape']`
  /// - Modifier shortcuts: `"<C-x>"` → `['Control', 'x']`,
  ///   `"<S-a>"` → `['Shift', 'a']`
  /// - Mixed: `"g<C-t>"` → `['g', 'Control', 't']`
  factory KeyChord.parse(String binding) {
    final keys = <String>[];
    var i = 0;
    while (i < binding.length) {
      if (binding[i] == '<') {
        final end = binding.indexOf('>', i);
        if (end == -1) {
          // Malformed — treat the '<' as a literal character.
          keys.add(binding[i]);
          i++;
        } else {
          final inner = binding.substring(i + 1, end);
          keys.addAll(_parseAngleBracket(inner));
          i = end + 1;
        }
      } else {
        keys.add(binding[i]);
        i++;
      }
    }
    return KeyChord(keys);
  }

  static List<String> _parseAngleBracket(String inner) {
    // Modifier shortcuts: C-x → ['Control', 'x'], S-a → ['Shift', 'a']
    if (inner.length >= 3 && inner[1] == '-') {
      final modifier = inner[0].toUpperCase();
      final key = inner.substring(2);
      switch (modifier) {
        case 'C':
          return ['Control', key];
        case 'S':
          return ['Shift', key];
        case 'A':
          return ['Alt', key];
        case 'M':
          return ['Meta', key];
        default:
          return [inner]; // Unknown modifier — return as-is.
      }
    }
    // Named special key, e.g. Escape, Return, Tab, Space.
    return [inner];
  }

  int get length => keys.length;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! KeyChord) return false;
    if (keys.length != other.keys.length) return false;
    for (var i = 0; i < keys.length; i++) {
      if (keys[i] != other.keys[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(keys);

  @override
  String toString() => 'KeyChord(${keys.join(', ')})';
}

// ---------------------------------------------------------------------------
// KeyMatchResult
// ---------------------------------------------------------------------------

/// The result returned by [KeyMatcher.feed] after processing one key.
sealed class KeyMatchResult {
  const KeyMatchResult();
}

/// A complete chord was matched. [actionName] identifies the bound action.
final class MatchFound extends KeyMatchResult {
  final String actionName;
  const MatchFound(this.actionName);

  @override
  bool operator ==(Object other) =>
      other is MatchFound && other.actionName == actionName;

  @override
  int get hashCode => actionName.hashCode;

  @override
  String toString() => 'MatchFound($actionName)';
}

/// The keys fed so far are a prefix of one or more bindings.
/// Wait for more keys or a timeout.
final class PartialMatch extends KeyMatchResult {
  const PartialMatch();

  @override
  bool operator ==(Object other) => other is PartialMatch;

  @override
  int get hashCode => (PartialMatch).hashCode;

  @override
  String toString() => 'PartialMatch()';
}

/// No binding matches the current key sequence. The input is discarded.
final class NoMatch extends KeyMatchResult {
  const NoMatch();

  @override
  bool operator ==(Object other) => other is NoMatch;

  @override
  int get hashCode => (NoMatch).hashCode;

  @override
  String toString() => 'NoMatch()';
}

// ---------------------------------------------------------------------------
// Internal trie
// ---------------------------------------------------------------------------

class _TrieNode {
  final Map<String, _TrieNode> children = {};
  String? actionName;
}

// ---------------------------------------------------------------------------
// KeyMatcher
// ---------------------------------------------------------------------------

/// Matches incoming key events against a set of mode-specific chord bindings.
///
/// Internally maintains a trie per mode. Call [feed] once per key event.
/// When a partial chord is in progress, a [chordTimeout] timer is started;
/// if it fires, [onTimeout] is called and the position resets to the root.
///
/// Call [dispose] when done to cancel any active timer.
class KeyMatcher {
  /// How long to wait for the next key before abandoning a partial chord.
  Duration chordTimeout;

  /// Called when the chord timer fires. Use this to notify the UI layer.
  void Function()? onTimeout;

  final Map<QuillMode, _TrieNode> _roots = {};
  final Map<QuillMode, _TrieNode> _current = {};
  final List<String> _partialKeys = [];
  Timer? _timer;

  KeyMatcher(
    Map<QuillMode, Map<KeyChord, String>> bindings, {
    this.chordTimeout = const Duration(milliseconds: 1500),
    this.onTimeout,
  }) {
    for (final entry in bindings.entries) {
      final mode = entry.key;
      final root = _TrieNode();
      _roots[mode] = root;

      for (final binding in entry.value.entries) {
        var node = root;
        for (final key in binding.key.keys) {
          node = node.children.putIfAbsent(key, _TrieNode.new);
        }
        node.actionName = binding.value;
      }
    }
  }

  /// Feed one key identifier into the matcher for the given [mode].
  ///
  /// Returns a [KeyMatchResult] describing the outcome.
  KeyMatchResult feed(String key, QuillMode mode) {
    final root = _roots[mode];
    if (root == null) {
      _resetPosition();
      return const NoMatch();
    }

    // Current position: either mid-chord or at root.
    final from = _current[mode] ?? root;
    final next = from.children[key];

    if (next == null) {
      // Dead end — no match.
      _resetPosition();
      return const NoMatch();
    }

    _partialKeys.add(key);

    if (next.actionName != null && next.children.isEmpty) {
      // Terminal node with no further children — unambiguous match.
      final action = next.actionName!;
      _resetPosition();
      return MatchFound(action);
    }

    if (next.actionName != null && next.children.isNotEmpty) {
      // Terminal node that is also a prefix — prefer the match immediately.
      // (Vim behaviour: exact match wins over prefix ambiguity.)
      final action = next.actionName!;
      _resetPosition();
      return MatchFound(action);
    }

    // Internal node — partial match, advance position and start timer.
    _current[mode] = next;
    _startTimer();
    return const PartialMatch();
  }

  /// Reset to trie root and cancel any in-progress timer.
  void reset() {
    _resetPosition();
  }

  /// The keys fed so far during the current partial match, joined as a string.
  ///
  /// Empty string when no partial chord is in progress.
  String get partialChord => _partialKeys.join();

  /// Cancel the active chord timer and release resources.
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  // -------------------------------------------------------------------------
  // Internals
  // -------------------------------------------------------------------------

  void _resetPosition() {
    _current.clear();
    _partialKeys.clear();
    _timer?.cancel();
    _timer = null;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(chordTimeout, _onTimerFired);
  }

  void _onTimerFired() {
    _resetPosition();
    onTimeout?.call();
  }
}
