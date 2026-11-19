import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/desktop_title_bar.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets(
    'Mac workspace sends its painted height and preserves preview clearance',
    (tester) async {
      const channel = MethodChannel(DesktopTitleBarController.channelName);
      final controller = DesktopTitleBarController(
        channel: channel,
        platform: TargetPlatform.macOS,
        web: false,
      );
      final requests = <Map<Object?, Object?>>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'setIntegrated') {
          requests.add(Map<Object?, Object?>.of(call.arguments as Map));
        }
        if (call.method == 'status' || call.method == 'setIntegrated') {
          return {
            'height': 40.0,
            'integrated': true,
            'leadingInset': 88.0,
            'fullscreen': false,
          };
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
        controller.state.dispose();
      });

      const preview = Key('preview');
      Widget app({
        bool integrated = true,
        RaftInteraction interaction = RaftInteraction.pointerMode,
        double? height,
      }) => MaterialApp(
        theme: raftTheme(platform: TargetPlatform.macOS),
        builder: (context, child) => RaftInteractionScope(
          interaction: interaction,
          child: height == null
              ? DesktopTitleBar(
                  controller: controller,
                  integrated: integrated,
                  child: child!,
                )
              : DesktopTitleBar(
                  controller: controller,
                  integrated: integrated,
                  integratedHeight: height,
                  child: child!,
                ),
        ),
        home: Scaffold(
          body: Column(
            children: [
              if (integrated)
                Builder(
                  builder: (context) => RaftWorkspaceTopBar(
                    leadingInset: DesktopTitleBarScope.maybeOf(context)!
                        .leadingInset,
                    workspace: const Text('Workspace'),
                    onSearch: () {},
                  ),
                ),
              Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    RaftPreviewPageRoute<void>(
                      builder: (_) => const SizedBox.expand(key: preview),
                    ),
                  ),
                  child: const Text('Open preview'),
                ),
              ),
            ],
          ),
        ),
      );

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final row = find.byType(RaftWorkspaceTopBar);
      expect(tester.getSize(row).height, 44);
      final desktopRequest = requests.last;
      expect(
        tester.getTopLeft(find.text('Workspace')).dx,
        greaterThanOrEqualTo(88),
      );

      await tester.tap(find.text('Open preview'));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(preview)).dy, 48);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();

      await tester.pumpWidget(app(interaction: RaftInteraction.touchMode));
      await tester.pumpAndSettle();
      expect(tester.getSize(row).height, 48);
      expect(requests.last, {'enabled': true, 'height': 48.0});

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final restoredDesktopRequest = requests.last;

      await tester.pumpWidget(app(integrated: false));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(RaftDesktopTitleStrip)).height, 48);
      expect(requests.last, {'enabled': true, 'height': 48.0});

      await tester.pumpWidget(app(height: 52));
      await tester.pumpAndSettle();
      expect(requests.last, {'enabled': true, 'height': 52.0});

      // Report a boundary mismatch after Flutter has unmounted the test view.
      addTearDown(() {
        expect(desktopRequest, {'enabled': true, 'height': 44.0});
        expect(restoredDesktopRequest, {'enabled': true, 'height': 44.0});
      });
    },
  );
}
