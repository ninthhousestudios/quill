import 'package:test/test.dart';
import 'package:quill_keys/src/core/action_registry.dart';

void main() {
  group('ActionRegistry', () {
    late ActionRegistry registry;

    setUp(() {
      registry = ActionRegistry();
    });

    test('register and invoke', () {
      var count = 0;
      registry.register('increment', () => count++);

      final result = registry.invoke('increment');

      expect(result, isTrue);
      expect(count, equals(1));

      registry.invoke('increment');
      expect(count, equals(2));
    });

    test('invoke unknown returns false', () {
      final result = registry.invoke('nonexistent');
      expect(result, isFalse);
    });

    test('unregister removes action', () {
      var count = 0;
      registry.register('action', () => count++);

      registry.unregister('action');

      final result = registry.invoke('action');
      expect(result, isFalse);
      expect(count, equals(0));
    });

    test('registerAll works', () {
      var aCount = 0;
      var bCount = 0;
      var cCount = 0;

      registry.registerAll({
        'alpha': () => aCount++,
        'beta': () => bCount++,
        'gamma': () => cCount++,
      });

      expect(registry.invoke('alpha'), isTrue);
      expect(registry.invoke('beta'), isTrue);
      expect(registry.invoke('gamma'), isTrue);

      expect(aCount, equals(1));
      expect(bCount, equals(1));
      expect(cCount, equals(1));
    });

    test('register throws on duplicate name', () {
      registry.register('dup', () {});
      expect(() => registry.register('dup', () {}), throwsArgumentError);
    });

    test('has returns correct values', () {
      registry.register('present', () {});
      expect(registry.has('present'), isTrue);
      expect(registry.has('absent'), isFalse);
    });

    test('registeredNames reflects current state', () {
      registry.register('x', () {});
      registry.register('y', () {});
      expect(registry.registeredNames, containsAll(['x', 'y']));

      registry.unregister('x');
      expect(registry.registeredNames, isNot(contains('x')));
      expect(registry.registeredNames, contains('y'));
    });
  });
}
