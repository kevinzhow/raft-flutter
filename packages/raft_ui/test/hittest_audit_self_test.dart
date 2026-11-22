import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../../tool/testing/hittest_audit.dart';

Widget _host(Widget child) => MaterialApp(
  theme: raftTheme().copyWith(platform: TargetPlatform.linux),
  home: Scaffold(body: child),
);

class _HoverDisappearingButton extends StatefulWidget {
  const _HoverDisappearingButton();

  @override
  State<_HoverDisappearingButton> createState() =>
      _HoverDisappearingButtonState();
}

class _HoverDisappearingButtonState extends State<_HoverDisappearingButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    child: IgnorePointer(
      ignoring: _hovered,
      child: RaftButton(
        key: const ValueKey('unstable-btn'),
        label: 'Flicker',
        onPressed: () {},
      ),
    ),
  );
}

class _RightHalfBlockerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool? hitTest(Offset position) => position.dx >= 200;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void main() {
  testWidgets('clean screen passes with probed controls > 0', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            spacing: 12,
            children: [
              RaftButton(
                key: const ValueKey('save-btn'),
                label: 'Save',
                onPressed: () {},
              ),
              RaftButton(
                key: const ValueKey('copy-btn'),
                label: '',
                uiVariant: RaftButtonVariant.ghost,
                uiSize: RaftButtonSize.iconMd,
                glyph: RaftGlyph.copy,
                tooltip: 'Copy Code',
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final report = await auditHitTests(tester, surface: 'clean-screen');
    expect(report.probedControls, 2);
    expect(report.findings, isEmpty, reason: report.formatFailure());
  });

  testWidgets('detects opaque sibling occluding a button in a Stack', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 200,
          height: 100,
          child: Stack(
            children: [
              Positioned(
                left: 16,
                top: 16,
                child: RaftButton(
                  key: const ValueKey('covered-btn'),
                  label: 'Covered',
                  onPressed: () {},
                ),
              ),
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (_) {},
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final report = await auditHitTests(
      tester,
      surface: 'occluded-sibling',
      options: const HitTestAuditOptions(probeHoverStability: false),
    );
    expect(report.probedControls, 1);
    expect(
      report.findings.where((f) => f.kind == HitTestIssueKind.occluded),
      isNotEmpty,
    );
  });

  testWidgets('detects child Positioned outside Stack bounds (Clip.none)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        Center(
          child: SizedBox(
            width: 100,
            height: 40,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  right: -60,
                  top: 0,
                  child: RaftButton(
                    key: const ValueKey('escaped-btn'),
                    label: 'Outside',
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final report = await auditHitTests(
      tester,
      surface: 'escaped-stack',
      options: const HitTestAuditOptions(probeHoverStability: false),
    );
    expect(report.probedControls, 1);
    expect(
      report.findings.where((f) => f.kind == HitTestIssueKind.occluded),
      isNotEmpty,
    );
  });

  testWidgets('detects foreground painter occluding right side of a control', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 240,
          height: 100,
          child: CustomPaint(
            foregroundPainter: _RightHalfBlockerPainter(),
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: RaftButton(
                  key: const ValueKey('scrollbar-blocked-btn'),
                  label: 'Copy',
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final report = await auditHitTests(
      tester,
      surface: 'foreground-painter-blocker',
      options: const HitTestAuditOptions(probeHoverStability: false),
    );
    expect(report.probedControls, 1);
    expect(
      report.findings.where(
        (f) =>
            f.kind == HitTestIssueKind.occluded &&
            f.occluder.contains('RenderCustomPaint'),
      ),
      isNotEmpty,
    );
  });

  testWidgets('detects hover-unstable control that loses hit-test on hover', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        const Padding(
          padding: EdgeInsets.all(24),
          child: _HoverDisappearingButton(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final report = await auditHitTests(tester, surface: 'hover-unstable');
    expect(report.probedControls, 1);
    expect(
      report.findings.where((f) => f.kind == HitTestIssueKind.hoverUnstable),
      isNotEmpty,
    );
  });
}
