// Web v1.24 ArtifactContentSlot (MainLayout.tsx, ArtifactActivityViewer.tsx):
// an Artifact opened from its Activity row or a Search hit shows its viewer in
// the detail area beside the list on wide windows, as a conversation row does
// (`?open=artifact:<id>`), never over the whole window. Its row stays
// selected, its × and Escape close it and focus goes back to the row, another
// row replaces it, leaving the list closes it, and with Artifacts off nothing
// opens. On a phone it is a page pushed over the list.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/artifacts/artifact_comments_panel.dart'
    show ArtifactCommentsPanel;
import 'package:raft_flutter/features/artifacts/artifact_models.dart';
import 'package:raft_flutter/features/artifacts/artifact_viewer_page.dart';
import 'package:raft_flutter/features/quick_switcher.dart' show QuickSwitcher;
import 'package:raft_ui/raft_ui.dart';

import 'app_global_server_selector_test.dart' show RootFixture;
import 'support/artifact_fake_client.dart';

const _second = 'pt_00000000-0000-4000-8000-000000000002';

Map<String, Object?> _row(
  String id,
  String title, {
  Map<String, Object?>? target,
}) => {
  'kind': 'object',
  'objectKind': 'artifact',
  'objectId': id,
  'summary': {'title': title, 'kind': 'markdown', 'latestVersion': 3},
  'home': {'kind': 'channel', 'label': 'general-a', 'channelId': 'ca'},
  'latestEvent': {
    'eventKind': 'version',
    'reason': 'following',
    'actor': {'type': 'user', 'id': 'u2', 'name': 'Judith'},
    'at': '2026-11-17T15:20:00Z',
  },
  'target': target,
  'unreadCount': 0,
  'hasMention': false,
  'isFollowing': true,
  'lastActivityAt': '2026-11-17T15:20:00Z',
  'doneFrontierSeq': '9',
};

RootFixture artifactListFixture({bool artifacts = true, bool search = false}) {
  final fixture = RootFixture();
  fixture.overrides['POST /feature-flags/evaluate'] = (_) => {
    'evaluations': [
      {'key': 'workspace_artifacts_v0', 'enabled': artifacts},
    ],
  };
  fixture.overrides['GET /channels/inbox'] = (_) => {
    'items': [
      _row(artifactId, 'Launch plan', target: {'version': 2}),
      _row(_second, 'Second plan', target: {'comment': 'comment-1'}),
    ],
    'hasMore': false,
    'totalUnreadCount': 0,
  };
  for (final (id, title) in [
    (artifactId, 'Launch plan'),
    (_second, 'Second plan'),
  ]) {
    final card = artifactCardJson(
      id: id,
      title: title,
      kind: 'markdown',
      latest: 3,
    );
    fixture.overrides['GET /artifacts/$id'] = (_) => artifactViewerJson(
      card: card,
      frame: false,
      versions: const [1, 2, 3],
      files: [
        {'path': 'plan.md', 'kind': 'markdown', 'entry': true},
      ],
    );
  }
  fixture.overrides['GET /artifacts/$artifactId/files/plan.md'] = (_) =>
      ResponseBody.fromString(
        '# Plan',
        200,
        headers: {
          Headers.contentTypeHeader: ['text/markdown; charset=utf-8'],
        },
      );
  if (search) {
    fixture.overrides['GET /search'] = (_) => {
      'groups': [
        {
          'app': 'artifacts',
          'items': [
            {
              'card': {
                'id': artifactId,
                'title': 'Launch plan',
                'kind': 'markdown',
              },
              'matches': [],
            },
          ],
        },
      ],
    };
    fixture.overrides['GET /messages/search'] = (_) => {
      'results': [],
      'hasMore': false,
    };
  }
  return fixture;
}

Finder _row1() => find.byKey(const ValueKey('activity-object-$artifactId'));
Finder _row2() => find.byKey(const ValueKey('activity-object-$_second'));
final _viewer = find.byType(ArtifactWorkspaceViewer);

bool _selected(WidgetTester t, Finder row) =>
    t.widget<RaftInboxItem>(row).selected;

