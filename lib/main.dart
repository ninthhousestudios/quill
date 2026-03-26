import 'package:flutter/material.dart';
import 'package:quill_keys/quill.dart';

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

void main() {
  runApp(const QuillDemoApp());
}

// ---------------------------------------------------------------------------
// Profiles
// ---------------------------------------------------------------------------

enum DemoProfile {
  vim('Vim'),
  josh("Josh's defaults");

  const DemoProfile(this.label);
  final String label;

  String get toml => switch (this) {
        vim => vimProfileToml,
        josh => qutebrowserProfileToml,
      };
}

// ---------------------------------------------------------------------------
// Themes
// ---------------------------------------------------------------------------

// Josh's theme: black, green (#00ff00), purple (#6b00ff).
final _joshTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: Colors.black,
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF00FF00),
    secondary: Color(0xFF6B00FF),
    surface: Color(0xFF111111),
    onPrimary: Colors.black,
    onSecondary: Colors.white,
    onSurface: Color(0xFF00FF00),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF111111),
    foregroundColor: Color(0xFF00FF00),
  ),
  tabBarTheme: const TabBarThemeData(
    labelColor: Color(0xFF00FF00),
    unselectedLabelColor: Color(0xFF6B00FF),
    indicatorColor: Color(0xFF00FF00),
  ),
  cardTheme: const CardThemeData(
    color: Color(0xFF111111),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF6B00FF),
      foregroundColor: Colors.white,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF00FF00),
      side: const BorderSide(color: Color(0xFF6B00FF)),
    ),
  ),
  inputDecorationTheme: const InputDecorationTheme(
    labelStyle: TextStyle(color: Color(0xFF6B00FF)),
    hintStyle: TextStyle(color: Color(0xFF444444)),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Color(0xFF6B00FF)),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Color(0xFF00FF00), width: 2),
    ),
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: Color(0xFF00FF00)),
    bodyLarge: TextStyle(color: Color(0xFF00FF00)),
    displayMedium: TextStyle(color: Color(0xFF00FF00)),
  ),
  useMaterial3: true,
);

final _defaultTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
  useMaterial3: true,
);

// ---------------------------------------------------------------------------
// Root app
// ---------------------------------------------------------------------------

class QuillDemoApp extends StatefulWidget {
  const QuillDemoApp({super.key});

  @override
  State<QuillDemoApp> createState() => _QuillDemoAppState();
}

class _QuillDemoAppState extends State<QuillDemoApp> {
  bool _useQbTheme = false;
  DemoProfile _profile = DemoProfile.vim;

  void _toggleTheme() => setState(() => _useQbTheme = !_useQbTheme);

  void _setProfile(DemoProfile p) => setState(() => _profile = p);

  @override
  Widget build(BuildContext context) {
    final config = QuillConfig.fromToml(_profile.toml);

    return MaterialApp(
      title: 'Quill Demo',
      debugShowCheckedModeBanner: false,
      theme: _useQbTheme ? _joshTheme : _defaultTheme,
      home: QuillScope(
        key: ValueKey(_profile), // force rebuild on profile switch
        config: config,
        child: _DemoShell(
          onToggleTheme: _toggleTheme,
          profile: _profile,
          onProfileChanged: _setProfile,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shell — registers actions, hosts the tab layout.
// ---------------------------------------------------------------------------

class _DemoShell extends StatefulWidget {
  const _DemoShell({
    required this.onToggleTheme,
    required this.profile,
    required this.onProfileChanged,
  });

  final VoidCallback onToggleTheme;
  final DemoProfile profile;
  final ValueChanged<DemoProfile> onProfileChanged;

  @override
  State<_DemoShell> createState() => _DemoShellState();
}

class _DemoShellState extends State<_DemoShell>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _counter = 0;
  final ScrollController _scrollController = ScrollController();

  // Track last action message for display
  String _lastAction = 'Press f to activate hints, j/k to scroll';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Register actions after the first frame so QuillScope.of is available
    // and we are safely outside the build phase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _registerActions();
    });
  }

  void _cycleProfile() {
    final values = DemoProfile.values;
    final next = values[(widget.profile.index + 1) % values.length];
    widget.onProfileChanged(next);
  }

  /// Guard: only run scroll actions when the controller is attached.
  void _scroll(double Function(ScrollPosition pos) target,
      {Duration duration = const Duration(milliseconds: 150),
      String label = ''}) {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      target(_scrollController.position).clamp(0.0, double.infinity),
      duration: duration,
      curve: Curves.easeOut,
    );
    if (label.isNotEmpty) setState(() => _lastAction = label);
  }

