import 'package:flutter/widgets.dart';

import 'quill_scope.dart';

/// Wraps a child widget and registers it as a target in the Quill hint system.
///
/// When [HintMode] is active, [HintOverlay] assigns this widget a typed label.
/// Typing that label invokes [onHint] (if provided) or looks up [actionName]
/// in the [QuillController]'s [ActionRegistry].
///
/// Place [HintOverlay] somewhere above this widget in the tree (e.g. wrapping
/// the same subtree as [QuillScope]) so the overlay can read each hint widget's
/// position.
///
/// Example:
/// ```dart
/// QuillHint(
///   actionName: 'open-file',
///   child: ElevatedButton(onPressed: _openFile, child: Text('Open')),
/// )
/// ```
class QuillHint extends StatefulWidget {
  const QuillHint({
    super.key,
    required this.actionName,
    this.onHint,
    required this.child,
  });

  /// Name of the action to invoke (looked up in [ActionRegistry]) when this
  /// hint's label is fully typed. Ignored if [onHint] is also provided.
  final String actionName;

  /// Optional direct callback. Takes precedence over [actionName].
  final VoidCallback? onHint;

  final Widget child;

  @override
  State<QuillHint> createState() => _QuillHintState();
}

class _QuillHintState extends State<QuillHint> {
  final GlobalKey _childKey = GlobalKey();
  late HintEntry _entry;

  // Hold a direct reference to the controller so we can safely call
  // unregisterHint in dispose() without touching context.
  QuillController? _controller;

  @override
  void initState() {
    super.initState();
    _entry = HintEntry(
      key: _childKey,
      actionName: widget.actionName,
      onHint: widget.onHint,
    );
    // Register after the first frame so the controller is available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller = QuillScope.of(context);
        _controller!.registerHint(_entry);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cache the controller reference on every dependency change so it is
    // available safely in dispose().
    _controller = QuillScope.of(context);
  }

  @override
  void dispose() {
    // Use the cached reference — context is no longer valid here.
    _controller?.unregisterHint(_entry);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _childKey, child: widget.child);
  }
}
