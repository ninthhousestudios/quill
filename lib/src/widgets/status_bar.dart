import 'package:flutter/widgets.dart';

import 'quill_scope.dart';

/// A minimal status bar widget that displays the current Quill mode and any
/// partial chord in progress.
///
/// Reads state from the nearest [QuillScope] ancestor and rebuilds whenever
/// the [QuillController] notifies (mode change, partial chord update, timeout).
///
/// Layout: mode name on the left, partial chord on the right. The chord
/// section is omitted entirely when no chord is in progress.
///
/// Styling is fully optional — sensible defaults are applied (bold mode name,
/// monospace chord text). Wrap this widget in whatever container/decoration
/// suits your UI.
class QuillStatusBar extends StatelessWidget {
  const QuillStatusBar({
    super.key,
    this.modeStyle,
    this.chordStyle,
  });

  /// Style for the `[MODE_NAME]` text. Defaults to bold.
  final TextStyle? modeStyle;

  /// Style for the partial chord text. Defaults to monospace.
  final TextStyle? chordStyle;

  static const TextStyle _defaultModeStyle = TextStyle(
    fontWeight: FontWeight.bold,
    inherit: true,
  );

  static const TextStyle _defaultChordStyle = TextStyle(
    fontFamily: 'monospace',
    inherit: true,
  );

  @override
  Widget build(BuildContext context) {
    final controller = QuillScope.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final modeName = controller.currentMode.name;
        final chord = controller.partialChord;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '[$modeName]',
              style: modeStyle ?? _defaultModeStyle,
            ),
            if (chord.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                chord,
                style: chordStyle ?? _defaultChordStyle,
              ),
            ],
          ],
        );
      },
    );
  }
}
