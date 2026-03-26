import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_keys/src/core/config.dart';
import 'package:quill_keys/src/core/key_matcher.dart';
import 'package:quill_keys/src/core/mode.dart';
import 'package:quill_keys/src/widgets/quill_scope.dart';
import 'package:quill_keys/src/widgets/status_bar.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

QuillConfig configWith(Map<String, String> normal) {
  final modeBindings = normal.map(
    (k, v) => MapEntry(KeyChord.parse(k), v),
  );
  return QuillConfig(
    bindings: {const NormalMode(): modeBindings},
  );
}

/// Wraps [child] in a WidgetsApp + QuillScope with [config] and optional
/// [actions]. Captures the [QuillController] into [controllerOut] if provided.
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
  TestWidgetsFlutterBinding.ensureInitialized();

  // -------------------------------------------------------------------------
  // 1. Shows current mode
  // -------------------------------------------------------------------------
  testWidgets('shows current mode', (tester) async {
    await tester.pumpWidget(
      scopeWidget(
        config: const QuillConfig(),
        child: const QuillStatusBar(),
      ),
    );

    expect(find.text('[NORMAL]'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 2. Shows partial chord after first key of a chord binding
  // -------------------------------------------------------------------------
  testWidgets('shows partial chord', (tester) async {
    await tester.pumpWidget(
      scopeWidget(
        config: configWith({'gt': 'some-action'}),
        actions: {'some-action': () {}},
        child: const QuillStatusBar(),
      ),
    );

    // Before any key: no chord text.
    expect(find.text('g'), findsNothing);

    // Send the first key of the two-key chord — produces a PartialMatch.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyG);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyG);
    await tester.pump();

    // Status bar should now show the partial chord 'g'.
    expect(find.text('g'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 3. Updates on mode change (push InsertMode)
  // -------------------------------------------------------------------------
  testWidgets('updates on mode change', (tester) async {
    late QuillController controller;

    await tester.pumpWidget(
      scopeWidget(
        config: const QuillConfig(),
        child: Builder(
          builder: (context) {
            controller = QuillScope.of(context);
            return const QuillStatusBar();
          },
        ),
      ),
    );

    // Initial state is NORMAL.
    expect(find.text('[NORMAL]'), findsOneWidget);
    expect(find.text('[INSERT]'), findsNothing);

    // Push InsertMode onto the stack.
    controller.modeStack.push(InsertMode());
    await tester.pump();

    expect(find.text('[INSERT]'), findsOneWidget);
    expect(find.text('[NORMAL]'), findsNothing);
  });
}
