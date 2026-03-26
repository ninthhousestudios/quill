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
}
