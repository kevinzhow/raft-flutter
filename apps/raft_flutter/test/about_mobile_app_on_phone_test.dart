// Settings › About always has the Mobile app section (Web AboutSection.tsx:
// the section is unconditional), on a phone as on a desktop.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/workspace_settings.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_updater/raft_updater.dart';

import 'workspace_source_location_contract_test.dart' show pageFixture;

void main() {
  // The About page reads the process-wide updater; make it once, outside the
  // tests' leak tracking (it lives for the process, as in the app).
  setUpAll(() => AppUpdater.instance);
  for (final platform in [TargetPlatform.android, TargetPlatform.linux]) {
    testWidgets('${platform.name}: About shows the Mobile app downloads', (
      t,
    ) async {
      final (w, _) = await pageFixture(t, section: 'chat');
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme().copyWith(platform: platform),
          home: Scaffold(
            body: SingleChildScrollView(
              child: WorkspaceAboutSection(controller: w),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Download Android APK'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });
  }
}
