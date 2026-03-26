import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/action_registry.dart';
import '../core/config.dart';
import '../core/hint_labels.dart';
import '../core/key_matcher.dart';
import '../core/mode.dart';

// ---------------------------------------------------------------------------
// HintEntry
// ---------------------------------------------------------------------------

/// A registration record for a [QuillHint] widget.
///
/// Holds the key used to find the widget's render box and the action (or
/// direct callback) to invoke when the hint's label is typed.
class HintEntry {
  final GlobalKey key;
  final String actionName;
  final VoidCallback? onHint;

  HintEntry({
    required this.key,
    required this.actionName,
    this.onHint,
  });
}

// ---------------------------------------------------------------------------
// QuillController
// ---------------------------------------------------------------------------

/// Owns the mode stack, key matcher, and action registry for a [QuillScope].
///
/// Extend or wrap this to add custom behaviour. Notifies listeners on every
/// mode change, partial chord update, and chord timeout.
class QuillController extends ChangeNotifier {
  final ModeStack modeStack;
  final KeyMatcher keyMatcher;
  final ActionRegistry actionRegistry;
  final QuillConfig config;

  final List<HintEntry> _hints = [];

  /// All currently registered hint entries (unmodifiable view).
  List<HintEntry> get hints => List.unmodifiable(_hints);

  /// Register a [HintEntry]. Called by [QuillHint] on initState.
  void registerHint(HintEntry entry) {
    _hints.add(entry);
    notifyListeners();
  }

  /// Unregister a [HintEntry]. Called by [QuillHint] on dispose.
  ///
  /// Does NOT call [notifyListeners] because this runs during widget teardown
  /// when the tree may be locked. The hint is leaving — no rebuild needed.
  void unregisterHint(HintEntry entry) {
    _hints.remove(entry);
  }

  /// Generate labels for the current hint list using [config.hintChars].
  List<String> generateHintLabels() {
    final generator = HintLabelGenerator(chars: config.hintChars);
    return generator.generate(_hints.length);
  }

  QuillController({
    required this.config,
    Map<String, void Function()>? actions,
  })  : modeStack = ModeStack(),
        keyMatcher = KeyMatcher(config.bindings),
        actionRegistry = ActionRegistry() {
    keyMatcher.chordTimeout = config.chordTimeout;
    keyMatcher.onTimeout = notifyListeners;

    // Notify UI when mode changes.
    modeStack.onModeChanged.listen((_) => notifyListeners());

    // Built-in actions always available.
    actionRegistry.register('normal-mode', modeStack.reset);
    actionRegistry.register('hint-activate', () => modeStack.push(HintMode()));

    if (actions != null) {
      actionRegistry.registerAll(actions);
    }
  }

  /// The keys fed so far in the current partial chord (empty if none).
  String get partialChord => keyMatcher.partialChord;

  /// The currently active mode.
  QuillMode get currentMode => modeStack.current;

  /// Push [InsertMode] onto the mode stack.
  void enterInsertMode() => modeStack.push(InsertMode());

  /// Pop the current mode; if it is [InsertMode], return to the previous mode.
  void exitInsertMode() {
    if (modeStack.current is InsertMode) {
      modeStack.pop();
    }
  }

  /// The core key-event dispatcher. Feed this to a [Focus.onKeyEvent] handler.
  ///
  /// Only [KeyDownEvent]s are processed. Key-up and key-repeat events are
  /// passed through as [KeyEventResult.ignored].
  KeyEventResult handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = _keyString(event);
    if (key == null) return KeyEventResult.ignored;

    final result = keyMatcher.feed(key, modeStack.current);

