import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/mode.dart';
import 'quill_scope.dart';

/// Renders floating hint labels over registered [QuillHint] widgets whenever
/// the controller is in [HintMode].
///
/// Place this widget somewhere in the subtree below [QuillScope] — ideally
/// wrapping the entire interactive content so it can measure positions
/// relative to its own coordinate space. A common pattern:
///
/// ```dart
/// QuillScope(
///   config: config,
///   child: HintOverlay(
///     child: Scaffold(...),
///   ),
/// )
/// ```
///
/// The overlay intercepts keyboard input while in [HintMode]:
/// - Printable characters narrow the candidate set.
/// - Backspace removes the last typed character.
/// - Escape exits [HintMode] without invoking any action.
/// - A full label match invokes the associated action and exits [HintMode].
class HintOverlay extends StatefulWidget {
  const HintOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<HintOverlay> createState() => _HintOverlayState();
}

class _HintOverlayState extends State<HintOverlay> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'HintOverlay');
  final GlobalKey _stackKey = GlobalKey();
  String _typed = '';

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final ctrl = QuillScope.of(context);
    if (ctrl.currentMode is! HintMode) return KeyEventResult.ignored;

    final logical = event.logicalKey;

    if (logical == LogicalKeyboardKey.escape) {
      _exit(ctrl);
      return KeyEventResult.handled;
    }

    if (logical == LogicalKeyboardKey.backspace) {
      if (_typed.isNotEmpty) {
        setState(() => _typed = _typed.substring(0, _typed.length - 1));
      }
      return KeyEventResult.handled;
    }

    // Printable single character.
    final label = logical.keyLabel;
    if (label.length == 1) {
      final next = _typed + label.toLowerCase();
      setState(() => _typed = next);
      _checkMatch(ctrl, next);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _checkMatch(QuillController ctrl, String typed) {
    final hints = ctrl.hints;
    final labels = ctrl.generateHintLabels();
    for (var i = 0; i < hints.length && i < labels.length; i++) {
      if (labels[i] == typed) {
        _invoke(ctrl, hints[i]);
        return;
      }
    }
  }

  void _invoke(QuillController ctrl, HintEntry entry) {
    _exit(ctrl);
    if (entry.onHint != null) {
      entry.onHint!();
    } else {
      ctrl.actionRegistry.invoke(entry.actionName);
    }
  }

  void _exit(QuillController ctrl) {
    setState(() => _typed = '');
    ctrl.modeStack.pop();
  }

  List<Widget> _buildLabels(QuillController ctrl) {
    final hints = ctrl.hints;
    final labels = ctrl.generateHintLabels();
    final result = <Widget>[];

    for (var i = 0; i < hints.length && i < labels.length; i++) {
      final entry = hints[i];
      final label = labels[i];
      if (!label.startsWith(_typed)) continue;

      // Position relative to the Stack.
      Offset localPos = Offset.zero;
      final renderBox =
          entry.key.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        final stackBox =
            _stackKey.currentContext?.findRenderObject() as RenderBox?;
        if (stackBox != null) {
          localPos =
              stackBox.globalToLocal(renderBox.localToGlobal(Offset.zero));
        }
      }

      result.add(
        Positioned(
          left: localPos.dx,
          top: localPos.dy,
          child: _HintLabel(
            label: label,
            typed: _typed,
            highlighted: _typed.isNotEmpty,
          ),
        ),
      );
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    // QuillScope.of registers a dependency on _QuillInherited, which notifies
    // on every QuillController.notifyListeners() call (updateShouldNotify
    // always returns true). This causes HintOverlay to rebuild on every mode
    // change, chord update, or hint registration.
    final ctrl = QuillScope.of(context);
    final inHintMode = ctrl.currentMode is HintMode;

    // Manage focus without post-frame callbacks — just sync the focus node
    // during the build. The FocusNode itself handles the actual focus change.
    if (inHintMode) {
      _focusNode.requestFocus();
    }

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _onKey,
      child: Stack(
        key: _stackKey,
        children: [
          widget.child,
          if (inHintMode) ..._buildLabels(ctrl),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _HintLabel
// ---------------------------------------------------------------------------

/// The small badge rendered over a hint widget.
///
/// Characters already typed appear dimmer; the remaining suffix is bold.
class _HintLabel extends StatelessWidget {
  const _HintLabel({
    required this.label,
    required this.typed,
    required this.highlighted,
  });

  final String label;
  final String typed;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final typedPart = label.substring(0, typed.length);
    final remainPart = label.substring(typed.length);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: highlighted
            ? const Color(0xFFFFD700) // gold when filtering
            : const Color(0xFFFFFF00), // bright yellow at rest
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: const Color(0xFF888800), width: 1),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            if (typedPart.isNotEmpty)
              TextSpan(
                text: typedPart,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF888800),
                ),
              ),
            TextSpan(
              text: remainPart,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF222200),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
