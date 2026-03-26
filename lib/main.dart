import 'package:flutter/material.dart';
import 'package:quill_keys/quill.dart';

// ---------------------------------------------------------------------------
// TOML config — defines all keybindings for the demo app.
// ---------------------------------------------------------------------------

const _kTomlConfig = '''
[normal]
j = "scroll-down"
k = "scroll-up"
f = "hint-activate"
i = "enter-insert"

[insert]
Escape = "normal-mode"

[normal."gt"]
action = "next-tab"

[normal."gT"]
action = "prev-tab"
''';

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

void main() {
  runApp(const QuillDemoApp());
}

// ---------------------------------------------------------------------------
// Root app — QuillScope wraps everything so keybindings are global.
// ---------------------------------------------------------------------------

class QuillDemoApp extends StatelessWidget {
  const QuillDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final config = QuillConfig.fromToml(_kTomlConfig);

    return MaterialApp(
      title: 'Quill Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: QuillScope(
        config: config,
        child: const _DemoShell(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shell — registers actions, hosts the tab layout.
// ---------------------------------------------------------------------------

class _DemoShell extends StatefulWidget {
  const _DemoShell();

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

  void _registerActions() {
    final ctrl = QuillScope.of(context);
    ctrl.registerActions({
      'scroll-down': () {
        final target =
            (_scrollController.offset + 80).clamp(0.0, double.infinity);
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
        setState(() => _lastAction = 'Scrolled down');
      },
      'scroll-up': () {
        final target =
            (_scrollController.offset - 80).clamp(0.0, double.infinity);
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
        setState(() => _lastAction = 'Scrolled up');
      },
      'enter-insert': () {
        QuillScope.of(context).enterInsertMode();
        setState(() => _lastAction = 'Entered INSERT mode (press Escape to leave)');
      },
      'next-tab': () {
        _tabController.animateTo(
          (_tabController.index + 1) % _tabController.length,
        );
        setState(() => _lastAction = 'Next tab (gt)');
      },
      'prev-tab': () {
        _tabController.animateTo(
          (_tabController.index - 1 + _tabController.length) %
              _tabController.length,
        );
        setState(() => _lastAction = 'Prev tab (gT)');
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
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Actions'),
              Tab(text: 'Scroll'),
              Tab(text: 'Insert'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _ActionsTab(
              counter: _counter,
              lastAction: _lastAction,
            ),
            _ScrollTab(
              scrollController: _scrollController,
              lastAction: _lastAction,
            ),
            _InsertTab(lastAction: _lastAction),
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
      color: scheme.inversePrimary,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: QuillStatusBar(
            modeStyle: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: scheme.onSurface,
            ),
            chordStyle: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: scheme.primary,
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
  });

  final int counter;
  final String lastAction;

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
          const Center(
            child: Text('counter', style: TextStyle(color: Colors.grey)),
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
          const _KeyHelpCard(),
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
            style: const TextStyle(color: Colors.grey, fontSize: 12),
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

class _InsertTab extends StatelessWidget {
  const _InsertTab({required this.lastAction});

  final String lastAction;

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
                lastAction,
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
          const Text(
            'Click into the field below — Quill automatically detects the '
            'text input and switches to INSERT mode. Press Escape to return '
            'to NORMAL mode. Watch the status bar at the bottom.',
          ),
          const SizedBox(height: 24),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Type here',
              hintText: 'Focus me to enter INSERT mode automatically',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Another field',
              hintText: 'Tab between fields — mode follows focus',
              border: OutlineInputBorder(),
            ),
          ),
          const Spacer(),
          const _KeyHelpCard(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Key help reference card shown at the bottom of tabs.
// ---------------------------------------------------------------------------

class _KeyHelpCard extends StatelessWidget {
  const _KeyHelpCard();

  @override
  Widget build(BuildContext context) {
    const bindings = [
      ('j', 'Scroll down'),
      ('k', 'Scroll up'),
      ('f', 'Hint mode'),
      ('i', 'Enter insert mode'),
      ('gt', 'Next tab'),
      ('gT', 'Prev tab'),
      ('Esc', 'Normal mode'),
    ];

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
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
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
