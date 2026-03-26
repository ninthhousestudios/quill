import 'package:flutter/material.dart';
import 'package:quill_keys/quill.dart';

const _toml = '''
[settings]
chord_timeout_ms = 1500
hint_chars = "asdfghjkl"

[normal]
j = "scroll-down"
k = "scroll-up"
f = "hint-activate"
gt = "next-tab"

[insert]
"<Escape>" = "normal-mode"
''';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: QuillScope(
        config: QuillConfig.fromToml(_toml),
        actions: {
          'scroll-down': () => debugPrint('scroll down'),
          'scroll-up': () => debugPrint('scroll up'),
          'next-tab': () => debugPrint('next tab'),
        },
        child: HintOverlay(
          child: Scaffold(
            appBar: AppBar(title: const Text('Quill Example')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  QuillHint(
                    actionName: 'scroll-down',
                    child: ElevatedButton(
                      onPressed: () {},
                      child: const Text('Scroll Down'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  QuillHint(
                    actionName: 'scroll-up',
                    child: ElevatedButton(
                      onPressed: () {},
                      child: const Text('Scroll Up'),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const TextField(
                    decoration: InputDecoration(
                      labelText: 'Focus here for Insert mode',
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: const Padding(
              padding: EdgeInsets.all(8.0),
              child: QuillStatusBar(),
            ),
          ),
        ),
      ),
    );
  }
}
