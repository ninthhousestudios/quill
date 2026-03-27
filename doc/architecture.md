# Quill Architecture

## Overview

Quill (`quill_keys`) is a vim-style modal keybinding package for Flutter desktop applications. It provides modes, sequential key chords, a hint overlay system, and TOML-based configuration — modeled after qutebrowser's keyboard system.

The package is structured as a single pub package with a clean internal boundary: pure-Dart core logic with zero Flutter imports, and a Flutter widget layer on top.

```
lib/
  quill.dart                    # barrel export
  src/
    core/                       # pure Dart — no Flutter imports
      mode.dart                 # QuillMode, ModeStack
      key_matcher.dart          # KeyChord, KeyMatcher (trie), KeyMatchResult, ChordContinuation
      action_registry.dart      # ActionRegistry
      config.dart               # QuillConfig, TOML parsing
      hint_labels.dart          # HintLabelGenerator
    widgets/                    # Flutter layer
      quill_scope.dart          # QuillController, QuillScope, HintEntry
      quill_hint.dart           # QuillHint wrapper widget
      hint_overlay.dart         # HintOverlay
      status_bar.dart           # QuillStatusBar
```

## Design Principles

1. **Core is pure Dart.** Everything in `src/core/` uses only `dart:async` and `dart:collection`. No Flutter SDK imports. This means core logic can be tested with plain `dart test` — no widget harness needed.

2. **Global scope only.** Quill intercepts key events at a single top-level `Focus` widget. There is no per-screen or per-widget binding scope. This is a deliberate v1 simplification.

3. **Named actions.** All actions are referenced by string name (`"scroll-down"`, `"hint-activate"`). Bindings map key chords to action names; the app registers callbacks under those names. This decouples binding configuration from implementation.

4. **Configuration as data.** Bindings are defined in TOML files, not Dart code. The app provides defaults; users can overlay their own TOML file. Different TOML files serve as "profiles" (e.g. qutebrowser-style vs vim-style).

## Key Interception Pipeline

Quill sits between the platform's key delivery and Flutter's focus system:

```
Window Manager (Hyprland, Sway, etc.)
  │  ← WM grabs consumed here; Flutter never sees them
  ▼
Platform Embedding (GTK / Wayland)
  │  ← converts to Flutter KeyEvent
  ▼
QuillScope (Focus widget, autofocus: true)
  │  ← QuillController.handleKeyEvent()
  │     ├─ KeyDownEvent only (ignores KeyUp, KeyRepeat)
  │     ├─ Converts LogicalKeyboardKey → string token
  │     ├─ In InsertMode: passes through (KeyEventResult.ignored)
  │     ├─ In HintMode: delegates to HintOverlay's FocusNode
  │     └─ Otherwise: feeds token into KeyMatcher
  │         ├─ MatchFound → ActionRegistry.invoke(name)
  │         ├─ PartialMatch → start/restart chord timer
  │         └─ NoMatch → KeyEventResult.ignored
  ▼
Child widget tree (receives unhandled events)
```

### Insert Mode Pass-Through

When the mode stack's current mode is `InsertMode`, `handleKeyEvent` returns `KeyEventResult.ignored` for all keys, allowing them to reach text input widgets normally. This is how typing in `TextField`s works — Quill gets out of the way.

### Auto Insert Mode Detection

`QuillScope` listens to `FocusManager.instance` for focus changes. When primary focus moves to a node whose ancestor tree contains an `EditableText` widget, Quill automatically pushes `InsertMode`. When that focus is lost, it pops back. This means users don't need to manually press `i` to type in a text field — it just works.

The app can also call `controller.enterInsertMode()` / `controller.exitInsertMode()` explicitly.

## Core Components

### ModeStack

A stack of `QuillMode` values. Never empty — always has at least `NormalMode` at the bottom.

```
┌──────────┐
│ HintMode │  ← current (top)
├──────────┤
│NormalMode│  ← bottom, cannot be popped
└──────────┘
```

- `push(mode)` → transitions to new mode, emits on `onModeChanged`
- `pop()` → returns to previous mode (no-op if only one remains)
- `reset()` → clears to `[NormalMode]`
- `onModeChanged` → sync broadcast stream (must be sync to avoid Flutter rebuild timing issues)

`QuillMode` is a sealed class with three built-in subclasses: `NormalMode`, `InsertMode`, `HintMode`. Apps can create custom modes by extending `QuillMode`.

**Critical implementation detail:** The stream controller uses `sync: true`. An async broadcast stream causes mode change notifications to fire as microtasks, which land after `tester.pump()` in tests and after the current build frame in production — meaning dependent widgets miss the update.

### KeyMatcher (Trie)

The heart of chord matching. Builds one prefix trie per mode from the binding map.

```
Normal mode trie:

  root
  ├─ 'j' → terminal: "scroll-down"
  ├─ 'k' → terminal: "scroll-up"
  ├─ 'f' → terminal: "hint-activate"
  └─ 'g'
     ├─ 't' → terminal: "next-tab"
     └─ 'T' → terminal: "prev-tab"
```

