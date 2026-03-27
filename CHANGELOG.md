# Changelog

## 1.0.1

### Fixed
- Hint mode now exits when pressing `f` again (toggle behavior)
- Profile-specific escape keys (`jk` in vim, `Alt-i` in qutebrowser) now work in hint mode
- HintOverlay delegates to TOML `[hint]` bindings before consuming keys as label input, so users can configure custom exit keys
- Removed `f` from default `hint_chars` to avoid conflict with the exit binding

## 1.0.0

Initial release.

### Core
- `QuillMode` sealed class with `NormalMode`, `InsertMode`, `HintMode` — extensible for custom modes
- `ModeStack` — push/pop/reset mode stack with sync broadcast stream
- `KeyMatcher` — trie-based key matching with sequential chord support and configurable timeout (default 1.5s)
- `KeyChord` — parse binding strings from TOML config (`"gt"`, `"<Escape>"`, `"<C-x>"`)
- `ActionRegistry` — register and invoke callbacks by string name
- `QuillConfig` — TOML configuration parser with merge/overlay support
- `HintLabelGenerator` — home-row-first shortest-unique-prefix label generation

### Widgets
- `QuillScope` — top-level `Focus` widget + `InheritedWidget` providing `QuillController` to descendants
- `QuillController` — `ChangeNotifier` owning mode stack, key matcher, action registry, and hint registration
- `QuillHint` — wrapper widget registering a child as a hint target
- `HintOverlay` — renders positioned hint labels in Hint mode with keyboard-driven selection
- `QuillStatusBar` — displays current mode and partial chord in progress

### Features
- Auto insert mode detection when `TextField` / `EditableText` gains focus
- TOML-based binding profiles (load different files for different keybinding styles)
- Built-in `"normal-mode"` and `"hint-activate"` actions
- Modifier key support: `<C-x>`, `<S-a>`, `<A-x>`, `<M-x>`
