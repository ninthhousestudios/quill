import 'package:flutter_test/flutter_test.dart';

import 'package:quill_keys/main.dart';

void main() {
  testWidgets('QuillDemoApp renders without error', (WidgetTester tester) async {
    await tester.pumpWidget(const QuillDemoApp());
    // Allow post-frame callbacks (QuillHint registration) to complete.
    await tester.pump();

    // App should be on screen — title in AppBar.
    expect(find.text('Quill Demo'), findsOneWidget);
  });

  testWidgets('QuillStatusBar shows NORMAL mode initially',
      (WidgetTester tester) async {
    await tester.pumpWidget(const QuillDemoApp());
    await tester.pump();

    // The status bar renders [NORMAL] text.
    expect(find.text('[NORMAL]'), findsOneWidget);
  });
}