  void _registerActions() {
    final ctrl = QuillScope.of(context);
    ctrl.registerActions({
      'scroll-down': () => _scroll(
            (p) => p.pixels + 80,
            label: 'Scrolled down',
          ),
      'scroll-up': () => _scroll(
            (p) => p.pixels - 80,
            label: 'Scrolled up',
          ),
      'scroll-half-down': () => _scroll(
            (p) => p.pixels + 300,
            duration: const Duration(milliseconds: 200),
            label: 'Half-page scroll down (e)',
          ),
      'scroll-half-up': () => _scroll(
            (p) => p.pixels - 300,
            duration: const Duration(milliseconds: 200),
            label: 'Half-page scroll up (u)',
          ),
      'scroll-top': () => _scroll(
            (_) => 0,
            duration: const Duration(milliseconds: 300),
            label: 'Scroll to top (gg)',
          ),
      'scroll-bottom': () => _scroll(
            (p) => p.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            label: 'Scroll to bottom (G)',
          ),
      'next-tab': () {
        _tabController.animateTo(
          (_tabController.index + 1) % _tabController.length,
        );
        setState(() => _lastAction = 'Next tab (J)');
      },
      'prev-tab': () {
        _tabController.animateTo(
          (_tabController.index - 1 + _tabController.length) %
              _tabController.length,
        );
        setState(() => _lastAction = 'Prev tab (K)');
      },
      'back': () => setState(() => _lastAction = 'Back (h/H)'),
      'forward': () => setState(() => _lastAction = 'Forward (l/L)'),
      'zoom-in': () => setState(() => _lastAction = 'Zoom in (+/=)'),
      'zoom-out': () => setState(() => _lastAction = 'Zoom out (-)'),
      'toggle-statusbar': () => setState(() => _lastAction = 'Toggle statusbar (xs)'),
      'toggle-tabs': () => setState(() => _lastAction = 'Toggle tabs (xt)'),
      'toggle-chrome': () => setState(() => _lastAction = 'Toggle chrome (xx)'),
      'toggle-dark-mode': () {
        widget.onToggleTheme();
        setState(() => _lastAction = 'Toggled theme (D)');
      },
      'increment': () {
        setState(() {
          _counter++;
          _lastAction = 'Counter incremented to $_counter';
        });
      },
      'decrement': () {
        setState(() {
          _counter = (_counter - 1).clamp(0, 9999);
          _lastAction = 'Counter decremented to $_counter';
        });
      },
      'reset-counter': () {
        setState(() {
          _counter = 0;
          _lastAction = 'Counter reset to 0';
        });
      },
      'show-info': () {
        setState(() => _lastAction = 'Info action triggered via hint');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quill hint system working!'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      'goto-tab-actions': () {
        _tabController.animateTo(0);
        setState(() => _lastAction = 'Switched to Actions tab');
      },
      'goto-tab-scroll': () {
        _tabController.animateTo(1);
        setState(() => _lastAction = 'Switched to Scroll tab');
      },
      'goto-tab-insert': () {
        _tabController.animateTo(2);
        setState(() => _lastAction = 'Switched to Insert tab');
      },
      // vim profile binds "i" to this
      'enter-insert': () {
        setState(() => _lastAction = 'Enter insert (i) — focus a text field');
      },
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HintOverlay(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quill Demo'),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor ??
              Theme.of(context).colorScheme.inversePrimary,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: QuillHint(
                actionName: 'cycle-profile',
                onHint: () => _cycleProfile(),
                child: DropdownButton<DemoProfile>(
                  value: widget.profile,
                  underline: const SizedBox.shrink(),
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 13,
                  ),
                  items: [
                    for (final p in DemoProfile.values)
                      DropdownMenuItem(value: p, child: Text(p.label)),
                  ],
                  onChanged: (p) {
                    if (p != null) widget.onProfileChanged(p);
                  },
                ),
              ),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              QuillHint(
                actionName: 'goto-tab-actions',
                child: const Tab(text: 'Actions'),
              ),
              QuillHint(
                actionName: 'goto-tab-scroll',
                child: const Tab(text: 'Scroll'),
              ),
              QuillHint(
                actionName: 'goto-tab-insert',
                child: const Tab(text: 'Insert'),
              ),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _ActionsTab(
              counter: _counter,
              lastAction: _lastAction,
              profile: widget.profile,
            ),
            _ScrollTab(
              scrollController: _scrollController,
              lastAction: _lastAction,
            ),
            _InsertTab(
              lastAction: _lastAction,
              profile: widget.profile,
            ),
          ],
        ),
        bottomNavigationBar: _StatusBarBand(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status bar band — sits at the bottom of the screen.
// ---------------------------------------------------------------------------

class _StatusBarBand extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: QuillStatusBar(
            modeStyle: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: scheme.primary,
            ),
            chordStyle: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: scheme.secondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 1 — hint-wrapped action buttons and a counter.
// ---------------------------------------------------------------------------

class _ActionsTab extends StatelessWidget {
  const _ActionsTab({
    required this.counter,
    required this.lastAction,
    required this.profile,
  });

  final int counter;
  final String lastAction;
  final DemoProfile profile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Last-action feedback banner
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lastAction,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Counter display
          Center(
            child: Text(
              '$counter',
              style: Theme.of(context).textTheme.displayMedium,
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text('counter',
                style: TextStyle(color: Theme.of(context).hintColor)),
          ),
          const SizedBox(height: 24),

          // QuillHint-wrapped buttons
          const Text(
            'Actions (press f to show hints):',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              QuillHint(
                actionName: 'increment',
                child: ElevatedButton.icon(
                  onPressed: () => QuillScope.of(context)
                      .actionRegistry
                      .invoke('increment'),
                  icon: const Icon(Icons.add),
                  label: const Text('Increment'),
                ),
              ),
              QuillHint(
                actionName: 'decrement',
                child: ElevatedButton.icon(
                  onPressed: () => QuillScope.of(context)
                      .actionRegistry
                      .invoke('decrement'),
                  icon: const Icon(Icons.remove),
                  label: const Text('Decrement'),
                ),
              ),
              QuillHint(
                actionName: 'reset-counter',
                child: OutlinedButton.icon(
                  onPressed: () => QuillScope.of(context)
                      .actionRegistry
                      .invoke('reset-counter'),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset'),
                ),
              ),
              QuillHint(
                actionName: 'show-info',
                child: OutlinedButton.icon(
                  onPressed: () => QuillScope.of(context)
                      .actionRegistry
                      .invoke('show-info'),
                  icon: const Icon(Icons.info_outline),
                  label: const Text('Info'),
                ),
              ),
            ],
          ),

          const Spacer(),
          _KeyHelpCard(profile: profile),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2 — scrollable content to demonstrate j/k bindings.
// ---------------------------------------------------------------------------

class _ScrollTab extends StatelessWidget {
  const _ScrollTab({
    required this.scrollController,
    required this.lastAction,
  });

  final ScrollController scrollController;
  final String lastAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            lastAction,
            style: TextStyle(
                color: Theme.of(context).hintColor, fontSize: 12),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 40,
            itemBuilder: (context, i) => ListTile(
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text('Item ${i + 1}'),
              subtitle: Text('Press j/k to scroll — no mouse needed'),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 3 — text field to demonstrate Insert mode auto-detection.
// ---------------------------------------------------------------------------

class _InsertTab extends StatefulWidget {
  const _InsertTab({required this.lastAction, required this.profile});

  final String lastAction;
  final DemoProfile profile;

  @override
  State<_InsertTab> createState() => _InsertTabState();
}

class _InsertTabState extends State<_InsertTab> {
  final FocusNode _field1Focus = FocusNode();
  final FocusNode _field2Focus = FocusNode();

  @override
  void dispose() {
    _field1Focus.dispose();
    _field2Focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                widget.lastAction,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Insert Mode Demo',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            widget.profile == DemoProfile.vim
                ? 'Click a field or press i to enter INSERT mode. '
                  'Press Escape (or jk) to return to NORMAL. '
                  'Watch the status bar at the bottom.'
                : 'Click into a field — Quill auto-detects text input and '
                  'switches to INSERT mode. Press Escape or Alt+i '
                  'to return to NORMAL. Watch the status bar.',
          ),
          const SizedBox(height: 24),
          QuillHint(
            actionName: 'focus-field-1',
            onHint: () => _field1Focus.requestFocus(),
            child: TextField(
              focusNode: _field1Focus,
              decoration: const InputDecoration(
                labelText: 'Type here',
                hintText: 'Focus me to enter INSERT mode automatically',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ),
          const SizedBox(height: 16),
          QuillHint(
            actionName: 'focus-field-2',
            onHint: () => _field2Focus.requestFocus(),
            child: TextField(
              focusNode: _field2Focus,
              decoration: const InputDecoration(
                labelText: 'Another field',
                hintText: 'Tab between fields — mode follows focus',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const Spacer(),
          _KeyHelpCard(profile: widget.profile),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Key help reference card shown at the bottom of tabs.
// ---------------------------------------------------------------------------

const _vimBindings = [
  ('j/k', 'Scroll'),
  ('Ctrl+d/u', 'Half-page'),
  ('gg', 'Top'),
  ('G', 'Bottom'),
  ('gt/gT', 'Next/prev tab'),
  ('i', 'Insert mode'),
  ('f', 'Hints'),
  ('Esc', 'Normal mode'),
  ('jk', 'Leave insert'),
];

const _joshBindings = [
  ('j/k', 'Scroll'),
  ('e/u', 'Half-page'),
  ('gg', 'Top'),
  ('G', 'Bottom'),
  ('J/K', 'Next/prev tab'),
  ('h/l', 'Back/forward'),
  ('f', 'Hints'),
  ('D', 'Theme toggle'),
  ('Esc', 'Normal mode'),
  ('Alt+i', 'Leave insert'),
];

class _KeyHelpCard extends StatelessWidget {
  const _KeyHelpCard({required this.profile});

  final DemoProfile profile;

  @override
  Widget build(BuildContext context) {
    final bindings =
        profile == DemoProfile.vim ? _vimBindings : _joshBindings;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Keybindings',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                for (final (key, desc) in bindings)
                  RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        TextSpan(
                          text: key,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        TextSpan(
                          text: ' $desc',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
