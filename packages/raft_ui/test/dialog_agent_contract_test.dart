import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Future<void> open(
  WidgetTester t, {
  required bool agent,
  bool poisoned = false,
}) async {
  t.view.physicalSize = const Size(1280, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  addTearDown(() => t.pumpWidget(const SizedBox()));
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: DefaultTextStyle(
          style: TextStyle(
            fontWeight: poisoned ? FontWeight.w900 : FontWeight.w400,
            decoration: poisoned
                ? TextDecoration.underline
                : TextDecoration.none,
          ),
          child: Builder(
            builder: (context) => RaftButton(
              label: 'Open',
              onPressed: () {
                Widget dialog(BuildContext c) => agent
                    ? RaftAgentDialogCard(
                        title: 'Review agent',
                        onClose: () => Navigator.pop(c),
                        children: const [Text('Body')],
                      )
                    : const RaftDialog(
                        title: 'Review settings',
                        content: Text('Body'),
                      );
                if (agent) {
                  showRaftAgentModal<void>(context, builder: dialog);
                } else {
                  showRaftDialog<void>(context: context, builder: dialog);
                }
              },
            ),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('Open'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('agent dialog adapter uses the same source surface and header', (
    t,
  ) async {
    await open(t, agent: true);
    expect(find.byType(RaftDialogSurface), findsOneWidget);
    final surface = t.getRect(find.byType(RaftDialogSurface));
    final title = t.getRect(find.text('Review agent'));
    expect(title.left - surface.left, 20);
    expect(title.top - surface.top, 20);
    expect(t.widget<Text>(find.text('Review agent')).style!.fontSize, 17);
  });
  testWidgets('agent Modal uses the same motion-free source route', (t) async {
    await open(t, agent: true);
    final route = ModalRoute.of(t.element(find.byType(RaftAgentDialogCard)))!;
    expect(route.transitionDuration, Duration.zero);
  });
  testWidgets('a dialog portal does not inherit a trigger text decoration', (
    t,
  ) async {
    await open(t, agent: false, poisoned: true);
    final title = t.widget<Text>(find.text('Review settings'));
    expect(title.style!.decoration, TextDecoration.none);
    expect(
      DefaultTextStyle.of(t.element(find.text('Body'))).style.fontWeight,
      FontWeight.w400,
    );
  });
}
