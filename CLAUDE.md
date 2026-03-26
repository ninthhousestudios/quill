# Quill (quill_keys) — Claude Development Guide

## What This Is

A vim-style modal keybinding Flutter package. Modes, chords, hints, TOML config. Modeled after qutebrowser.

## Package Structure

Single package, layered internally:
- `lib/src/core/` — **pure Dart, zero Flutter imports.** Do not add Flutter imports to these files.
- `lib/src/widgets/` — Flutter widget layer, depends on core.
- `lib/quill.dart` — barrel export.
- `lib/main.dart` — demo app (not part of the package API).

## Running Tests

```bash
flutter test              # all tests
flutter test test/core/   # core only (pure Dart, fast)
flutter test test/widgets/ # widget tests
flutter analyze           # lint check
```

## Key Architectural Decisions

- **ModeStack stream must be sync** (`StreamController.broadcast(sync: true)`). Async causes Flutter widget rebuilds to miss mode changes within the same frame.
- **InheritedWidget wiring**: `_QuillScopeState` listens to the controller and calls `setState`. `updateShouldNotify` returns `true` unconditionally. Both are required.
- **Modifier combos feed two trie tokens**: `<C-x>` becomes `['Control', 'x']` — two sequential `feed()` calls from one physical keypress.
- **Greedy matching**: if a trie node is both terminal and has children, the terminal wins immediately. Don't bind a key that's also the prefix of a chord.
- **Insert mode passes through**: `handleKeyEvent` returns `KeyEventResult.ignored` when in InsertMode so text fields receive keys.

## TOML Config Format

```toml
[settings]
chord_timeout_ms = 1500
hint_chars = "asdfghjkl"

[normal]
j = "scroll-down"
gt = "next-tab"

[insert]
"<Escape>" = "normal-mode"
```

## Built-in Actions

These are always registered by `QuillController`:
- `"normal-mode"` — resets mode stack to Normal
- `"hint-activate"` — pushes HintMode

## Adding New Core Classes

If adding to `src/core/`, ensure:
1. Zero Flutter imports
2. Unit tests in `test/core/` using `package:test/test.dart` (not flutter_test)
3. Export added to `lib/quill.dart`

## Adding New Widgets

If adding to `src/widgets/`, ensure:
1. Widget tests in `test/widgets/` using `package:flutter_test/flutter_test.dart`
2. Export added to `lib/quill.dart`

## v1 Scope Boundaries

**In scope:** modes, chords, hints, TOML config, status bar, global scope.

**Out of scope (v2+):** command mode, count prefixes, per-widget scoping, runtime rebinding, GUI binding editor.
