import 'package:fake_async/fake_async.dart';
import 'package:quill_keys/src/core/key_matcher.dart';
import 'package:quill_keys/src/core/mode.dart';
import 'package:test/test.dart';

void main() {
  // Convenience shorthands.
  const normal = NormalMode();
  const insert = InsertMode();

  // ---------------------------------------------------------------------------
  // KeyChord.parse
  // ---------------------------------------------------------------------------
  group('KeyChord.parse', () {
    test('simple single char', () {
      expect(KeyChord.parse('j'), equals(KeyChord(['j'])));
    });

    test('simple multi-char chord', () {
      expect(KeyChord.parse('gt'), equals(KeyChord(['g', 't'])));
    });

    test('<Escape> special key', () {
      expect(KeyChord.parse('<Escape>'), equals(KeyChord(['Escape'])));
    });

    test('<C-x> expands to Control + x', () {
      expect(KeyChord.parse('<C-x>'), equals(KeyChord(['Control', 'x'])));
    });

    test('<S-a> expands to Shift + a', () {
      expect(KeyChord.parse('<S-a>'), equals(KeyChord(['Shift', 'a'])));
    });

    test('mixed: g<C-t>', () {
      expect(
        KeyChord.parse('g<C-t>'),
        equals(KeyChord(['g', 'Control', 't'])),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // KeyChord equality and hashCode
  // ---------------------------------------------------------------------------
  group('KeyChord equality', () {
    test('equal when keys are identical', () {
      expect(KeyChord(['g', 't']), equals(KeyChord(['g', 't'])));
    });

    test('not equal when keys differ', () {
      expect(KeyChord(['g', 't']), isNot(equals(KeyChord(['g', 'j']))));
    });

    test('hashCode consistent with equality', () {
      expect(
        KeyChord(['g', 't']).hashCode,
        equals(KeyChord(['g', 't']).hashCode),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Single key match
  // ---------------------------------------------------------------------------
  group('single key match', () {
    late KeyMatcher matcher;

    setUp(() {
      matcher = KeyMatcher({
        normal: {KeyChord.parse('j'): 'scroll-down'},
      });
    });

    tearDown(() => matcher.dispose());

    test('j in NormalMode → MatchFound(scroll-down)', () {
      expect(matcher.feed('j', normal), equals(MatchFound('scroll-down')));
    });

    test('j in InsertMode → NoMatch (no bindings for InsertMode)', () {
      expect(matcher.feed('j', insert), isA<NoMatch>());
    });
  });

  // ---------------------------------------------------------------------------
  // Chord match
  // ---------------------------------------------------------------------------
  group('chord match', () {
    late KeyMatcher matcher;

    setUp(() {
      matcher = KeyMatcher({
        normal: {KeyChord.parse('gt'): 'next-tab'},
      });
    });

    tearDown(() => matcher.dispose());

    test('g → PartialMatch', () {
      expect(matcher.feed('g', normal), isA<PartialMatch>());
    });

    test('g then t → MatchFound(next-tab)', () {
      matcher.feed('g', normal);
      expect(matcher.feed('t', normal), equals(MatchFound('next-tab')));
    });

    test('unrelated key after partial → NoMatch', () {
      matcher.feed('g', normal);
      // 'x' is not a valid continuation of 'g'.
      expect(matcher.feed('x', normal), isA<NoMatch>());
    });
  });

  // ---------------------------------------------------------------------------
  // No match
  // ---------------------------------------------------------------------------
  group('no match', () {
    late KeyMatcher matcher;

    setUp(() {
      matcher = KeyMatcher({
        normal: {KeyChord.parse('j'): 'scroll-down'},
      });
    });

    tearDown(() => matcher.dispose());

    test('unbound key z → NoMatch', () {
      expect(matcher.feed('z', normal), isA<NoMatch>());
    });
  });

  // ---------------------------------------------------------------------------
  // Mode-specific bindings
  // ---------------------------------------------------------------------------
  group('mode-specific bindings', () {
    late KeyMatcher matcher;

    setUp(() {
      matcher = KeyMatcher({
        normal: {KeyChord.parse('j'): 'scroll-down'},
        insert: {KeyChord.parse('j'): 'self-insert'},
      });
    });

    tearDown(() => matcher.dispose());

    test('j in NormalMode → scroll-down', () {
      expect(matcher.feed('j', normal), equals(MatchFound('scroll-down')));
    });

    test('j in InsertMode → self-insert', () {
      expect(matcher.feed('j', insert), equals(MatchFound('self-insert')));
    });
  });

  // ---------------------------------------------------------------------------
  // reset() returns to root
  // ---------------------------------------------------------------------------
  group('reset', () {
    late KeyMatcher matcher;

    setUp(() {
      matcher = KeyMatcher({
        normal: {KeyChord.parse('gt'): 'next-tab'},
      });
    });

    tearDown(() => matcher.dispose());

    test('reset after partial restores root — can re-enter chord', () {
      expect(matcher.feed('g', normal), isA<PartialMatch>());
      matcher.reset();
      // After reset, feeding 'g' again should be PartialMatch (not NoMatch).
      expect(matcher.feed('g', normal), isA<PartialMatch>());
    });
  });

  // ---------------------------------------------------------------------------
  // partialChord tracks in-progress keys
  // ---------------------------------------------------------------------------
  group('partialChord', () {
    late KeyMatcher matcher;

    setUp(() {
      matcher = KeyMatcher({
        normal: {KeyChord.parse('gt'): 'next-tab'},
      });
    });

    tearDown(() => matcher.dispose());

    test('empty before any input', () {
      expect(matcher.partialChord, equals(''));
    });

    test('tracks fed keys during partial', () {
      matcher.feed('g', normal);
      expect(matcher.partialChord, equals('g'));
    });

    test('resets to empty after match', () {
      matcher.feed('g', normal);
      matcher.feed('t', normal);
      expect(matcher.partialChord, equals(''));
    });

    test('resets to empty after reset()', () {
      matcher.feed('g', normal);
      matcher.reset();
      expect(matcher.partialChord, equals(''));
    });
  });

  // ---------------------------------------------------------------------------
  // Chord timeout
  // ---------------------------------------------------------------------------
  group('chord timeout', () {
    test('onTimeout called after chordTimeout elapses', () {
      fakeAsync((async) {
        var timeoutFired = false;
        final matcher = KeyMatcher(
          {
            normal: {KeyChord.parse('gt'): 'next-tab'},
          },
          chordTimeout: const Duration(milliseconds: 100),
          onTimeout: () => timeoutFired = true,
        );

        matcher.feed('g', normal);
        expect(timeoutFired, isFalse);

        async.elapse(const Duration(milliseconds: 100));
        expect(timeoutFired, isTrue);

        // After timeout the position is reset — feeding 'g' again starts fresh.
        expect(matcher.feed('g', normal), isA<PartialMatch>());

        matcher.dispose();
      });
    });

    test('timer resets on each new key in partial', () {
      fakeAsync((async) {
        var timeoutCount = 0;
        final matcher = KeyMatcher(
          {
            normal: {
              KeyChord.parse('gt'): 'next-tab',
              KeyChord.parse('gx'): 'close-tab',
            },
          },
          chordTimeout: const Duration(milliseconds: 100),
          onTimeout: () => timeoutCount++,
        );

        matcher.feed('g', normal);

        // Advance 90ms — no timeout yet.
        async.elapse(const Duration(milliseconds: 90));
        expect(timeoutCount, equals(0));

        // Advance another 100ms — now timeout fires.
        async.elapse(const Duration(milliseconds: 100));
        expect(timeoutCount, equals(1));

        matcher.dispose();
      });
    });

    test('onTimeout resets shouldShowWhichKey', () {
      fakeAsync((async) {
        final matcher = KeyMatcher(
          {
            normal: {KeyChord.parse('gt'): 'next-tab'},
          },
          chordTimeout: const Duration(milliseconds: 200),
          whichKeyDelay: const Duration(milliseconds: 50),
        );

        matcher.feed('g', normal);
        async.elapse(const Duration(milliseconds: 50));
        expect(matcher.shouldShowWhichKey, isTrue);

        // Chord timeout fires — which-key resets.
        async.elapse(const Duration(milliseconds: 150));
        expect(matcher.shouldShowWhichKey, isFalse);

        matcher.dispose();
      });
    });

    test('dispose cancels timer — onTimeout not called', () {
      fakeAsync((async) {
        var timeoutFired = false;
        final matcher = KeyMatcher(
          {
            normal: {KeyChord.parse('gt'): 'next-tab'},
          },
          chordTimeout: const Duration(milliseconds: 100),
          onTimeout: () => timeoutFired = true,
        );

        matcher.feed('g', normal);
        matcher.dispose();

        async.elapse(const Duration(milliseconds: 200));
        expect(timeoutFired, isFalse);
      });
    });
  });

  // ---------------------------------------------------------------------------
  // continuations()
  // ---------------------------------------------------------------------------
  group('continuations', () {
    late KeyMatcher matcher;

    setUp(() {
      matcher = KeyMatcher({
        normal: {
          KeyChord.parse('gt'): 'next-tab',
          KeyChord.parse('gT'): 'prev-tab',
          KeyChord.parse('gg'): 'scroll-top',
          KeyChord.parse('j'): 'scroll-down',
        },
      });
    });

    tearDown(() => matcher.dispose());

    test('at root returns all top-level keys', () {
      final conts = matcher.continuations(normal);
      final keys = conts.map((c) => c.key).toSet();
      expect(keys, equals({'g', 'j'}));
    });

    test('after partial returns children of current node', () {
      matcher.feed('g', normal);
      final conts = matcher.continuations(normal);
      final keys = conts.map((c) => c.key).toSet();
      expect(keys, equals({'t', 'T', 'g'}));
    });

    test('terminal children have actionName set', () {
      matcher.feed('g', normal);
      final conts = matcher.continuations(normal);
      final nextTab = conts.firstWhere((c) => c.key == 't');
      expect(nextTab.actionName, equals('next-tab'));
      expect(nextTab.hasChildren, isFalse);
    });

    test('intermediate node at root has null actionName and hasChildren', () {
      final conts = matcher.continuations(normal);
      final g = conts.firstWhere((c) => c.key == 'g');
      expect(g.actionName, isNull);
      expect(g.hasChildren, isTrue);
    });

    test('returns empty list for mode with no bindings', () {
      expect(matcher.continuations(insert), isEmpty);
    });

    test('resets to root continuations after match completes', () {
      matcher.feed('g', normal);
      matcher.feed('t', normal); // completes 'gt'
      final conts = matcher.continuations(normal);
      final keys = conts.map((c) => c.key).toSet();
      expect(keys, equals({'g', 'j'}));
    });
  });

  // ---------------------------------------------------------------------------
  // Which-key timer
  // ---------------------------------------------------------------------------
  group('which-key timer', () {
    test('shouldShowWhichKey becomes true after delay', () {
      fakeAsync((async) {
        final matcher = KeyMatcher(
          {
            normal: {KeyChord.parse('gt'): 'next-tab'},
          },
          whichKeyDelay: const Duration(milliseconds: 50),
        );

        expect(matcher.shouldShowWhichKey, isFalse);
        matcher.feed('g', normal);
        expect(matcher.shouldShowWhichKey, isFalse);

        async.elapse(const Duration(milliseconds: 50));
        expect(matcher.shouldShowWhichKey, isTrue);

        matcher.dispose();
      });
    });

    test('onWhichKey callback fires after delay', () {
      fakeAsync((async) {
        var callbackFired = false;
        final matcher = KeyMatcher(
          {
            normal: {KeyChord.parse('gt'): 'next-tab'},
          },
          whichKeyDelay: const Duration(milliseconds: 50),
          onWhichKey: () => callbackFired = true,
        );

        matcher.feed('g', normal);
        expect(callbackFired, isFalse);

        async.elapse(const Duration(milliseconds: 50));
        expect(callbackFired, isTrue);

        matcher.dispose();
      });
    });

    test('resets on match completion', () {
      fakeAsync((async) {
        final matcher = KeyMatcher(
          {
            normal: {KeyChord.parse('gt'): 'next-tab'},
          },
          whichKeyDelay: const Duration(milliseconds: 50),
        );

        matcher.feed('g', normal);
        async.elapse(const Duration(milliseconds: 50));
        expect(matcher.shouldShowWhichKey, isTrue);

        matcher.feed('t', normal); // match found — resets
        expect(matcher.shouldShowWhichKey, isFalse);

        matcher.dispose();
      });
    });

    test('resets on explicit reset()', () {
      fakeAsync((async) {
        final matcher = KeyMatcher(
          {
            normal: {KeyChord.parse('gt'): 'next-tab'},
          },
          whichKeyDelay: const Duration(milliseconds: 50),
        );

        matcher.feed('g', normal);
        async.elapse(const Duration(milliseconds: 50));
        expect(matcher.shouldShowWhichKey, isTrue);

        matcher.reset();
        expect(matcher.shouldShowWhichKey, isFalse);

        matcher.dispose();
      });
    });

    test('does not fire on NoMatch', () {
      fakeAsync((async) {
        var callbackFired = false;
        final matcher = KeyMatcher(
          {
            normal: {KeyChord.parse('gt'): 'next-tab'},
          },
          whichKeyDelay: const Duration(milliseconds: 50),
          onWhichKey: () => callbackFired = true,
        );

        matcher.feed('z', normal); // NoMatch — no timer started
        async.elapse(const Duration(milliseconds: 100));
        expect(callbackFired, isFalse);
        expect(matcher.shouldShowWhichKey, isFalse);

        matcher.dispose();
      });
    });

    test('dispose cancels which-key timer', () {
      fakeAsync((async) {
        var callbackFired = false;
        final matcher = KeyMatcher(
          {
            normal: {KeyChord.parse('gt'): 'next-tab'},
          },
          whichKeyDelay: const Duration(milliseconds: 50),
          onWhichKey: () => callbackFired = true,
        );

        matcher.feed('g', normal);
        matcher.dispose();

        async.elapse(const Duration(milliseconds: 100));
        expect(callbackFired, isFalse);
      });
    });
  });
}
