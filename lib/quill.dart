/// Quill — vim-style modal keybinding package for Flutter.
///
/// Import this barrel to access all public Quill APIs:
/// - [QuillScope] / [QuillController] — top-level scope widget and controller
/// - [QuillHint] — opt-in hint target wrapper
/// - [HintOverlay] — renders floating hint labels in HintMode
/// - [QuillStatusBar] — displays current mode + partial chord
/// - [QuillConfig] / [QuillConfig.fromToml] — configuration and TOML parser
/// - [QuillMode] / [NormalMode] / [InsertMode] / [HintMode] — mode types
/// - [ActionRegistry] — named action registration and invocation
/// - [KeyMatcher] — chord trie key matcher
/// - [HintLabelGenerator] — generates short unique hint labels
library;

export 'src/core/mode.dart';
export 'src/core/key_matcher.dart';
export 'src/core/action_registry.dart';
export 'src/core/config.dart';
export 'src/core/hint_labels.dart';
export 'src/widgets/quill_scope.dart';
export 'src/widgets/quill_hint.dart';
export 'src/widgets/hint_overlay.dart';
export 'src/widgets/status_bar.dart';
export 'src/defaults/qutebrowser_profile.dart';
export 'src/defaults/vim_profile.dart';
