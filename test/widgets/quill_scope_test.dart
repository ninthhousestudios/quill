import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_keys/src/core/config.dart';
import 'package:quill_keys/src/core/key_matcher.dart';
import 'package:quill_keys/src/core/mode.dart';
import 'package:quill_keys/src/widgets/quill_scope.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Minimal config with mode-specific bindings.
QuillConfig configWith(Map<String, String> normal,
    {Map<String, String>? insert}) {
  final bindings = <QuillMode, Map<KeyChord, String>>{};
  bindings[const NormalMode()] =
      normal.map((k, v) => MapEntry(KeyChord.parse(k), v));
  if (insert != null) {
    bindings[const InsertMode()] =
        insert.map((k, v) => MapEntry(KeyChord.parse(k), v));
  }
  return QuillConfig(bindings: bindings);
}

/// Wrap [child] in a QuillScope with [config] and optional [actions].
Widget scopeWidget({
  required QuillConfig config,
  Map<String, void Function()>? actions,
  required Widget child,
}) {
  return WidgetsApp(
    color: const Color(0xFF000000),
    builder: (_, __) => QuillScope(
      config: config,
      actions: actions,
      child: child,
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // Make sure bindings framework is initialised before any test sends keys.
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------------------
  // 1. QuillScope provides controller to descendants
  // ---------------------------------------------------------------------------
  testWidgets('QuillScope provides controller to descendants', (tester) async {
    QuillController? found;

    await tester.pumpWidget(
      scopeWidget(
        config: const QuillConfig(),
        child: Builder(
          builder: (context) {
            found = QuillScope.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(found, isA<QuillController>());
  });

  // ---------------------------------------------------------------------------
  // 2. Key event dispatches to a registered action
  // ---------------------------------------------------------------------------
  testWidgets('key event dispatches to registered action', (tester) async {
    var called = false;

    await tester.pumpWidget(
      scopeWidget(
        config: configWith({'j': 'scroll-down'}),
        actions: {'scroll-down': () => called = true},
        child: const SizedBox(),
      ),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyJ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyJ);

    expect(called, isTrue);
  });

  // ---------------------------------------------------------------------------
  // 3. Chord dispatch works
  // ---------------------------------------------------------------------------
  testWidgets('chord dispatch works', (tester) async {
    var called = false;

    await tester.pumpWidget(
      scopeWidget(
        config: configWith({'gt': 'next-tab'}),
        actions: {'next-tab': () => called = true},
        child: const SizedBox(),
      ),
    );

    // First key — partial match.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyG);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyG);
    expect(called, isFalse);

    // Second key — complete match.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyT);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyT);
    expect(called, isTrue);
  });

  // ---------------------------------------------------------------------------
  // 4. Mode switch via action
  // ---------------------------------------------------------------------------
  testWidgets('mode switch via action', (tester) async {
    late QuillController controller;

    await tester.pumpWidget(
      scopeWidget(
        config: configWith({'i': 'enter-insert'}),
        actions: {},
        child: Builder(
          builder: (context) {
            controller = QuillScope.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    // Register after controller is captured.
    controller.registerAction(
      'enter-insert',
      () => controller.modeStack.push(InsertMode()),
    );

    expect(controller.currentMode, isA<NormalMode>());

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyI);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyI);

    expect(controller.currentMode, isA<InsertMode>());
  });

  // ---------------------------------------------------------------------------
  // 5. Escape in insert mode fires insert-mode binding and returns to normal
  // ---------------------------------------------------------------------------
  testWidgets('Escape returns to normal mode from insert mode', (tester) async {
    late QuillController controller;

    await tester.pumpWidget(
      scopeWidget(
        // Escape bound in BOTH modes — normal and insert.
        config: configWith(
          {'<Escape>': 'normal-mode'},
          insert: {'<Escape>': 'normal-mode'},
        ),
        child: Builder(
          builder: (context) {
            controller = QuillScope.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    // Push InsertMode.
    controller.modeStack.push(InsertMode());
    await tester.pump();
    expect(controller.currentMode, isA<InsertMode>());

    // Press Escape — should match the insert-mode binding and return to Normal.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);

    expect(controller.currentMode, isA<NormalMode>());
  });

  // ---------------------------------------------------------------------------
  // 6. Unbound keys in insert mode pass through
  // ---------------------------------------------------------------------------
  testWidgets('unbound keys in insert mode pass through', (tester) async {
    late QuillController controller;
    var actionCalled = false;

    await tester.pumpWidget(
      scopeWidget(
        config: configWith(
          {'j': 'scroll-down'},
          insert: {'<Escape>': 'normal-mode'},
        ),
        actions: {'scroll-down': () => actionCalled = true},
        child: Builder(
          builder: (context) {
            controller = QuillScope.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    // Push InsertMode.
    controller.modeStack.push(InsertMode());
    await tester.pump();

    // Press 'j' — bound in normal mode but NOT in insert mode.
    // Should pass through (not trigger scroll-down).
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyJ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyJ);

    expect(actionCalled, isFalse);
    expect(controller.currentMode, isA<InsertMode>());
  });
}
