import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_ui/raft_ui.dart';

import 'mobile_computer_navigation_test.dart'
    show fixture, computer, finishPageAnimation, loadComputerPageFonts;

class _DeleteFixture {
  _DeleteFixture() {
    f.overrides['GET /servers/a/machines'] = (_) => {
      'machines': [if (!deleted) computer, remaining],
    };
    f.overrides['GET /servers/b/machines'] = (_) => {
      'machines': [
        {...remaining, 'id': 'beta-computer', 'name': 'Beta computer'},
      ],
    };
    f.overrides['DELETE /servers/a/machines/computer-a'] = (_) async {
      deletes++;
      if (pending != null) await pending!.future;
      final failed = failures > 0;
      if (failed) failures--;
      f.adapter.statuses['DELETE /servers/a/machines/computer-a'] = failed
          ? 500
          : 200;
      if (failed) return {'error': 'Computer removal failed'};
      deleted = true;
      return <String, dynamic>{};
    };
  }

  final f = fixture();
  final remaining = <String, dynamic>{
    ...computer,
    'id': 'computer-b',
    'name': 'Remaining computer',
  };
  bool deleted = false;
  int deletes = 0, failures = 0;
  Completer<void>? pending;

  Future<void> open(WidgetTester t, {String theme = 'light'}) async {
    await loadComputerPageFonts(t);
    await f.mount(t, theme, 390, uri: Uri.parse('/s/alpha/settings'));
    addTearDown(() => f.close(t));
    addTearDown(() {
      if (pending?.isCompleted == false) pending!.complete();
    });
    await t.ensureVisible(find.text('Computers'));
    await t.tap(find.text('Computers'));
    await f.flush(t);
    final first = find.byKey(const ValueKey('fleet-computer-a'));
    await finishPageAnimation(t, first);
    // This is the production inner page Navigator plus the root Navigator
    // that will own the confirmation, not a callback-only detail harness.
    final context = t.element(first);
    expect(
      identical(
        Navigator.of(context),
        Navigator.of(context, rootNavigator: true),
      ),
      isFalse,
    );
    await t.tap(first);
    await f.flush(t);
    await finishPageAnimation(t, find.byKey(const Key('computer-mobile-back')));
    await t.ensureVisible(find.byKey(const ValueKey('computer-delete')));
    await t.tap(find.byKey(const ValueKey('computer-delete')));
    await f.flush(t);
  }

  Finder get confirm => find
      .descendant(
        of: find.byType(RaftConfirmDialog),
        matching: find.text('Delete Computer'),
      )
      .last;

  Future<void> submit(WidgetTester t) async {
    await t.tap(confirm);
    await f.flush(t);
  }

  Future<void> expectUsableList(WidgetTester t) async {
    await t.pumpAndSettle();
    expect(f.workspace(t).location.route, RaftRoute.computers);
    expect(find.byType(RaftConfirmDialog), findsNothing);
    expect(find.byType(RaftMobileComputerList), findsOneWidget);
    expect(find.byKey(const ValueKey('fleet-computer-a')), findsNothing);
    final next = find.byKey(const ValueKey('fleet-computer-b'));
    expect(next.hitTestable(), findsOneWidget);
    await t.tap(next);
    await f.flush(t);
    expect(f.workspace(t).location.entityId, 'computer-b');
    expect(t.takeException(), isNull);
  }
}

