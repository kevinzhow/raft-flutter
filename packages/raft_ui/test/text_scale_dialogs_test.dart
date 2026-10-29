// Dialogs, banners and attachment cards under large text sizes: content
// reflows (wraps, stacks, scrolls), actions stay on screen, and the default
// text size keeps its layout.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Future<void> _pump(
  WidgetTester t,
  double factor,
  Widget home, {
  Size view = const Size(390, 844),
}) async {
  t.view.physicalSize = view;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = factor;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      builder: (context, child) => RaftTextScaling(child: child!),
      home: home,
    ),
  );
}

void main() {
  group('RaftSosDialog', () {
    Widget sos() => Scaffold(
      body: Center(
        child: RaftSosDialog(
          channelName: 'release',
          onStop: () async => null,
          onResume: (_) async => null,
          onClose: () {},
        ),
      ),
    );

    testWidgets('keeps its height at the default text size', (t) async {
      await _pump(t, 1.0, sos(), view: const Size(390, 500));
      expect(t.takeException(), isNull);
      final scroll = find.descendant(
        of: find.byType(RaftSosDialog),
        matching: find.byType(Scrollable),
      );
      expect(scroll, findsOneWidget);
      expect(t.state<ScrollableState>(scroll).position.maxScrollExtent, 0);
      expect(
        find.byKey(const ValueKey('sos-stop')).hitTestable(),
        findsOneWidget,
      );
    });

    testWidgets('large text caps the card, scrolls the body, pins actions', (
      t,
    ) async {
      await _pump(t, 3.1, sos(), view: const Size(390, 500));
      expect(t.takeException(), isNull);
      final card = t.getRect(find.byType(RaftDialogSurface));
      expect(card.height, lessThanOrEqualTo(500 - 32));
      final scroll = find.descendant(
        of: find.byType(RaftSosDialog),
        matching: find.byType(SingleChildScrollView),
      );
      expect(scroll, findsOneWidget);
      expect(
        t
            .state<ScrollableState>(find.byType(Scrollable))
            .position
            .maxScrollExtent,
        greaterThan(0),
      );
      for (final key in ['sos-cancel', 'sos-stop']) {
        final r = t.getRect(find.byKey(ValueKey(key)));
        expect(r.bottom, lessThanOrEqualTo(card.bottom), reason: key);
        expect(r.top, greaterThanOrEqualTo(card.top), reason: key);
      }
    });
  });

  group('showRaftDialog / showRaftAlertDialog', () {
    for (final alert in [false, true]) {
      testWidgets('${alert ? 'alert' : 'dialog'} at 3.1x scrolls its body', (
        t,
      ) async {
        await _pump(
          t,
          3.1,
          Scaffold(
            body: Builder(
              builder: (context) => RaftButton(
                label: 'Open',
                onPressed: () => alert
                    ? showRaftAlertDialog(
                        context: context,
                        title: 'Delete channel?',
                        description: 'This cannot be undone. ' * 12,
                        confirmLabel: 'Delete',
                        destructive: true,
                      )
                    : showRaftDialog<void>(
                        context: context,
                        builder: (context) => RaftDialog(
                          title: 'Review changes',
                          content: RaftDialogDescription(
                            'Review the pending changes before continuing. ' *
                                12,
                          ),
                          actions: [
                            RaftButton(label: 'Cancel', onPressed: () {}),
                            RaftButton(label: 'Confirm', onPressed: () {}),
                          ],
                        ),
                      ),
              ),
            ),
          ),
          view: const Size(390, 600),
        );
        await t.tap(find.text('Open'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        final dialog = t.getRect(find.byType(RaftDialog));
        expect(dialog.top, greaterThanOrEqualTo(0));
        expect(dialog.bottom, lessThanOrEqualTo(600));
        final scroll = find.descendant(
          of: find.byType(RaftDialog),
          matching: find.byType(Scrollable),
        );
        expect(scroll, findsOneWidget);
        expect(
          t.state<ScrollableState>(scroll).position.maxScrollExtent,
          greaterThan(0),
        );
        final action = t.getRect(find.byType(RaftButton).last);
        expect(action.bottom, lessThanOrEqualTo(dialog.bottom));
      });
    }
  });

  group('RaftFormDialog', () {
    testWidgets('large text keeps actions reachable and does not overflow', (
      t,
    ) async {
      var submitted = false;
      await _pump(
        t,
        3.1,
        Scaffold(
          body: Builder(
            builder: (context) => RaftButton(
              label: 'Open',
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => RaftFormDialog(
                  title: 'Rename channel',
                  description: 'Pick a name teammates will recognise.',
                  fields: const [
                    RaftFormField('name', 'Name', initial: 'release'),
                    RaftFormField('topic', 'Topic', multiline: true),
                  ],
                  submitLabel: 'Save',
                  onSubmit: (_) async {
                    submitted = true;
                  },
                ),
              ),
            ),
          ),
        ),
        view: const Size(390, 600),
      );
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final dialog = t.getRect(find.byType(RaftDialogSurface));
      expect(dialog.bottom, lessThanOrEqualTo(600));
      expect(
        find.descendant(
          of: find.byType(RaftDialogSurface),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
      expect(
        t.getRect(find.byType(RaftButton).last).bottom,
        lessThanOrEqualTo(600),
      );
      expect(find.text('Save').hitTestable(), findsOneWidget);
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(submitted, isTrue);
    });
  });

  group('RaftAttachmentCard', () {
    Widget card() => Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: RaftAttachmentCard(
          filename: 'report.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 5242880,
          onOpen: () {},
        ),
      ),
    );

    testWidgets('is 176x80 at the default text size', (t) async {
      await _pump(t, 1.0, card());
      expect(t.takeException(), isNull);
      expect(t.getSize(find.byType(RaftAttachmentCard)), const Size(176, 80));
    });

    testWidgets('grows with the text and does not cut the file type', (
      t,
    ) async {
      await _pump(t, 3.1, card());
      expect(t.takeException(), isNull);
      final size = t.getSize(find.byType(RaftAttachmentCard));
      expect(size.width, greaterThan(176));
      expect(size.width, lessThanOrEqualTo(390));
      expect(size.height, greaterThan(80));
      final badge = t.getRect(find.byType(RaftFileTypeBadge));
      final label = t.getRect(find.text('PDF'));
      expect(badge.height, greaterThanOrEqualTo(label.height));
      expect(badge.width, greaterThanOrEqualTo(label.width));
    });
  });

  group('RaftPreviewTransferStage', () {
    testWidgets('scrolls instead of overflowing at large text', (t) async {
      final progress = ValueNotifier<RaftTransferProgress?>(
        const RaftTransferProgress(received: 1782579, total: 2936012),
      );
      addTearDown(progress.dispose);
      await _pump(
        t,
        3.1,
        Scaffold(
          body: RaftPreviewTransferStage(
            filename: '2026Q3-report.pdf',
            meta: 'PDF · 2.8 MB',
            progress: progress,
            onCancel: () {},
          ),
        ),
        view: const Size(390, 500),
      );
      expect(t.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  });

  group('RaftFileTransferPanel', () {
    Widget panel() {
      final progress = ValueNotifier<RaftTransferProgress?>(
        const RaftTransferProgress(received: 1782579, total: 2936012),
      );
      addTearDown(progress.dispose);
      return Scaffold(
        body: SingleChildScrollView(
          child: Center(
            child: RaftFileTransferPanel(
              filename: '2026Q3-report.pdf',
              meta: 'PDF · 2.8 MB',
              progress: progress,
              onCancel: () {},
            ),
          ),
        ),
      );
    }

    testWidgets('size line and Cancel share a row at the default size', (
      t,
    ) async {
      await _pump(t, 1.0, panel());
      expect(t.takeException(), isNull);
      final cancel = t.getRect(find.text('Cancel'));
      final size = t.getRect(find.textContaining('MB ·'));
      expect((cancel.center.dy - size.center.dy).abs(), lessThan(12));
    });

    testWidgets('Cancel stacks under the size line at large text', (t) async {
      await _pump(t, 3.1, panel());
      expect(t.takeException(), isNull);
      final cancel = t.getRect(find.text('Cancel'));
      final size = t.getRect(find.textContaining('MB ·').last);
      expect(cancel.top, greaterThanOrEqualTo(size.bottom));
    });
  });
}
