/// Default keybinding profile modeled after qutebrowser.
///
/// Only includes bindings that make sense in a Flutter GUI app context.
/// Browser-specific actions (open URL, tab-focus-by-number) are omitted.
/// Apps should register their own action callbacks for these names.
const qutebrowserProfileToml = '''
[settings]
chord_timeout_ms = 1500
hint_chars = "asdghjkl"

# --- Normal mode -----------------------------------------------------------
[normal]
# Scrolling
j = "scroll-down"
k = "scroll-up"
e = "scroll-half-down"
u = "scroll-half-up"
gg = "scroll-top"
G = "scroll-bottom"

# Navigation
h = "back"
l = "forward"
H = "back"
L = "forward"

# Tabs
J = "next-tab"
K = "prev-tab"

# Zoom
"+" = "zoom-in"
"=" = "zoom-in"
"-" = "zoom-out"

# Hints
f = "hint-activate"

# UI toggles
xs = "toggle-statusbar"
xt = "toggle-tabs"
xx = "toggle-chrome"

# Dark mode
D = "toggle-dark-mode"

# --- Insert mode ------------------------------------------------------------
[insert]
"<Escape>" = "normal-mode"
"<A-i>" = "normal-mode"

# --- Hint mode --------------------------------------------------------------
[hint]
"<Escape>" = "normal-mode"
f = "normal-mode"
"<A-i>" = "normal-mode"
''';