    switch (result) {
      case MatchFound(:final actionName):
        actionRegistry.invoke(actionName);
        notifyListeners();
        return KeyEventResult.handled;
      case PartialMatch():
        notifyListeners();
        return KeyEventResult.handled;
      case NoMatch():
        // In insert mode, unmatched keys pass through to text fields.
        // Matched keys (above) still fire — e.g. Escape → normal-mode.
        return KeyEventResult.ignored;
    }
  }

  /// Convert a [KeyEvent] to the string identifier the trie expects.
  ///
  /// Returns `null` for keys we don't know how to represent (e.g. lone
  /// modifier keys).
  String? _keyString(KeyEvent event) {
    final logical = event.logicalKey;

    // Lone modifier keys produce no binding token.
    if (_isModifierKey(logical)) return null;

    // Detect held modifiers via HardwareKeyboard.
    final hw = HardwareKeyboard.instance;
    final ctrlHeld =
        hw.isControlPressed || hw.isMetaPressed; // treat Meta like Ctrl on mac
    final shiftHeld = hw.isShiftPressed;
    final altHeld = hw.isAltPressed;

    // Map well-known special keys to their named identifiers.
    final special = _specialKeyName(logical);
    if (special != null) {
      // Build modifier-prefixed token list if needed.
      if (ctrlHeld) return null; // Ctrl+special not yet in bindings — ignore.
      return special;
    }

    // Printable character — keyLabel gives e.g. "J", lower-case it.
    final label = logical.keyLabel;
    if (label.isEmpty) return null;

    // Multi-character labels (e.g. "F1", "Numpad 1") — not single keys.
    // We do handle them as their label for future bindings, but only single
    // characters are in the current chord alphabet.
    if (ctrlHeld && label.length == 1) {
      // Ctrl+letter: emit two trie tokens ['Control', 'x']
      // KeyMatcher.feed takes one token at a time, so we feed 'Control' first.
      // However feed() is designed for single tokens per call; modifier combos
      // like <C-x> are stored as consecutive trie nodes ['Control', 'x'].
      // We therefore feed 'Control' and then the letter in sequence.
      final letterResult = keyMatcher.feed('Control', modeStack.current);
      if (letterResult is NoMatch) return null; // no ctrl binding — bail
      // Now feed the letter (the caller will do the second feed via our return).
      // Actually, we need to return the letter here so handleKeyEvent feeds it.
      // But we already consumed the 'Control' node — just return the letter.
      return label.toLowerCase();
    }

    if (altHeld && label.length == 1) {
      final _ = keyMatcher.feed('Alt', modeStack.current);
      return label.toLowerCase();
    }

    if (shiftHeld && label.length == 1) {
      // Uppercase letter — return as-is. In TOML, "H" means Shift+h.
      // The <S-a> syntax feeds ['Shift', 'a'] as two tokens, but bare
      // uppercase letters like H, J, K, L, D, G are single trie nodes.
      return label; // already uppercase from keyLabel
    }

    // Plain printable character.
    if (label.length == 1) return label.toLowerCase();

    // Multi-char label without modifier — return as-is (e.g. "F1").
    return label;
  }

  static bool _isModifierKey(LogicalKeyboardKey key) {
    // ignore: prefer_const_literals_to_create_immutables
    final modifiers = <LogicalKeyboardKey>{
      LogicalKeyboardKey.shift,
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.shiftRight,
      LogicalKeyboardKey.control,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.controlRight,
      LogicalKeyboardKey.alt,
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.altRight,
      LogicalKeyboardKey.meta,
      LogicalKeyboardKey.metaLeft,
      LogicalKeyboardKey.metaRight,
      LogicalKeyboardKey.capsLock,
    };
    return modifiers.contains(key);
  }

  static String? _specialKeyName(LogicalKeyboardKey key) {
    // ignore: prefer_const_literals_to_create_immutables
    final map = <LogicalKeyboardKey, String>{
      LogicalKeyboardKey.escape: 'Escape',
      LogicalKeyboardKey.enter: 'Return',
      LogicalKeyboardKey.numpadEnter: 'Return',
      LogicalKeyboardKey.tab: 'Tab',
      LogicalKeyboardKey.space: 'Space',
      LogicalKeyboardKey.backspace: 'Backspace',
      LogicalKeyboardKey.delete: 'Delete',
      LogicalKeyboardKey.arrowUp: 'Up',
      LogicalKeyboardKey.arrowDown: 'Down',
      LogicalKeyboardKey.arrowLeft: 'Left',
      LogicalKeyboardKey.arrowRight: 'Right',
      LogicalKeyboardKey.home: 'Home',
      LogicalKeyboardKey.end: 'End',
      LogicalKeyboardKey.pageUp: 'PageUp',
      LogicalKeyboardKey.pageDown: 'PageDown',
    };
    return map[key];
  }

  /// Register a single named action.
  void registerAction(String name, void Function() callback) {
    actionRegistry.register(name, callback);
  }

  /// Bulk-register a map of name → callback pairs.
  void registerActions(Map<String, void Function()> actions) {
    actionRegistry.registerAll(actions);
  }

  @override
  void dispose() {
    modeStack.dispose();
    keyMatcher.dispose();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// _QuillInherited
// ---------------------------------------------------------------------------

class _QuillInherited extends InheritedNotifier<QuillController> {
  const _QuillInherited({
    required QuillController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Always return true so that descendants are notified on every
  /// [QuillController.notifyListeners] call, not just when the controller
  /// identity changes.
  @override
  bool updateShouldNotify(_QuillInherited oldWidget) => true;
}

// ---------------------------------------------------------------------------
// QuillScope
// ---------------------------------------------------------------------------

/// Top-level widget that owns a [QuillController] and intercepts key events.
///
/// Wrap your application (or a subtree) with [QuillScope]. Descendants can
/// retrieve the controller via [QuillScope.of].
///
/// The widget auto-detects text-field focus via [FocusManager] and pushes
/// [InsertMode] when a text field becomes primary focus, popping it when the
/// field loses focus.
class QuillScope extends StatefulWidget {
  const QuillScope({
    super.key,
    required this.config,
    this.actions,
    required this.child,
  });

  final QuillConfig config;
  final Map<String, void Function()>? actions;
  final Widget child;

  /// Look up the nearest [QuillController] in the widget tree.
  ///
  /// Throws a [FlutterError] if no [QuillScope] ancestor is found.
  static QuillController of(BuildContext context) {
    final inherited =
        context.dependOnInheritedWidgetOfExactType<_QuillInherited>();
    if (inherited == null) {
      throw FlutterError(
        'QuillScope.of() called with a context that does not contain a '
        'QuillScope.\n'
        'Make sure your widget tree includes a QuillScope ancestor.',
      );
    }
    return inherited.notifier!;
  }

  @override
  State<QuillScope> createState() => _QuillScopeState();
}

class _QuillScopeState extends State<QuillScope> {
  late QuillController _controller;
  final FocusNode _focusNode = FocusNode(debugLabel: 'QuillScope');
  QuillMode _previousMode = const NormalMode();

  @override
  void initState() {
    super.initState();
    _controller = QuillController(
      config: widget.config,
      actions: widget.actions,
    );
    // Rebuild whenever the controller notifies so that _QuillInherited is
    // given a new widget — this triggers InheritedElement.update() →
    // notifyClients() → all dependents rebuild.
    _controller.addListener(_onControllerChange);
    // Listen to FocusManager so we can auto-enter/exit InsertMode when a
    // text field gains or loses focus.
    FocusManager.instance.addListener(_onFocusChange);
  }

  void _onControllerChange() {
    if (!mounted) return;
    // When leaving InsertMode, reclaim focus from the text field so that
    // subsequent keypresses route through QuillScope, not the field.
    final current = _controller.currentMode;
    if (_previousMode is InsertMode && current is! InsertMode) {
      _focusNode.requestFocus();
    }
    _previousMode = current;
    setState(() {});
  }

  void _onFocusChange() {
    final primary = FocusManager.instance.primaryFocus;

    if (primary == null) {
      // Nothing focused — if we were in insert mode, pop back.
      if (_controller.currentMode is InsertMode) {
        _controller.exitInsertMode();
      }
      return;
    }

    // Walk up from the focused node's context to see if it's inside an
    // EditableText (i.e. a text input field).
    final focusContext = primary.context;
    if (focusContext == null) return;

    bool inTextField = false;
    focusContext.visitAncestorElements((element) {
      if (element.widget is EditableText) {
        inTextField = true;
        return false; // stop walking
      }
      return true;
    });

    if (inTextField && _controller.currentMode is! InsertMode) {
      _controller.enterInsertMode();
    } else if (!inTextField && _controller.currentMode is InsertMode) {
      _controller.exitInsertMode();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChange);
    FocusManager.instance.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _QuillInherited(
      controller: _controller,
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (_, event) => _controller.handleKeyEvent(event),
        child: widget.child,
      ),
    );
  }
}
