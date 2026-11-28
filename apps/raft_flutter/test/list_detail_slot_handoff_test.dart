// #380 review round 1: one detail slot at a time. Opening a task, closing
// it, or Back from a cold start never leaves an Artifact's address
// (`?artifact=`, `&version=`, `&review=`) behind to reappear as another
// column, in the list's slot, or after Back; Escape closes the shell's
// Artifact column before the page under it.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/raft_navigation_history.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_navigation.dart';
import 'package:raft_flutter/features/artifacts/artifact_session.dart';
import 'package:raft_flutter/features/mobile_workspace_pages.dart'
    show backMobilePage;
import 'package:raft_flutter/features/task_content_slot.dart';

import 'support/artifact_fake_client.dart' show artifactShort;
import 'task_content_slot_test.dart' show mountTasks, settle, card;
import 'workspace_source_location_contract_test.dart' show pageFixture;

const _artifactKeys = ['artifact', 'version', 'review'];

void _noArtifact(RaftLocation location) {
  for (final key in _artifactKeys) {
    expect(location.query(key), isNull, reason: '$key left in $location');
  }
}

Future<void> _openArtifactAddress(WidgetTester t, WorkspaceController w) async {
  ArtifactSession.of(w).debugSetEnabled(true);
  w.navigation.navigate(
    w.location.withQuery({
      'artifact': artifactShort,
      'version': '2',
      'review': 'review-1',
    }),
    kind: RaftNavigationKind.replace,
  );
  w.notifyListeners();
  await settle(t);
}

final _shellColumn = find.byKey(const ValueKey('shell-artifact-column'));
final _activityTask = find.byKey(const ValueKey('activity-thread-task-conv'));

void main() {
  for (final size in const [Size(1280, 800), Size(841, 701)]) {
    testWidgets('Activity at ${size.width}: an Artifact then a task row opens '
        'the task alone', (t) async {
      final w = await mountTasks(t, size, section: 'activity');
      await _openArtifactAddress(t, w);
      expect(w.location.content?.kind, RaftContentKind.artifact);
      await t.tap(_activityTask);
      await settle(t);
      expect(w.location.query('open'), 'task:task-1');
      _noArtifact(w.location);
      expect(_shellColumn, findsNothing);
    });
  }

  testWidgets('Tasks page: task A with a shell Artifact, then task B, '
      'leaves no Artifact column', (t) async {
    final w = await mountTasks(t, const Size(1280, 800), twoTasks: true);
    await t.tap(card.hitTestable());
    await settle(t);
    expect(taskSlotId(w.location), 'task-1');
    await _openArtifactAddress(t, w);
    await t.tap(
      find.byKey(const ValueKey('tasks-page-row-cell-task-2')).hitTestable(),
    );
    await settle(t);
    expect(taskSlotId(w.location), 'task-2');
    _noArtifact(w.location);
    expect(_shellColumn, findsNothing);
  });

  testWidgets('closing a task that has a shell Artifact closes both', (
    t,
  ) async {
    final w = await mountTasks(t, const Size(1280, 800), section: 'activity');
    await t.tap(_activityTask);
    await settle(t);
    await _openArtifactAddress(t, w);
    // Focus back in the main area, off the column (a click there).
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(t);
    // Escape first closes the Artifact column, then the task.
    _noArtifact(w.location);
    expect(w.location.query('open'), 'task:task-1');
    await t.tap(find.byKey(const ValueKey('task-modal-close')).hitTestable());
    await settle(t);
    expect(w.location.query('open'), isNull);
    expect(w.location.task, isNull);
    _noArtifact(w.location);
    expect(_shellColumn, findsNothing);
  });

  testWidgets('Tasks page: Escape off the Artifact column closes the column, '
      'not the task under it', (t) async {
    final w = await mountTasks(t, const Size(1280, 800));
    await t.tap(card.hitTestable());
    await settle(t);
    await _openArtifactAddress(t, w);
    expect(_shellColumn, findsOneWidget);
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(t);
    _noArtifact(w.location);
    expect(taskSlotId(w.location), 'task-1');
    expect(_shellColumn, findsNothing);
  });

  testWidgets('closing a task drops an Artifact address left beside it', (
    t,
  ) async {
    final w = await mountTasks(t, const Size(1280, 800), section: 'activity');
    await t.tap(_activityTask);
    await settle(t);
    await _openArtifactAddress(t, w);
    await t.tap(find.byKey(const ValueKey('task-modal-close')).hitTestable());
    await settle(t);
    expect(w.location.query('open'), isNull);
    _noArtifact(w.location);
    expect(_shellColumn, findsNothing);
  });

  testWidgets('phone: an Artifact page, then a task, then Back never brings '
      'the Artifact back', (t) async {
    final (w, _) = await pageFixture(t);
    w.navigation.navigate(
      RaftLocation.parse(
        '/s/demo/activity?artifact=$artifactShort&version=2&review=review-1',
      ),
    );
    final row = {
      'kind': 'task',
      'taskId': 'task-1',
      'parentChannelId': 'c1',
      'threadChannelId': 'task-conv',
    };
    expect(openTaskFromList(w, row, wide: false), isTrue);
    _noArtifact(w.location);
    expect(w.location.task, isNotNull);
    // The phone's Back (the page stack the location derives).
    w.navigation.mobileTabs = const {'chat', 'activity', 'tasks'};
    backMobilePage(w.navigation);
    _noArtifact(w.location);
    expect(w.location.task, isNull);
  });

  group('cold start Back', () {
    test('an Artifact address alone closes', () {
      final navigation = WorkspaceNavigation()
        ..bind(
          'scope',
          RaftLocation.parse(
            '/s/alpha/activity?artifact=$artifactShort&version=2',
          ),
        );
      final next = navigation.back();
      _noArtifact(next);
      expect(next.route, RaftRoute.activity);
      expect(next.content, isNull);
    });

    test('a thread with its shell Artifact closes both', () {
      final navigation = WorkspaceNavigation()
        ..bind(
          'scope',
          RaftLocation.parse(
            '/s/alpha/activity?open=thread:t1&thread=c1:m1'
            '&artifact=$artifactShort',
          ),
        );
      final next = navigation.back();
      _noArtifact(next);
      expect(next.content, isNull);
      expect(next.thread, isNull);
    });
  });
}
