import 'dart:async';

/// Base sealed class for all Quill modes.
///
/// Apps can extend [QuillMode] to define custom modes beyond the three
/// built-in modes ([NormalMode], [InsertMode], [HintMode]).
sealed class QuillMode {
  const QuillMode();

  /// Human-readable name for this mode, shown in the status bar.
  String get name;
}

/// The default resting mode. Key bindings are active.
final class NormalMode extends QuillMode {
  const NormalMode();

  @override
  String get name => 'NORMAL';
}

/// Text input is focused. Key events pass through to the focused widget.
final class InsertMode extends QuillMode {
  const InsertMode();

  @override
  String get name => 'INSERT';
}

/// Hint labels are visible. Typing a label triggers the associated action.
final class HintMode extends QuillMode {
  const HintMode();

  @override
  String get name => 'HINT';
}

/// A stack of [QuillMode] values that tracks the current active mode.
///
/// The stack is never empty — it always contains at least [NormalMode] at
/// the bottom. Pushing a mode transitions into it; popping returns to the
/// previous mode. When only one mode remains, [pop] is a no-op (returns
/// the current mode without removing it).
///
/// Mode transitions are broadcast on [onModeChanged]. Call [dispose] when
/// the stack is no longer needed to close the stream.
class ModeStack {
  final List<QuillMode> _stack = [const NormalMode()];
  // Use a synchronous broadcast controller so listeners fire immediately
  // when push/pop/reset is called. This allows QuillController to call
  // notifyListeners() synchronously, keeping Flutter's build/notify pipeline
  // in a predictable single-frame order.
  final StreamController<QuillMode> _controller =
      StreamController<QuillMode>.broadcast(sync: true);

  /// The currently active mode (top of stack).
  QuillMode get current => _stack.last;

  /// Push [mode] onto the stack, making it the active mode.
  ///
  /// Emits the new mode on [onModeChanged].
  void push(QuillMode mode) {
    _stack.add(mode);
    _controller.add(current);
  }

  /// Pop the top mode from the stack and return it.
  ///
  /// If only one mode remains, the stack is left unchanged and the current
  /// mode is returned without emitting on [onModeChanged].
  QuillMode pop() {
    if (_stack.length <= 1) {
      return current;
    }
    final removed = _stack.removeLast();
    _controller.add(current);
    return removed;
  }

  /// Reset the stack to its initial state: a single [NormalMode].
  ///
  /// Emits [NormalMode] on [onModeChanged].
  void reset() {
    _stack
      ..clear()
      ..add(const NormalMode());
    _controller.add(current);
  }

  /// Broadcast stream that emits the new [QuillMode] on every transition.
  Stream<QuillMode> get onModeChanged => _controller.stream;

  /// Close the stream controller. Call this when the stack is no longer needed.
  void dispose() {
    _controller.close();
  }
}
