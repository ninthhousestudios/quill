# quill_keys

Vim-style modal keybinding package for Flutter desktop apps. Modes, sequential key chords, hint overlays, and TOML configuration — modeled after [qutebrowser](https://qutebrowser.org/).

## Features

- **Modal input**: Normal, Insert, and Hint modes with a mode stack. Define custom modes by extending `QuillMode`.
- **Key chords**: Sequential multi-key bindings (`gt` for "next tab") via trie-based matching with configurable timeout.
- **Hint system**: qutebrowser-style hint labels over any widget. Home-row-first label generation, type a label to trigger its action.
- **TOML config**: Human-readable binding files. Overlay user config on app defaults. Use different files as "profiles".
- **Named actions**: All actions are strings. Bindings map chords to names; your app registers callbacks. Config and code stay decoupled.
- **Auto insert mode**: Quill detects when a `TextField` gains focus and switches to Insert mode automatically. Escape returns to Normal and releases focus from the field.
- **Status bar**: Drop-in widget showing current mode and partial chord in progress.

## Design Principle: Hint Everything

**Every clickable or interactive widget should be wrapped with `QuillHint`.** This is the core UX contract of a Quill-powered app: anything a mouse user can click, a keyboard user can reach via hints.

This includes buttons, tabs, text fields, icons, list items, cards — anything tappable. For text fields specifically, use the `onHint` callback to request focus, which auto-triggers Insert mode:

```dart
QuillHint(
  actionName: 'focus-search',
  onHint: () => _searchFocusNode.requestFocus(),
  child: TextField(focusNode: _searchFocusNode, ...),
)
```

Quill provides the mechanism; your app wraps the widgets. The demo app (`lib/main.dart`) models this exhaustively as a reference.

## Quick Start

```dart
import 'package:quill_keys/quill.dart';

const tomlConfig = '''
[settings]
chord_timeout_ms = 1500
hint_chars = "asdfghjkl"

[normal]
j = "scroll-down"
k = "scroll-up"
f = "hint-activate"
gt = "next-tab"
gg = "scroll-top"
G = "scroll-bottom"

[insert]
"<Escape>" = "normal-mode"
''';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: QuillScope(
        config: QuillConfig.fromToml(tomlConfig),
        actions: {
          'scroll-down': () => print('down'),
          'scroll-up': () => print('up'),
          'next-tab': () => print('next tab'),
        },
        child: HintOverlay(
          child: Scaffold(
            body: Column(
              children: [
                QuillHint(
                  actionName: 'scroll-down',
                  child: ElevatedButton(
                    onPressed: () {},
                    child: Text('Scroll Down'),
                  ),
                ),
                // ... wrap every clickable widget with QuillHint
              ],
            ),
            bottomNavigationBar: QuillStatusBar(),
          ),
        ),
      ),
    );
  }
}
```

## TOML Config Format

```toml
[settings]
chord_timeout_ms = 1500       # Timeout for multi-key chords (ms)
hint_chars = "asdfghjkl"       # Characters used for hint labels (home row)

[normal]
j = "scroll-down"              # Single key binding
k = "scroll-up"
gt = "next-tab"                # Two-key chord
gg = "scroll-top"              # Repeated-key chord
G = "scroll-bottom"            # Shift+key (uppercase)
f = "hint-activate"            # Built-in: enters Hint mode
"<C-x>" = "close-tab"         # Ctrl+X
"<Escape>" = "normal-mode"     # Built-in: resets to Normal mode

[insert]
"<Escape>" = "normal-mode"
"<A-i>" = "normal-mode"        # Alt+I as alternative

[hint]
"<Escape>" = "normal-mode"
```

### Key syntax

| Syntax | Meaning |
|--------|---------|
| `j` | Single key |
| `gt` | Sequential chord: g then t |
| `gg` | Repeated key chord |
| `G` | Shift+G (uppercase = shifted) |
| `"<Escape>"` | Named special key |
| `"<C-x>"` | Ctrl+X |
| `"<S-a>"` | Shift+A |
| `"<A-x>"` | Alt+X |

### Profiles

Profiles are just different TOML files. Two are built in:

```dart
final config = QuillConfig.fromToml(qutebrowserProfileToml);
// or
final config = QuillConfig.fromToml(vimProfileToml);
```

Overlay user customizations on top of defaults:

```dart
final merged = defaultConfig.merge(userConfig);
```

## Modes

| Mode | Behavior |
|------|----------|
| **Normal** | Key bindings are active. Default resting state. |
| **Insert** | Keys pass through to the focused text field. Auto-activated on `TextField` focus. Escape exits and releases focus. |
| **Hint** | Labels appear over `QuillHint` widgets. Type a label to trigger its action. |

The mode stack supports nesting — entering Hint from Normal, then canceling, returns to Normal.

## Widgets

### QuillScope

Top-level widget. Wraps your app and intercepts key events. When leaving Insert mode, it automatically reclaims focus from text fields so Normal-mode bindings work immediately.

```dart
QuillScope(
  config: QuillConfig.fromToml(toml),
  actions: { 'my-action': () => doThing() },
  child: MyApp(),
)
```

Access the controller from anywhere below:

```dart
final controller = QuillScope.of(context);
controller.registerAction('new-action', () => doOtherThing());
```

### QuillHint

Wraps a widget to make it a hint target. Use `actionName` to invoke a registered action, or `onHint` for a direct callback:

```dart
// Invoke a registered action
QuillHint(
  actionName: 'open-settings',
  child: IconButton(icon: Icon(Icons.settings), onPressed: openSettings),
)

// Direct callback (e.g. focusing a text field)
QuillHint(
  actionName: 'focus-search',
  onHint: () => searchFocus.requestFocus(),
  child: TextField(focusNode: searchFocus, ...),
)
```

### HintOverlay

Renders floating labels. Place it above your `QuillHint` widgets:

```dart
HintOverlay(
  child: Scaffold(
    body: Column(children: [
      QuillHint(actionName: 'a', child: ButtonA()),
      QuillHint(actionName: 'b', child: ButtonB()),
    ]),
  ),
)
```

### QuillStatusBar

Shows `[NORMAL]`, `[INSERT]`, `[HINT]` and partial chords:

```dart
QuillStatusBar(
  modeStyle: TextStyle(fontWeight: FontWeight.bold),
  chordStyle: TextStyle(fontFamily: 'monospace'),
)
```

## Architecture

Pure-Dart core with zero Flutter imports, Flutter widget layer on top. See [doc/architecture.md](doc/architecture.md) for the full design document.

```
lib/src/
  core/           # Pure Dart: mode stack, trie matcher, registry, config, labels
  widgets/        # Flutter: QuillScope, QuillHint, HintOverlay, QuillStatusBar
  defaults/       # Built-in profiles: qutebrowser, vim
```

## Testing

```bash
# Core unit tests (pure Dart, fast)
flutter test test/core/

# Widget tests
flutter test test/widgets/

# All tests
flutter test
```

## Limitations (v1)

- Global scope only (no per-widget binding scopes)
- No command mode or command palette
- No count prefixes (`5j`)
- No runtime rebinding
- Greedy matching: can't bind both `g` and `gt` simultaneously

## License

See [LICENSE](LICENSE).
