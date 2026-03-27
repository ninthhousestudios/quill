/// Default keybinding profile modeled after vim/neovim conventions.
///
/// Apps should register their own action callbacks for these names.
const vimProfileToml = '''
[settings]
chord_timeout_ms = 1500
hint_chars = "asdghjkl"

# --- Normal mode -----------------------------------------------------------
[normal]
# Scrolling
j = "scroll-down"
k = "scroll-up"
"<C-d>" = "scroll-half-down"
"<C-u>" = "scroll-half-up"
gg = "scroll-top"
G = "scroll-bottom"

# Tabs / buffers
gt = "next-tab"
gT = "prev-tab"

# Hints (like easymotion / hop.nvim)
f = "hint-activate"

# Enter insert
i = "enter-insert"

# --- Insert mode ------------------------------------------------------------
[insert]
"<Escape>" = "normal-mode"
jk = "normal-mode"

# --- Hint mode --------------------------------------------------------------
[hint]
"<Escape>" = "normal-mode"
f = "normal-mode"
jk = "normal-mode"
''';