/// The viewer is painted inside the workspace's page, not on a route over it.
void _beside(WidgetTester t, Finder row) {
  expect(_viewer, findsOneWidget);
  final route = ModalRoute.of(t.element(_viewer));
  expect(route, isNot(isA<RaftFullBleedDialogRoute<void>>()));
  expect(route, isNot(isA<RaftPreviewPageRoute<void>>()));
  expect(row.hitTestable(), findsOneWidget, reason: 'the list stays');
  expect(
    t.getRect(_viewer).left,
    greaterThanOrEqualTo(t.getRect(row).right - 1),
  );
}

bool _focusIn(Finder finder) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return false;
  final target = finder.evaluate().single;
  var inside = identical(focused, target);
  focused.visitAncestorElements((e) {
    if (identical(e, target)) inside = true;
    return !inside;
  });
  return inside;
}

void main() {
  for (final escape in [false, true]) {
    testWidgets('Activity wide: an Artifact row opens beside the list, '
        '${escape ? 'Escape' : '×'} closes it back to its row', (t) async {
      final fixture = artifactListFixture();
      await fixture.mount(
        t,
        'light',
        1280,
        uri: Uri.parse('/s/alpha/activity'),
      );
      final w = fixture.workspace(t);
      expect(_row1(), findsOneWidget);
      await t.tap(_row1());
      await fixture.flush(t);
      _beside(t, _row1());
      expect(w.location.route, RaftRoute.activity);
      expect(w.location.query('artifact'), artifactShort);
      expect(w.location.query('open'), isNull);
      expect(w.location.query('version'), '2');
      expect(
        t.widget<ArtifactWorkspaceViewer>(_viewer).target,
        const ArtifactLinkTarget.activity(artifactId, 2),
      );
      expect(_selected(t, _row1()), isTrue);
      expect(_selected(t, _row2()), isFalse);

      if (escape) {
        expect(_focusIn(_viewer), isTrue);
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
      } else {
        await t.tap(
          find.byKey(const ValueKey('artifact-viewer-close')).hitTestable(),
        );
      }
      await fixture.flush(t);
      expect(_viewer, findsNothing);
      expect(w.location.query('artifact'), isNull);
      expect(w.location.query('version'), isNull);
      expect(_selected(t, _row1()), isFalse);
      expect(_focusIn(_row1()), isTrue);
      await fixture.close(t);
    });
  }

  testWidgets('Activity wide: another row replaces the viewer; leaving '
      'Activity closes it', (t) async {
    final fixture = artifactListFixture();
    await fixture.mount(t, 'dark', 1280, uri: Uri.parse('/s/alpha/activity'));
    final w = fixture.workspace(t);
    await t.tap(_row1());
    await fixture.flush(t);
    await t.tap(_row2());
    await fixture.flush(t);
    _beside(t, _row2());
    expect(w.location.query('artifact'), isNot(artifactShort));
    expect(w.location.query('artifact'), isNotNull);
    expect(w.location.query('version'), isNull);
    // The comment the row is about is the opening's, not the address's.
    expect(
      t.widget<ArtifactWorkspaceViewer>(_viewer).target,
      const ArtifactLinkTarget.activity(_second, null, commentId: 'comment-1'),
    );
    expect(w.location.query('msg'), isNull);
    // Web `fit="measure"`: the list it lands in is over the Artifact inside
    // the slot, not a sheet over the window.
    expect(
      find.descendant(
        of: _viewer,
        matching: find.byType(ArtifactCommentsPanel),
      ),
      findsOneWidget,
    );
    expect(_selected(t, _row1()), isFalse);
    expect(_selected(t, _row2()), isTrue);

    await t.tap(find.byKey(const Key('rail-chat')));
    await fixture.flush(t);
    expect(_viewer, findsNothing);
    expect(w.location.query('artifact'), isNull);
    await fixture.close(t);
  });

  testWidgets('Activity wide with Artifacts off: a row opens nothing', (
    t,
  ) async {
    final fixture = artifactListFixture(artifacts: false);
    await fixture.mount(t, 'light', 1280, uri: Uri.parse('/s/alpha/activity'));
    if (_row1().evaluate().isNotEmpty) {
      await t.tap(_row1());
      await fixture.flush(t);
    }
    expect(_viewer, findsNothing);
    expect(_row1().hitTestable(), findsOneWidget, reason: 'nothing covers it');
    await fixture.close(t);
  });

  testWidgets('Activity phone: an Artifact row is a page over the list at '
      'its address; Back returns to the list', (t) async {
    final fixture = artifactListFixture();
    await fixture.mount(t, 'light', 390, uri: Uri.parse('/s/alpha/activity'));
    final w = fixture.workspace(t);
    await t.tap(_row1());
    await fixture.flush(t);
    await t.pumpAndSettle();
    expect(_viewer.hitTestable(), findsOneWidget);
    final route = ModalRoute.of(t.element(_viewer));
    expect(route, isNot(isA<RaftFullBleedDialogRoute<void>>()));
    expect(route, isNot(isA<RaftPreviewPageRoute<void>>()));
    expect(_row1().hitTestable(), findsNothing, reason: 'a page over it');
    expect(w.location.route, RaftRoute.activity);
    expect(w.location.query('artifact'), artifactShort);
    expect(t.widget<ArtifactWorkspaceViewer>(_viewer).page, isTrue);

    await t.tap(
      find.byKey(const ValueKey('artifact-viewer-close')).hitTestable(),
    );
    await fixture.flush(t);
    await t.pumpAndSettle();
    expect(_viewer, findsNothing);
    expect(w.location.query('artifact'), isNull);
    expect(_row1().hitTestable(), findsOneWidget);
    await fixture.close(t);
  });

  for (final width in [1280.0, 390.0]) {
    testWidgets('an Artifact address opens it on a cold start at $width', (
      t,
    ) async {
      final fixture = artifactListFixture();
      await fixture.mount(
        t,
        'light',
        width,
        uri: Uri.parse('/s/alpha/activity?artifact=$artifactShort&version=2'),
      );
      await t.pumpAndSettle();
      expect(_viewer.hitTestable(), findsOneWidget);
      expect(
        t.widget<ArtifactWorkspaceViewer>(_viewer).target,
        const ArtifactLinkTarget.activity(artifactId, 2),
      );
      if (width > 1000) _beside(t, _row1());
      await fixture.close(t);
    });
  }

  testWidgets('Search wide: an Artifact hit opens beside the results and '
      'stays selected', (t) async {
    final fixture = artifactListFixture(search: true);
    await fixture.mount(
      t,
      'light',
      1280,
      uri: Uri.parse('/s/alpha/search?q=plan'),
    );
    final w = fixture.workspace(t);
    await t.pump(const Duration(milliseconds: 250));
    await fixture.flush(t);
    final hit = find.byKey(const ValueKey('app:artifacts:$artifactId'));
    expect(hit, findsOneWidget);
    await t.tap(hit);
    await fixture.flush(t);
    _beside(t, hit);
    expect(w.location.route, RaftRoute.search);
    expect(w.location.query('artifact'), artifactShort);
    expect(t.widget<RaftSearchResultSurface>(hit).selected, isTrue);

    await t.tap(
      find.byKey(const ValueKey('artifact-viewer-close')).hitTestable(),
    );
    await fixture.flush(t);
    expect(_viewer, findsNothing);
    expect(w.location.query('artifact'), isNull);
    expect(hit.hitTestable(), findsOneWidget);
    await fixture.close(t);
  });
  testWidgets('quick switcher wide: an Artifact hit opens on the Search page '
      'beside its results', (t) async {
    final fixture = artifactListFixture(search: true);
    await fixture.mount(t, 'light', 1280, uri: Uri.parse('/s/alpha/activity'));
    final w = fixture.workspace(t);
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.keyK);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await fixture.flush(t);
    expect(find.byType(QuickSwitcher), findsOneWidget);
    await t.enterText(
      find.descendant(
        of: find.byType(QuickSwitcher),
        matching: find.byType(TextField),
      ),
      'plan',
    );
    await t.pump(const Duration(milliseconds: 250));
    await fixture.flush(t);
    final hit = find.descendant(
      of: find.byType(QuickSwitcher),
      matching: find.byKey(const ValueKey('app:artifacts:$artifactId')),
    );
    expect(hit, findsOneWidget);
    await t.tap(hit);
    await fixture.flush(t);
    await t.pumpAndSettle();
    expect(find.byType(QuickSwitcher), findsNothing);
    expect(w.location.route, RaftRoute.search);
    expect(w.location.query('artifact'), artifactShort);
    _beside(t, find.byKey(const ValueKey('app:artifacts:$artifactId')).first);
    await fixture.close(t);
  });
}
