import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// Web Modal scrolls the padded card within a full-window scrollport: a card
// taller than the screen is visible and hittable up to the window edge.
void main() {
  for (final dark in [false, true]) {
    testWidgets('framed tall form uses the full viewport dark=$dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      var pressed = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: dark, platform: TargetPlatform.linux),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showRaftForm<void>(
                  context,
                  guardUnsaved: false,
                  builder: (_) => RaftDialog.agent(
                    title: 'Create Agent',
                    onClose: () {},
                    footerGap: 4,
                    children: [const SizedBox(height: 672)],
                    footer: RaftAgentDialogFooter(
                      children: [
                        RaftAgentDialogButton(
                          key: const Key('submit'),
                          label: 'Create Agent',
                          primary: true,
                          onPressed: () => pressed++,
                        ),
                      ],
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final surface = find.byType(RaftDialogSurface);
      final button = find.byKey(const Key('submit'));
      final surfaceRect = tester.getRect(surface);
      final buttonRect = tester.getRect(button);
      expect(surfaceRect.top, 16);
      expect(buttonRect.top, lessThan(790));
      expect(buttonRect.bottom, greaterThan(790));
      await tester.tapAt(Offset(buttonRect.center.dx, 790));
      await tester.pump();
      expect(pressed, 1);
      // The Web scrollport includes the backdrop as well as the card.
      await tester.dragFrom(const Offset(40, 400), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(tester.getRect(surface).top, lessThan(surfaceRect.top));
      expect(find.byKey(const Key('submit')).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('changing text scale retains the form input and focus', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    final scale = ValueNotifier<double>(1);
    addTearDown(scale.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(platform: TargetPlatform.linux),
        builder: (context, child) => ValueListenableBuilder<double>(
          valueListenable: scale,
          builder: (context, value, _) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(value)),
            child: child!,
          ),
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showRaftForm<void>(
                context,
                guardUnsaved: false,
                builder: (_) => RaftDialog.card(
                  title: 'Edit',
                  onClose: () {},
                  child: const TextField(key: Key('input')),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('input')));
    await tester.enterText(find.byKey(const Key('input')), 'retained input');
    final editable = find.byType(EditableText);
    final state = tester.state<EditableTextState>(editable);
    expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isTrue);
    scale.value = 1.3;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.state<EditableTextState>(editable), same(state));
    expect(
      tester.widget<EditableText>(editable).controller.text,
      'retained input',
    );
    expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isTrue);
    scale.value = 1;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.state<EditableTextState>(editable), same(state));
    expect(
      tester.widget<EditableText>(editable).controller.text,
      'retained input',
    );
    expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });
}