`feed(key, mode)` advances position in the mode's trie:
- **Terminal node reached** → `MatchFound(actionName)`, reset to root
- **Internal node with children** → `PartialMatch()`, start chord timer
- **No matching child** → `NoMatch()`, reset to root

**Chord timeout:** Default 1.5 seconds. If the timer fires during a partial match, position resets to root and `onTimeout` is called (so the UI can update the status bar). Timer restarts on each new key during a partial.

**Which-key delay:** A second, shorter timer (default 400ms) starts alongside the chord timeout on any `PartialMatch`. When it fires, `shouldShowWhichKey` becomes `true` and `onWhichKey` is called. Apps use this signal along with `continuations(mode)` to show a which-key guide listing available next keys. Both timers reset atomically on match, timeout, or explicit `reset()`.

**`continuations(mode)`:** Returns a `List<ChordContinuation>` describing each child of the current trie node — the available next keys. Each entry has `key` (the key to press), `actionName` (non-null if pressing this key completes a chord), and `hasChildren` (true if pressing this key leads to deeper chords). Callable at any time — at root it returns all top-level keys for the mode.

**Greedy matching:** If a node is both terminal and has children (e.g. `g` is bound AND `gt` is bound), the terminal match fires immediately. This is standard vim behavior — there is no lookahead delay. In practice, avoid binding a key that is also the prefix of a chord. Note: greedy matching means the which-key timer never starts for these keys, since `MatchFound` fires instantly.

### KeyChord

Value type representing a binding sequence. `KeyChord.parse(String)` handles:

| Input | Parsed keys |
|-------|-------------|
| `"j"` | `['j']` |
| `"gt"` | `['g', 't']` |
| `"<Escape>"` | `['Escape']` |
| `"<C-x>"` | `['Control', 'x']` |
| `"<S-a>"` | `['Shift', 'a']` |
| `"g<C-t>"` | `['g', 'Control', 't']` |

Modifier combos (`<C-x>`) expand into two trie nodes: `Control` then `x`. This means a `Ctrl+X` keypress feeds two tokens into the trie sequentially. It works but is worth knowing about — the trie must have a `Control` child at the right depth.

### ActionRegistry

Simple `Map<String, void Function()>`. Register callbacks by name, invoke by name. Throws on duplicate registration. Two actions are always pre-registered by `QuillController`:

- `"normal-mode"` → `modeStack.reset()`
- `"hint-activate"` → `modeStack.push(HintMode())`

### QuillConfig

Parsed from TOML. Structure:

```toml
[settings]
chord_timeout_ms = 1500
which_key_delay_ms = 400
hint_chars = "asdfghjkl"

[normal]
j = "scroll-down"
k = "scroll-up"
gt = "next-tab"
f = "hint-activate"

[insert]
"<Escape>" = "normal-mode"
```

`QuillConfig.merge(other)` overlays one config on another — `other` wins on key conflicts. This enables a default config with user overrides on top.

### HintLabelGenerator

Generates shortest-unique-prefix labels using a character set (default: home row `asdfghjkl`). Algorithm:

1. Start with `chars.length` single-character candidates in a queue
2. While candidate count < requested count: remove the last (least-preferred) candidate, expand it into `chars.length` two-character children
3. Take the first `count` candidates from the front of the queue

This produces labels like `a, s, d, f, g, h, j, k, la, ls, ld, lf` for 12 items — home-row single characters are preserved; only the tail expands. No label is ever a prefix of another label (expanded nodes are consumed, never emitted).

## Widget Layer

### QuillScope + QuillController

`QuillScope` is a `StatefulWidget` that:
1. Creates a `QuillController` (which owns ModeStack, KeyMatcher, ActionRegistry)
2. Wraps its child in `_QuillInherited` (InheritedNotifier) for descendant access
3. Wraps that in a `Focus` widget with `autofocus: true` and `onKeyEvent` pointing to the controller

`QuillController` extends `ChangeNotifier` and fires on:
- Mode changes (via ModeStack stream listener)
- Key match / partial match / timeout (after each `handleKeyEvent` call)
- Which-key delay elapsed (via `onWhichKey` callback)

The controller proxies `shouldShowWhichKey` and `continuations` from `KeyMatcher` for convenient widget-layer access.

Descendants access it via `QuillScope.of(context)`, which triggers rebuilds on any notification.

**Rebuild wiring detail:** `_QuillScopeState` listens to the controller and calls `setState` on every notification. `_QuillInherited.updateShouldNotify` returns `true` unconditionally. Both are needed — `InheritedNotifier` alone was insufficient because the controller identity never changes, and `updateShouldNotify` was returning false.

### QuillHint

A wrapper widget that registers a `HintEntry` with the nearest `QuillController`. Each entry has:
- A `GlobalKey` for positioning the overlay label
- An `actionName` (looked up in ActionRegistry)
- An optional `onHint` callback (takes precedence over actionName)

Registration happens in `didChangeDependencies`; unregistration in `dispose`.

### HintOverlay

A `StatefulWidget` that renders positioned label badges over registered `QuillHint` widgets when in `HintMode`.

