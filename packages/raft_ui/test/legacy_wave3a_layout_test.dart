import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  Widget host(Widget child, Size size, {bool dark = false}) => MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(
      theme: raftTheme(dark: dark),
      home: Scaffold(
        body: SizedBox.fromSize(
          size: size,
          child: Center(child: child),
        ),
      ),
    ),
  );

  for (final size in const [Size(841, 701), Size(1180, 820), Size(390, 844)]) {
    for (final dark in const [false, true]) {
      final mode = dark ? 'dark' : 'light';
      testWidgets(
        'Wave 3A previews and panes render cleanly at ${size.width.toInt()}x${size.height.toInt()} ($mode)',
        (t) async {
          t.view.physicalSize = size;
          t.view.devicePixelRatio = 1.0;
          addTearDown(() {
            t.view.resetPhysicalSize();
            t.view.resetDevicePixelRatio();
          });

          await t.pumpWidget(
            host(
              const RaftOnboardingDotPane(
                child: RaftServerCreatePreview(
                  serverName: 'Design Team',
                  serverSlug: 'design-team',
                ),
              ),
              size,
              dark: dark,
            ),
          );
          expect(t.takeException(), isNull);

          await t.pumpWidget(
            host(
              const RaftOnboardingDotPane(
                child: RaftIdentityImpactPreview(
                  displayName: 'Riley',
                  handle: 'riley',
                ),
              ),
              size,
              dark: dark,
            ),
          );
          expect(t.takeException(), isNull);

          await t.pumpWidget(
            host(
              RaftCindySetupScreen(
                fields: const Text('Fields'),
                onCreate: () {},
                sessionActions: RaftCindySessionFooter(
                  onSwitchServer: () {},
                  onDeleteServer: () {},
                ),
              ),
              size,
              dark: dark,
            ),
          );
          expect(t.takeException(), isNull);

          await t.pumpWidget(
            host(
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    RaftSetupHandoffCard(
                      starting: false,
                      onDone: () {},
                      onSwitchServer: () {},
                    ),
                    const SizedBox(height: 16),
                    const RaftFeedbackEmptyState(kind: RaftFeedbackFilter.all),
                    const SizedBox(height: 16),
                    const RaftQuickSwitcherSkeleton(),
                    const SizedBox(height: 16),
                    RaftQuickSwitcherErrorCard(
                      title: 'Search failed',
                      body: 'Please retry.',
                      actionLabel: 'Retry',
                      onAction: () {},
                    ),
                  ],
                ),
              ),
              size,
              dark: dark,
            ),
          );
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
