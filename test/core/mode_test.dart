import 'package:test/test.dart';
import 'package:quill_keys/src/core/mode.dart';

void main() {
  group('ModeStack', () {
    late ModeStack stack;

    setUp(() {
      stack = ModeStack();
    });

    tearDown(() {
      stack.dispose();
    });

    test('starts in Normal mode', () {
      expect(stack.current, isA<NormalMode>());
      expect(stack.current.name, equals('NORMAL'));
    });

    test('push and pop work correctly', () {
      stack.push(HintMode());
      expect(stack.current, isA<HintMode>());

      final popped = stack.pop();
      expect(popped, isA<HintMode>());
      expect(stack.current, isA<NormalMode>());
    });

    test('cannot pop last mode', () {
      // Only NormalMode on the stack.
      final result = stack.pop();
      expect(result, isA<NormalMode>());
      // Stack still has it — another pop still returns NormalMode.
      expect(stack.current, isA<NormalMode>());
      expect(stack.pop(), isA<NormalMode>());
    });

    test('reset clears to Normal', () {
      stack.push(InsertMode());
      stack.push(HintMode());
      stack.push(InsertMode());

      stack.reset();

      expect(stack.current, isA<NormalMode>());
      // After reset, pop should also stay on NormalMode (stack depth is 1).
      stack.pop();
      expect(stack.current, isA<NormalMode>());
    });

    test('stream emits on mode changes', () async {
      final emissions = <QuillMode>[];
      final subscription = stack.onModeChanged.listen(emissions.add);

      stack.push(InsertMode());
      stack.push(HintMode());
      stack.pop(); // back to InsertMode
      stack.reset(); // back to NormalMode

      // Allow microtasks to flush.
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(emissions.length, equals(4));
      expect(emissions[0], isA<InsertMode>());
      expect(emissions[1], isA<HintMode>());
      expect(emissions[2], isA<InsertMode>());
      expect(emissions[3], isA<NormalMode>());
    });
  });
}