void main() {
  testWidgets('standalone FleetDetail deletion preserves a newer destination', (
    t,
  ) async {
    final h = _DeleteFixture()..pending = Completer<void>();
    await loadComputerPageFonts(t);
    await h.f.mount(t, 'light', 390, uri: Uri.parse('/s/alpha/computers'));
    addTearDown(() => h.f.close(t));
    addTearDown(() {
      if (!h.pending!.isCompleted) h.pending!.complete();
    });
    final w = h.f.workspace(t);
    final navigator = Navigator.of(
      t.element(find.byType(RaftMobileComputerList)),
      rootNavigator: true,
    );
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            // With no onOpenDetail, this actual FleetView opens its production
            // standalone FleetDetail route without an onClose callback.
            body: FleetView(controller: w, computers: true),
          ),
        ),
      ),
    );
    await h.f.flush(t);
    final first = find.byKey(const ValueKey('fleet-computer-a')).last;
    await finishPageAnimation(t, first);
    await t.tap(first);
    await h.f.flush(t);
    await finishPageAnimation(t, find.byKey(const Key('computer-mobile-back')));
    final detail = t.widget<FleetDetail>(find.byType(FleetDetail));
    expect(detail.onClose, isNull);
    await t.ensureVisible(find.byKey(const ValueKey('computer-delete')));
    await t.tap(find.byKey(const ValueKey('computer-delete')));
    await h.f.flush(t);
    await h.submit(t);
    expect(h.deletes, 1);
    var newerActions = 0;
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            body: ElevatedButton(
              onPressed: () => newerActions++,
              child: const Text('New same-server destination'),
            ),
          ),
        ),
      ),
    );
    await h.f.flush(t);
    h.pending!.complete();
    await h.f.flush(t);
    await t.pump(const Duration(milliseconds: 500));
    expect(w.services.entityDirectory.computer('computer-a'), isNull);
    final newer = find.text('New same-server destination').hitTestable();
    expect(newer, findsOneWidget);
    expect(find.byType(FleetDetail, skipOffstage: false), findsNothing);
    expect(find.byType(RaftConfirmDialog, skipOffstage: false), findsNothing);
    await t.tap(newer);
    expect(newerActions, 1);
    navigator.pop();
    await h.f.flush(t);
    await t.pump(const Duration(milliseconds: 500));
    expect(
      find.byKey(const ValueKey('fleet-computer-b')).hitTestable(),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('a late confirmation cannot pop a newer destination', (t) async {
    final pending = Completer<void>();
    addTearDown(() async {
      if (!pending.isCompleted) pending.complete();
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
    });
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => unawaited(
                RaftConfirmDialog.show(
                  context,
                  RaftConfirmDialog(
                    title: 'Delete fixture',
                    confirmLabel: 'Run fixture',
                    onConfirm: () => pending.future,
                  ),
                ),
              ),
              child: const Text('Preserved root'),
            ),
          ),
        ),
      ),
    );
    final navigator = Navigator.of(t.element(find.text('Preserved root')));
    await t.tap(find.text('Preserved root'));
    await t.pumpAndSettle();
    await t.tap(find.text('Run fixture'));
    await t.pump();
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('New destination')),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 500));
    pending.complete();
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('New destination').hitTestable(), findsOneWidget);
    expect(find.byType(RaftConfirmDialog, skipOffstage: false), findsNothing);
    expect(t.takeException(), isNull);
  });

  for (final theme in ['light', 'dark']) {
    testWidgets('$theme deleting a computer returns once to its usable list', (
      t,
    ) async {
      final h = _DeleteFixture();
      await h.open(t, theme: theme);
      await h.submit(t);
      expect(h.deletes, 1);
      expect(h.deleted, isTrue);
      await h.expectUsableList(t);
    });
  }

  testWidgets('a failed deletion stays on detail and can succeed on retry', (
    t,
  ) async {
    final h = _DeleteFixture()..failures = 1;
    await h.open(t);
    await h.submit(t);
    expect(h.deletes, 1);
    expect(h.deleted, isFalse);
    expect(h.f.workspace(t).location.entityId, 'computer-a');
    expect(find.byType(RaftConfirmDialog), findsOneWidget);
    expect(find.text('Computer removal failed'), findsOneWidget);
    expect(h.confirm.hitTestable(), findsOneWidget);
    await h.submit(t);
    expect(h.deletes, 2);
    expect(find.text('Computer removal failed'), findsNothing);
    await h.expectUsableList(t);
  });

  testWidgets('cancelling deletion preserves detail and makes no DELETE', (
    t,
  ) async {
    final h = _DeleteFixture();
    await h.open(t);
    await t.tap(find.text('Keep Computer'));
    await h.f.flush(t);
    expect(h.deletes, 0);
    expect(h.deleted, isFalse);
    expect(h.f.workspace(t).location.entityId, 'computer-a');
    expect(find.byKey(const Key('computer-mobile-back')), findsOneWidget);
    await t.tap(find.byKey(const Key('computer-mobile-back')));
    await h.f.flush(t);
    expect(h.f.workspace(t).location.route, RaftRoute.computers);
    expect(find.byKey(const ValueKey('fleet-computer-a')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'directory removal before DELETE reply closes only owned routes',
    (t) async {
      final h = _DeleteFixture()..pending = Completer<void>();
      await h.open(t);
      await h.submit(t);
      expect(h.deletes, 1);
      h.deleted = true;
      final refreshed = h.f
          .workspace(t)
          .services
          .entityDirectory
          .refresh(WorkspaceEntityKind.computers, force: true);
      await h.f.flush(t);
      await refreshed;
      await t.pumpAndSettle();
      expect(find.byType(RaftConfirmDialog), findsNothing);
      expect(h.f.workspace(t).location.route, RaftRoute.computers);
      h.pending!.complete();
      await h.f.flush(t);
      await h.expectUsableList(t);
    },
  );

  testWidgets('a computer disappearing before confirmation cannot be deleted', (
    t,
  ) async {
    final h = _DeleteFixture();
    await h.open(t);
    final retained = t.widget<RaftConfirmDialog>(
      find.byType(RaftConfirmDialog),
    );
    h.deleted = true;
    final refreshed = h.f
        .workspace(t)
        .services
        .entityDirectory
        .refresh(WorkspaceEntityKind.computers, force: true);
    await h.f.flush(t);
    await refreshed;
    await retained.onConfirm!();
    expect(h.deletes, 0);
    await h.expectUsableList(t);
  });

  for (final submitted in [false, true]) {
    testWidgets(
      'server switch fences ${submitted ? 'late' : 'retained'} delete',
      (t) async {
        final h = _DeleteFixture()..pending = Completer<void>();
        await h.open(t);
        final retained = t.widget<RaftConfirmDialog>(
          find.byType(RaftConfirmDialog),
        );
        if (submitted) await h.submit(t);
        await h.f.pushUri(t, '/s/beta/computers');
        await h.f.flush(t);
        await t.pumpAndSettle();
        expect(h.f.workspace(t).client.serverId, 'b');
        expect(find.byType(RaftConfirmDialog), findsNothing);
        if (submitted) {
          h.pending!.complete();
        } else {
          await retained.onConfirm!();
        }
        await h.f.flush(t);
        await t.pumpAndSettle();
        expect(h.deletes, submitted ? 1 : 0);
        expect(h.f.workspace(t).location.route, RaftRoute.computers);
        expect(h.f.workspace(t).location.serverSlug, 'beta');
        expect(
          find.byKey(const ValueKey('fleet-beta-computer')).hitTestable(),
          findsOneWidget,
        );
        expect(t.takeException(), isNull);
      },
    );
  }
}
