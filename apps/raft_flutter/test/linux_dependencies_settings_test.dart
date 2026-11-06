import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/linux_dependencies_settings.dart';
import 'package:raft_flutter/platform/linux_dependencies.dart';
import 'package:raft_ui/raft_ui.dart';

import 'linux_dependency_fixture.dart';

void main() {
  late DependencyHost host;
  late LinuxDependencies service;
  setUp(() {
    host = DependencyHost()..bind();
    service = LinuxDependencies(platformAvailable: () => true);
  });
  tearDown(() {
    host.unbind();
    service.dispose();
  });
  Future<void> mount(WidgetTester t) => t.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: LinuxDependenciesSettings(service: service),
        ),
      ),
    ),
  );

  testWidgets(
    'unchecked is quiet; check, copy and installed recheck remove notices',
    (t) async {
      String? copied;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await mount(t);
      await t.pumpAndSettle();
      expect(
        find.byKey(const Key('linux-dependency-notice-webkit')),
        findsNothing,
      );
      expect(find.text('Not checked'), findsNWidgets(3));
      await t.tap(find.byKey(const Key('linux-dependencies-check')));
      await t.pumpAndSettle();
      expect(
        find.byKey(const Key('linux-dependency-notice-webkit')),
        findsOneWidget,
      );
      await t.ensureVisible(
        find.byKey(const Key('linux-dependency-copy-webkit')),
      );
      await t.tap(find.byKey(const Key('linux-dependency-copy-webkit')));
      await t.pump();
      expect(copied, 'sudo apt install libwebkit2gtk-4.1-0');
      host.installed.addAll(['webkit', 'mpv', 'poppler']);
      await t.ensureVisible(
        find.byKey(const Key('linux-dependency-retry-webkit')),
      );
      await t.tap(find.byKey(const Key('linux-dependency-retry-webkit')));
      await t.pumpAndSettle();
      for (final feature in LinuxDependency.values) {
        expect(
          find.byKey(Key('linux-dependency-notice-${feature.name}')),
          findsNothing,
        );
        expect(
          find.byKey(Key('linux-dependency-status-${feature.name}-available')),
          findsOneWidget,
        );
      }
      await t.pumpWidget(const SizedBox());
      await mount(t);
      await t.pumpAndSettle();
      expect(
        find.text(
          'Install the system dependency to use this feature. The rest of Raft remains available.',
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'healthy dependencies never show installation or restart prompts',
    (t) async {
      host.installed.addAll(['webkit', 'mpv', 'poppler']);
      await mount(t);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('linux-dependencies-check')));
      await t.pumpAndSettle();
      expect(find.text('Copy install command'), findsNothing);
      expect(find.textContaining('restart'), findsNothing);
    },
  );
}
