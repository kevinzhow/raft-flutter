// A real Flutter/native caption host without session, database or network setup.
// Build with: flutter build windows --target test_driver/windows_frame_qa.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_flutter/platform/desktop_title_bar.dart';
import 'package:raft_flutter/platform/windows_tray.dart';
import 'package:raft_ui/raft_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final tray = WindowsTray(lab: true);
  await tray.initialize((label) => label);
  runApp(_FrameQa(tray: tray));
}

class _FrameQa extends StatefulWidget {
  const _FrameQa({required this.tray});

  final WindowsTray tray;

  @override
  State<_FrameQa> createState() => _FrameQaState();
}

class _FrameQaState extends State<_FrameQa> {
  static const _themes = [
    (name: 'Brutal light', id: 'brutal', dark: false),
    (name: 'Elegant light', id: 'elegant', dark: false),
    (name: 'Elegant dark', id: 'elegant', dark: true),
    (name: 'Raft light', id: builtInRaftThemeId, dark: false),
    (name: 'Raft dark', id: builtInRaftThemeId, dark: true),
  ];
  var _theme = 0;
  var _searches = 0;

  @override
  Widget build(BuildContext context) {
    final theme = _themes[_theme];
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: raftTheme(
        pack: packForThemeId(theme.id),
        dark: theme.dark,
        platform: TargetPlatform.windows,
      ),
      home: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.f9): widget.tray.quit,
          const SingleActivator(LogicalKeyboardKey.f6): () => setState(() {
            _theme = (_theme + 1) % _themes.length;
          }),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: LayoutBuilder(
              builder: (context, size) {
                final integrated = raftShowsWorkspaceTopBar(
                  tokens: RaftTokens.of(context),
                  width: size.maxWidth,
                  nativeWindowChrome: true,
                );
                return DesktopTitleBar(
                  integrated: integrated,
                  child: Builder(
                    builder: (context) {
                      final chrome = DesktopTitleBarScope.maybeOf(context);
                      return Column(
                        children: [
                          if (integrated)
                            RaftWorkspaceTopBar(
                              workspace: const Text('Windows frame QA'),
                              onSearch: () => setState(() => _searches++),
                              leadingInset: chrome?.leadingInset ?? 0,
                              trailingInset: chrome?.trailingInset ?? 0,
                              onDragStart: chrome?.onDragStart,
                              onDoubleTap: chrome?.onDoubleTap,
                            ),
                          Expanded(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  '${theme.name}\nF6 cycles the five themes; '
                                  'F9 quits this QA host.\n'
                                  'Search activations: $_searches\n\n'
                                  'This QA host opens no account or message database.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
