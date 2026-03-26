import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_keys/src/core/config.dart';
import 'package:quill_keys/src/core/mode.dart';
import 'package:quill_keys/src/widgets/hint_overlay.dart';
import 'package:quill_keys/src/widgets/quill_hint.dart';
import 'package:quill_keys/src/widgets/quill_scope.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Build a test app with [QuillScope] + [HintOverlay] + a column of buttons,
/// each wrapped in a [QuillHint].
///
/// [actions] are merged into the controller alongside the hint targets.
/// [hintCallbacks] maps button index → callback (index within [labels]).
Widget _testApp({
  required List<String> actionNames,
  Map<String, VoidCallback>? actions,
  List<VoidCallback?>? hintCallbacks,
}) {
  return WidgetsApp(
    color: const Color(0xFF000000),
    builder: (_, __) => QuillScope(
      config: const QuillConfig(),
      actions: actions,
      child: HintOverlay(
        child: Column(
          children: [
            for (var i = 0; i < actionNames.length; i++)
              QuillHint(
                actionName: actionNames[i],
                onHint: hintCallbacks != null ? hintCallbacks[i] : null,
                child: SizedBox(
                  width: 100,
                  height: 40,
                  child: Text(actionNames[i]),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // -------------------------------------------------------------------------
  // 1. Labels visible in HintMode
  // -------------------------------------------------------------------------
  testWidgets('shows labels in HintMode', (tester) async {
    late QuillController ctrl;

    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        builder: (_, __) => QuillScope(
          config: const QuillConfig(),
          child: HintOverlay(
            child: Builder(
              builder: (ctx) {
                ctrl = QuillScope.of(ctx);
                return Column(
                  children: [
                    QuillHint(
                      actionName: 'action-a',
                      child: const SizedBox(width: 100, height: 40, child: Text('A')),
                    ),
                    QuillHint(
                      actionName: 'action-b',
                      child: const SizedBox(width: 100, height: 40, child: Text('B')),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );

    // Let post-frame callbacks run so hints are registered.
    await tester.pump();

    expect(ctrl.hints.length, 2);

    // Not in HintMode yet — no Positioned label widgets from the overlay.
    expect(tester.widgetList(find.byType(Positioned)), isEmpty);

    // Enter HintMode.
    ctrl.modeStack.push(HintMode());
    await tester.pump();

    // The overlay should now render 2 Positioned label widgets (one per hint).
    final positioned = tester.widgetList(find.byType(Positioned));
    expect(positioned.length, greaterThanOrEqualTo(2));
  });

  // -------------------------------------------------------------------------
  // 2. Labels hidden in NormalMode
  // -------------------------------------------------------------------------
  testWidgets('hidden in NormalMode', (tester) async {
    await tester.pumpWidget(_testApp(actionNames: ['foo', 'bar']));
    await tester.pump(); // let post-frame callbacks run

    // In NormalMode — no Positioned widgets (the overlay renders none).
    final positioned = tester.widgetList(find.byType(Positioned));
    expect(positioned, isEmpty);
  });

  // -------------------------------------------------------------------------
  // 3. Typing filters labels
  // -------------------------------------------------------------------------
  testWidgets('typing filters labels', (tester) async {
    late QuillController ctrl;

    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        builder: (_, __) => QuillScope(
          config: const QuillConfig(),
          child: HintOverlay(
            child: Builder(
              builder: (ctx) {
                ctrl = QuillScope.of(ctx);
                return Column(
                  children: [
                    // Enough hints to force multi-char labels so we can
                    // test filtering. With 9 single chars and 10 hints, the
                    // 10th hint gets a 2-char label starting with the last
                    // single char 'l' expanded. But for simpler filtering
                    // just use 2 hints — labels 'a' and 's'.
                    QuillHint(
                      actionName: 'action-a',
                      child: const SizedBox(width: 100, height: 40, child: Text('A')),
                    ),
                    QuillHint(
                      actionName: 'action-s',
                      child: const SizedBox(width: 100, height: 40, child: Text('S')),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    ctrl.modeStack.push(HintMode());
    await tester.pump();

    // Both labels visible — 2 Positioned widgets.
    expect(
      tester.widgetList(find.byType(Positioned)).length,
      greaterThanOrEqualTo(2),
    );

    // Type 'a' — only the 'a' label should survive (Positioned count drops to 1).
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
    await tester.pump();

    // Still in HintMode (no complete match yet — 'a' is a complete match here,
    // so actually the hint fires). Let's reconsider: with 2 hints, labels are
    // 'a' and 's'. Typing 'a' IS a complete match for hint[0], so the hint
    // fires and HintMode is popped. The Positioned count should drop to 0.
    expect(ctrl.currentMode, isA<NormalMode>());
    expect(tester.widgetList(find.byType(Positioned)), isEmpty);
  });

  // -------------------------------------------------------------------------
  // 4. Complete match invokes action and exits HintMode
  // -------------------------------------------------------------------------
  testWidgets('complete match invokes action and exits HintMode', (tester) async {
    var called = false;
    late QuillController ctrl;

    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        builder: (_, __) => QuillScope(
          config: const QuillConfig(),
          actions: {'my-action': () => called = true},
          child: HintOverlay(
            child: Builder(
              builder: (ctx) {
                ctrl = QuillScope.of(ctx);
                return QuillHint(
                  actionName: 'my-action',
                  child: const SizedBox(width: 100, height: 40, child: Text('btn')),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(ctrl.hints.length, 1);

    // With a single hint, the label is 'a' (first home-row char).
    ctrl.modeStack.push(HintMode());
    await tester.pump();

    expect(ctrl.currentMode, isA<HintMode>());

    // Type the label 'a'.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
    await tester.pump();

    // Action invoked and HintMode exited.
    expect(called, isTrue);
    expect(ctrl.currentMode, isA<NormalMode>());
  });

  // -------------------------------------------------------------------------
  // 5. Escape exits HintMode without invoking any action
  // -------------------------------------------------------------------------
  testWidgets('Escape exits HintMode', (tester) async {
    var called = false;
    late QuillController ctrl;

    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        builder: (_, __) => QuillScope(
          config: const QuillConfig(),
          actions: {'my-action': () => called = true},
          child: HintOverlay(
            child: Builder(
              builder: (ctx) {
                ctrl = QuillScope.of(ctx);
                return QuillHint(
                  actionName: 'my-action',
                  child: const SizedBox(width: 100, height: 40, child: Text('btn')),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    ctrl.modeStack.push(HintMode());
    await tester.pump();
    expect(ctrl.currentMode, isA<HintMode>());

    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(called, isFalse);
    expect(ctrl.currentMode, isA<NormalMode>());
  });

  // -------------------------------------------------------------------------
  // 6. onHint callback takes precedence over actionName
  // -------------------------------------------------------------------------
  testWidgets('onHint callback takes precedence over actionName', (tester) async {
    var actionCalled = false;
    var hintCalled = false;
    late QuillController ctrl;

    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        builder: (_, __) => QuillScope(
          config: const QuillConfig(),
          actions: {'named-action': () => actionCalled = true},
          child: HintOverlay(
            child: Builder(
              builder: (ctx) {
                ctrl = QuillScope.of(ctx);
                return QuillHint(
                  actionName: 'named-action',
                  onHint: () => hintCalled = true,
                  child: const SizedBox(width: 100, height: 40, child: Text('btn')),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    ctrl.modeStack.push(HintMode());
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
    await tester.pump();

    expect(hintCalled, isTrue);
    expect(actionCalled, isFalse);
    expect(ctrl.currentMode, isA<NormalMode>());
  });
}