- Uses a `Stack` with `Positioned` widgets, measuring each hint's position via `GlobalKey` → `RenderBox` → `localToGlobal`
- Generates labels via `HintLabelGenerator` using `config.hintChars`
- Has its own `FocusNode` that steals focus in HintMode to capture keystrokes
- Tracks typed prefix — highlights matching labels, hides non-matching
- On complete match: invokes action (or `onHint`), pops HintMode
- On Escape: pops HintMode without invoking anything
- On Backspace: removes last typed character

### QuillStatusBar

A `StatelessWidget` using `ListenableBuilder` to rebuild on controller changes. Displays `[MODE_NAME]` and the partial chord (if any). Accepts optional `TextStyle` overrides for mode and chord text.

## Data Flow

### Key press → action invocation

```
User presses 'g' then 't'
  │
  ▼
Focus.onKeyEvent (QuillScope)
  │
  ▼
QuillController.handleKeyEvent(KeyDownEvent('g'))
  │
  ▼
KeyMatcher.feed('g', NormalMode)
  → PartialMatch (node has children: 't', 'T')
  → chord timer starts (1.5s), which-key timer starts (400ms)
  → partialChord = "g"
  → notifyListeners() → StatusBar rebuilds, shows "g"
  → return KeyEventResult.handled
  │
  ... 400ms later ...
  │
  ▼
Which-key timer fires
  → shouldShowWhichKey = true
  → onWhichKey() → notifyListeners()
  → App can now read continuations: [{key: 't', action: 'next-tab'}, {key: 'T', action: 'prev-tab'}]
  │
  ▼
QuillController.handleKeyEvent(KeyDownEvent('t'))
  │
  ▼
KeyMatcher.feed('t', NormalMode)
  → MatchFound("next-tab")
  → timer cancelled, position reset
  → partialChord = ""
  │
  ▼
ActionRegistry.invoke("next-tab")
  → calls the callback registered by the app
  → notifyListeners() → StatusBar rebuilds, chord cleared
  → return KeyEventResult.handled
```

### Hint mode flow

```
User presses 'f' (bound to "hint-activate")
  │
  ▼
ActionRegistry invokes "hint-activate"
  → modeStack.push(HintMode())
  → onModeChanged emits HintMode
  → QuillController.notifyListeners()
  │
  ▼
HintOverlay rebuilds
  → mode is HintMode → show overlay
  → generate labels for registered hints
  → position labels over each QuillHint widget
  → HintOverlay's FocusNode requests focus
  │
  ▼
User types 'a' then 's'
  → HintOverlay's KeyHandler captures these
  → typed prefix "a" → filter labels to 'a*'
  → typed prefix "as" → exact match found
  │
  ▼
HintEntry matched
  → invoke onHint callback (or ActionRegistry.invoke(actionName))
  → modeStack.pop() → back to NormalMode
  → overlay hides
```

## Testing Strategy

**Core tests** (`test/core/`): Pure Dart, use `package:test`. Fast, no Flutter harness. Cover:
- ModeStack lifecycle and stream behavior
- KeyChord parsing from all TOML binding formats
- KeyMatcher trie matching, partial chords, timeouts (via `fake_async`)
- ActionRegistry CRUD operations
- QuillConfig TOML parsing and merge semantics
- HintLabelGenerator output correctness and prefix-freedom

**Widget tests** (`test/widgets/`): Use `package:flutter_test`. Cover:
- QuillScope provides controller to descendants
- Key events dispatch through full pipeline (single key, chord, mode switch)
- HintOverlay shows/hides labels, filters by typed prefix, invokes on match
- QuillStatusBar displays mode name and partial chord

## Dependencies

| Package | Purpose | Layer |
|---------|---------|-------|
| `flutter` | Widget framework | widgets |
| `toml` | TOML config parsing (via petitparser) | core |
| `fake_async` | Timer testing (dev only) | test |
| `flutter_test` | Widget testing (dev only) | test |
| `test` | Pure Dart testing (dev only) | test |

## Known Limitations (v1)

- **Global scope only.** No per-widget or per-screen binding scopes.
- **No command mode.** No `:` command palette or typed commands.
- **No count prefixes.** `5j` doesn't scroll 5 times.
- **Greedy matching.** Can't bind both `g` and `gt` — `g` always wins immediately.
- **Modifier combos are two tokens.** `<C-x>` feeds `Control` then `x` into the trie sequentially, which works but is architecturally fragile.
- **Config merge default detection.** `QuillConfig.merge` uses value comparison against hardcoded defaults. Setting a value explicitly to the default won't override.
- **No runtime rebinding.** Bindings are fixed at `QuillConfig` construction time.

## Future Directions (v2+)

- **Command mode** — `:` opens a command palette, commands invokable by name
- **Count prefixes** — `5j` = invoke scroll-down 5 times
- **Per-widget scoping** — compose with Flutter's `Actions` system for tree-scoped bindings
- **Runtime bind/unbind** — modify bindings from command palette
- **GUI binding editor** — visual key configuration
- **Profiles UI** — switch between TOML profiles at runtime
