import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/artifacts/artifact_dashboard.dart';
import 'package:raft_flutter/features/artifacts/artifact_open_in_browser.dart';
import 'package:raft_ui/raft_ui.dart';

import '../support/artifact_fake_client.dart';

void main() {
  Future<ArtifactFakeClient> openHome(
    WidgetTester tester, {
    Size size = const Size(1280, 900),
    bool markdown = false,
    bool crossServer = false,
    bool origin = false,
    bool dark = false,
    TargetPlatform platform = TargetPlatform.linux,
    double? collectionWidth,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final client = ArtifactFakeClient();
    addTearDown(client.ingress.close);
    final workspace = WorkspaceController(client)
      ..server = RaftRecord({'id': 's1', 'role': 'owner', 'name': 'Example'});
    addTearDown(workspace.dispose);
    if (origin) {
      workspace.channels = [
        RaftChannel({'id': 'project', 'name': 'project-notes', 'joined': true}),
      ];
      client.answers['GET /messages/context/source-message'] = (_) => {
        'messages': <Object?>[],
      };
    }
    final card = artifactCardJson(
      title: 'Road map',
      kind: markdown ? 'markdown' : 'html',
    )..['fromAnotherServer'] = crossServer;
    client.answers['GET /artifacts/dashboard/all?sort=opened'] = (_) => {
      'rows': [
        {'card': card},
      ],
      'counts': {'total': 1, 'filtered': 1, 'relevant': 0},
    };
    client.answers['GET /artifacts/dashboard/conversations'] = (_) => {
      'conversations': [
        {'id': 'project', 'name': 'Project notes', 'type': 'private'},
      ],
    };
    final viewer = artifactViewerJson(
      card: card,
      frame: false,
      files: markdown
          ? [
              {'path': 'notes.md', 'kind': 'markdown', 'entry': true},
            ]
          : null,
    );
    if (origin) {
      viewer['origin'] = {
        'conversationId': 'project',
        'messageId': 'source-message',
      };
    }
    client.answers['GET /artifacts/$artifactId'] = (_) => viewer;
    client.answers['GET /artifacts/$artifactId/files/notes.md?version=1'] = (
      _,
    ) => '# Launch plan\n\nReview the release.';
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(dark: dark).copyWith(platform: platform),
        builder: (context, child) => RaftTextScaling(child: child!),
        home: Scaffold(
          body: Column(
            children: [
              const Text('Workspace navigation'),
              Expanded(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: collectionWidth ?? double.infinity,
                    height: double.infinity,
                    child: ArtifactDashboard(workspace: workspace),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
    return client;
  }

  final manageDialog = find.byKey(const Key('artifact-manage-dialog'));

  Future<void> chooseViewerAction(WidgetTester tester, String action) async {
    await tester.tap(find.byKey(const Key('artifact-viewer-menu-trigger')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();
  }

  double titleBaseline(WidgetTester tester, String title) {
    final paragraph = tester.renderObject<RenderParagraph>(find.text(title));
    final baseline = paragraph.getDryBaseline(
      paragraph.constraints,
      TextBaseline.alphabetic,
    )!;
    final painted = paragraph.localToGlobal(
      Offset(0, baseline.roundToDouble()),
    );
    return painted.dy - tester.getTopLeft(manageDialog).dy;
  }

  testWidgets('phone can switch between the grid and the list', (tester) async {
    await openHome(tester, size: const Size(390, 844));
    expect(find.byKey(const Key('artifact-grid')), findsOneWidget);
    await tester.tap(find.byKey(const Key('artifacts-view-list')));
    await tester.pumpAndSettle();
    final list = find.byKey(const Key('artifact-list'));
    expect(list, findsOneWidget);
    final avatar = find.descendant(of: list, matching: find.byType(RaftAvatar));
    expect(tester.getSize(avatar), Size.square(RaftAvatarSize.xs.extent));
    final filterStrip = find.ancestor(
      of: find.text('Relevant to me'),
      matching: find.byType(SingleChildScrollView),
    );
    expect(tester.getSize(filterStrip).width, 358);
    final title = tester.getRect(find.text('Road map'));
    final subtitle = tester.getRect(find.text('#general · v1'));
    final author = tester.getRect(find.text('You'));
    expect(subtitle.top - title.bottom, RaftSpace.half);
    expect(author.top - subtitle.bottom, greaterThanOrEqualTo(RaftSpace.x2));
    await tester.tap(find.byKey(const Key('artifacts-view-grid')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('artifact-grid')), findsOneWidget);
  });

  testWidgets(
    'desktop toolbar aligns the filters and uses the picker avatar size',
    (tester) async {
      final client = await openHome(tester);
      client.answers['GET /artifacts/dashboard/authors'] = (_) => {
        'authors': [
          {'id': 'author', 'type': 'user', 'displayName': 'Author name'},
        ],
      };
      expect(
        tester.getTopLeft(find.byType(RaftInputGroup)).dx,
        RaftDesktopMetrics.pageInset,
      );
      expect(
        tester.getSize(find.byKey(const Key('artifacts-view-grid'))).height,
        RaftDesktopMetrics.controlHeight,
      );
      final authorTrigger = find.byKey(const Key('artifacts-filter-author'));
      final anchor = tester.getTopLeft(authorTrigger);
      await tester.tap(authorTrigger);
      await tester.pumpAndSettle();
      final popup = find.byKey(const Key('artifact-dashboard-filter'));
      expect(tester.getTopLeft(popup).dx, anchor.dx.roundToDouble());
      expect(find.text('Author name'), findsOneWidget);
      final avatar = find.descendant(
        of: popup,
        matching: find.byType(RaftAvatar),
      );
      expect(tester.getSize(avatar), Size.square(RaftAvatarSize.xxxs.extent));
    },
  );

  testWidgets(
    'conversation picker opens below its trigger and Escape closes it',
    (tester) async {
      await openHome(tester);
      final trigger = find.text('By conversation');
      final origin = tester.getRect(trigger);
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      final popup = find.byKey(const Key('artifact-dashboard-filter'));
      expect(tester.getTopLeft(popup).dx, closeTo(origin.left, 30));
      expect(tester.getTopLeft(popup).dy, closeTo(origin.bottom, 26));
      expect(find.text('Everyone in Example'), findsOneWidget);
      expect(
        find.descendant(
          of: popup,
          matching: find.byWidgetPredicate(
            (widget) => widget is RaftIcon && widget.glyph == RaftGlyph.lock,
          ),
        ),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(popup, findsNothing);
    },
  );

  group('conversation picker query', () {
    const route = 'GET /artifacts/dashboard/conversations';
    final trigger = find.byKey(const Key('artifacts-filter-conversation'));
    final popup = find.byKey(const Key('artifact-dashboard-filter'));
    final input = find.descendant(
      of: popup,
      matching: find.byType(EditableText),
    );

    Map<String, Object> response(List<Map<String, String>> rows) => {
      'conversations': rows,
    };

    testWidgets('filters known rows through debounce and pending', (
      tester,
    ) async {
      final client = await openHome(tester, size: const Size(390, 844));
      final search = Completer<Object>();
      final next = Completer<Object>();
      const searchRoute = '$route?q=%23PrOj';
      client.answers[route] = (_) => response([
        {'id': 'general', 'name': 'General'},
        {'id': 'project', 'name': 'Project notes'},
        {
          'id': 'dm',
          'name': 'DM thread',
          'type': 'dm',
          'peerDisplayName': 'Project partner',
        },
        {
          'id': 'dm-name',
          'name': 'Project relay',
          'type': 'dm',
          'peerDisplayName': 'Casey',
        },
      ]);
      client.answers[searchRoute] = (_) => search.future;
      client.answers['$route?q=project+n'] = (_) => next.future;
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      expect(find.text('General'), findsOneWidget);
      expect(tester.widget<EditableText>(input).focusNode.hasFocus, isTrue);

      await tester.enterText(input, '  #PrOj  ');
      await tester.pump();
      expect(client.requests, isNot(contains(searchRoute)));
      expect(find.text('General'), findsNothing);
      expect(find.text('Anyone with the link'), findsNothing);
      expect(find.text('Project notes'), findsOneWidget);
      expect(find.text('Project partner'), findsOneWidget);
      expect(find.text('Casey'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(client.requests, contains(searchRoute));
      expect(find.text('Project notes'), findsOneWidget);
      expect(find.text('Project partner'), findsOneWidget);
      expect(tester.widget<EditableText>(input).focusNode.hasFocus, isTrue);

      search.complete(
        response([
          {'id': 'server-only', 'name': 'Server result'},
          {'id': 'new', 'name': 'Project new'},
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Project notes'), findsNothing);
      expect(find.text('Project partner'), findsNothing);
      expect(find.text('Casey'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Server result')).dy,
        lessThan(tester.getTopLeft(find.text('Project new')).dy),
      );
      await tester.enterText(input, '#PrOj ');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Server result'), findsOneWidget);
      expect(
        client.requests.where((request) => request == searchRoute),
        hasLength(1),
      );

      await tester.enterText(input, 'project n');
      await tester.pump();
      expect(find.text('Project new'), findsOneWidget);
      expect(find.text('Project notes'), findsOneWidget);
      expect(find.text('Server result'), findsNothing);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Project new'), findsOneWidget);
      next.complete(response([]));
      await tester.pumpAndSettle();
      expect(find.text('Project notes'), findsNothing);
      expect(find.text('Project new'), findsNothing);
      expect(find.text('No conversations found'), findsOneWidget);

      await tester.enterText(input, '');
      await tester.pump();
      expect(find.text('Anyone with the link'), findsOneWidget);
      expect(find.text('General'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(
        client.requests.where((request) => request == route),
        hasLength(2),
      );
      expect(find.text('General'), findsOneWidget);

      await tester.enterText(input, 'project n');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('No conversations found'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(popup, findsNothing);
      expect(
        tester.widget<RaftPickerTriggerButton>(trigger).focusNode!.hasFocus,
        isTrue,
      );
    });

    testWidgets('ignores stale replies and recovers from a failed search', (
      tester,
    ) async {
      final client = await openHome(tester);
      final stale = Completer<Object>();
      final latest = Completer<Object>();
      client.answers[route] = (_) => response([
        {'id': 'known', 'name': 'Missing project'},
      ]);
      client.answers['$route?q=stale'] = (_) => stale.future;
      client.answers['$route?q=missing'] = (_) => latest.future;
      await tester.tap(trigger);
      await tester.pumpAndSettle();

      await tester.enterText(input, 'stale');
      await tester.pump(const Duration(milliseconds: 300));
      expect(client.requests, contains('$route?q=stale'));
      expect(find.byType(RaftListRowSkeleton), findsOneWidget);
      expect(find.text('No conversations found'), findsNothing);
      expect(tester.widget<EditableText>(input).focusNode.hasFocus, isTrue);

      await tester.enterText(input, 'missing');
      stale.complete(
        response([
          {'id': 'stale', 'name': 'Missing stale answer'},
        ]),
      );
      await tester.pump();
      expect(find.text('Missing stale answer'), findsNothing);
      expect(find.text('Missing project'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      latest.completeError(StateError('fixture failure'));
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('No conversations found'), findsNothing);
      expect(find.byType(RaftListRowSkeleton), findsNothing);
      expect(find.text('Missing project'), findsOneWidget);

      client.answers['$route?q=missing'] = (_) => response([
        {'id': 'retry', 'name': 'Found on retry'},
      ]);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Found on retry'), findsOneWidget);
      expect(find.text('Missing project'), findsNothing);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('an unavailable endpoint waits for retry', (tester) async {
      final client = await openHome(tester);
      client.answers['$route?q=gone'] = (_) =>
          RaftApiException.response('Not found', status: 404);
      client.answers['$route?q=restored'] = (_) => response([
        {'id': 'restored', 'name': 'Restored conversation'},
      ]);
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      await tester.enterText(input, 'gone');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);

      await tester.enterText(input, 'restored');
      await tester.pump(const Duration(milliseconds: 300));
      expect(client.requests, isNot(contains('$route?q=restored')));
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(client.requests, contains('$route?q=restored'));
      expect(find.text('Restored conversation'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('starting a pending read preserves the highlighted row', (
      tester,
    ) async {
      final client = await openHome(tester);
      final pending = Completer<Object>();
      client.answers[route] = (_) => response([
        {'id': 'everyone', 'name': 'Everyone planning'},
      ]);
      client.answers['$route?q=everyone'] = (_) => pending.future;
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      await tester.enterText(input, 'everyone');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(client.requests, contains('$route?q=everyone'));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(popup, findsNothing);
      expect(find.text('Everyone planning'), findsOneWidget);
      pending.complete(response([]));
      await tester.pump();
    });

    testWidgets('empty Enter leaves active CJK composition open', (
      tester,
    ) async {
      final client = await openHome(tester);
      client.answers['$route?q=ni'] = (_) => response([]);
      client.answers['$route?q=%E4%BD%A0'] = (_) => response([]);
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      await tester.showKeyboard(input);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'ni',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('No conversations found'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(popup, findsOneWidget);
      expect(tester.widget<EditableText>(input).focusNode.hasFocus, isTrue);

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '你',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('No conversations found'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(popup, findsNothing);
    });

    testWidgets('empty Enter ignores modifier keys', (tester) async {
      final client = await openHome(tester);
      client.answers['$route?q=missing'] = (_) => response([]);
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      await tester.enterText(input, 'missing');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('No conversations found'), findsOneWidget);
      for (final modifier in [
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.altLeft,
        LogicalKeyboardKey.metaLeft,
      ]) {
        await tester.sendKeyDownEvent(modifier);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(modifier);
        await tester.pumpAndSettle();
        expect(popup, findsOneWidget, reason: modifier.keyLabel);
        expect(tester.widget<EditableText>(input).focusNode.hasFocus, isTrue);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(popup, findsNothing);
    });

    for (final authority in ['server', 'account', 'role', 'generation']) {
      testWidgets('fences cached rows and failures on a $authority change', (
        tester,
      ) async {
        final client = await openHome(tester);
        final dashboard = find.byType(ArtifactDashboard);
        final dashboardState = tester.state(dashboard);
        final workspace = tester.widget<ArtifactDashboard>(dashboard).workspace;
        final stale = Completer<Object>();
        final newBase = Completer<Object>();
        client.answers[route] = (_) => response([
          {'id': 'old', 'name': 'Old private conversation', 'type': 'private'},
        ]);
        client.answers['$route?q=old'] = (_) => authority == 'server'
            ? RaftApiException.response('Not found', status: 404)
            : stale.future;

        await tester.tap(trigger);
        await tester.pumpAndSettle();
        expect(find.text('Old private conversation'), findsOneWidget);
        await tester.enterText(input, 'old');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        expect(client.requests, contains('$route?q=old'));
        expect(find.text('Old private conversation'), findsOneWidget);
        if (authority == 'server') {
          expect(find.text('Try again'), findsOneWidget);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          await tester.tap(trigger);
          await tester.pumpAndSettle();
          expect(find.text('Try again'), findsOneWidget);
          expect(find.text('Old private conversation'), findsOneWidget);
          expect(
            client.requests.where((request) => request == route),
            hasLength(1),
          );
        }

        client.answers[route] = (_) => newBase.future;
        switch (authority) {
          case 'server':
            client.selectServer('s2');
            workspace.server = RaftRecord({
              'id': 's2',
              'role': 'owner',
              'name': 'Other server',
            });
          case 'account':
            client.user = RaftRecord({
              'id': 'u2',
              'displayName': 'Other account',
            });
          case 'role':
            workspace.server = RaftRecord({
              'id': 's1',
              'role': 'member',
              'name': 'Example',
            });
          case 'generation':
            client.selectServer(null);
            client.selectServer('s1');
        }
        workspace.notifyListeners();
        await tester.tap(find.text('Old private conversation'));
        await tester.pumpAndSettle();
        expect(tester.state(dashboard), same(dashboardState));
        expect(popup, findsNothing);
        expect(
          client.requests.where(
            (request) => request.contains('conversation=old'),
          ),
          isEmpty,
        );

        await tester.tap(trigger);
        await tester.pumpAndSettle();
        expect(
          client.requests.where((request) => request == route),
          hasLength(2),
        );
        expect(find.text('Old private conversation'), findsNothing);
        expect(find.text('Try again'), findsNothing);
        if (authority == 'account') {
          stale.completeError(
            RaftApiException.response('Not found', status: 404),
          );
        } else if (authority != 'server') {
          stale.complete(
            response([
              {'id': 'late', 'name': 'Late private conversation'},
            ]),
          );
        }
        await tester.pump();
        expect(find.text('Try again'), findsNothing);
        expect(find.text('Late private conversation'), findsNothing);
        newBase.complete(
          response([
            {'id': 'new', 'name': 'New scope conversation'},
          ]),
        );
        await tester.pumpAndSettle();
        expect(find.text('New scope conversation'), findsOneWidget);
      });
    }

    for (final (size, platform) in [
      (const Size(390, 844), TargetPlatform.linux),
      (const Size(856, 944), TargetPlatform.android),
      (const Size(944, 856), TargetPlatform.android),
    ]) {
      testWidgets(
        'keeps the house first and the selection on $size $platform',
        (tester) async {
          final client = await openHome(tester, size: size, platform: platform);
          final pending = Completer<Object>();
          client.answers[route] = (_) => response([
            {'id': 'everyone', 'name': 'Everyone planning'},
            {'id': 'chosen', 'name': 'Chosen conversation'},
          ]);
          client.answers['$route?q=everyone'] = (_) => pending.future;
          await tester.tap(trigger);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Chosen conversation'));
          await tester.pumpAndSettle();
          expect(
            find.descendant(
              of: trigger,
              matching: find.text('Chosen conversation'),
            ),
            findsOneWidget,
          );

          await tester.tap(trigger);
          await tester.pumpAndSettle();
          final chosenRow = find.ancestor(
            of: find.descendant(
              of: popup,
              matching: find.text('Chosen conversation'),
            ),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics && widget.properties.selected == true,
            ),
          );
          expect(chosenRow, findsOneWidget);
          await tester.tap(input);
          await tester.enterText(input, 'everyone');
          await tester.pump(const Duration(milliseconds: 300));
          expect(client.requests, contains('$route?q=everyone'));
          expect(
            find.descendant(
              of: popup,
              matching: find.text('Chosen conversation'),
            ),
            findsNothing,
          );
          expect(
            find.descendant(
              of: trigger,
              matching: find.text('Chosen conversation'),
            ),
            findsOneWidget,
          );
          expect(find.text('Everyone planning'), findsOneWidget);
          expect(
            tester.getTopLeft(find.text('Everyone in Example')).dy,
            lessThan(tester.getTopLeft(find.text('Everyone planning')).dy),
          );
          expect(tester.widget<EditableText>(input).focusNode.hasFocus, isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(popup, findsNothing);
          expect(
            find.descendant(
              of: trigger,
              matching: find.text('Everyone in Example'),
            ),
            findsOneWidget,
          );
          pending.complete(
            response([
              {'id': 'late', 'name': 'Everyone late'},
            ]),
          );
          await tester.pumpAndSettle();
          expect(find.text('Everyone late'), findsNothing);
        },
      );
    }
  });

  testWidgets('conversation picker stays below its trigger in a short window', (
    tester,
  ) async {
    await openHome(tester, size: const Size(390, 310));
    final trigger = find.byKey(const Key('artifacts-filter-conversation'));
    final popup = find.byKey(const Key('artifact-dashboard-filter'));
    final triggerBottom = tester.getBottomLeft(trigger).dy;
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(popup).dy, (triggerBottom + 4).round());
    final input = find.descendant(
      of: popup,
      matching: find.byType(EditableText),
    );
    final list = find.descendant(
      of: popup,
      matching: find.byType(SingleChildScrollView),
    );
    final searchRect = tester.getRect(input);
    await tester.drag(list, const Offset(0, -75));
    await tester.pumpAndSettle();
    expect(find.text('Everyone in Example').hitTestable(), findsOneWidget);
    expect(tester.getRect(input), searchRect);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(popup, findsNothing);
  });

  testWidgets('Viewer More opens visibility on hover and retains its actions', (
    tester,
  ) async {
    final client = await openHome(tester, dark: true, markdown: true);
    await tester.tap(find.text('Road map'));
    await tester.pumpAndSettle();
    final more = find.byKey(const Key('artifact-viewer-menu-trigger'));
    final menu = find.byKey(const Key('artifact-viewer-menu-surface'));
    await tester.tap(more);
    await tester.pumpAndSettle();
    final visibility = find.text('Who can see');
    final audience = find.text('Anyone with the link');
    expect(audience, findsNothing);
    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer(location: Offset.zero);
    addTearDown(pointer.removePointer);
    await pointer.moveTo(tester.getCenter(visibility));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(audience.hitTestable(), findsOneWidget);
    await pointer.moveTo(tester.getCenter(audience));
    await tester.pumpAndSettle();
    expect(audience.hitTestable(), findsOneWidget);
    await tester.tap(audience);
    await tester.pumpAndSettle();
    expect(menu, findsNothing);
    expect(find.text('Turn on link sharing?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(client.requests.where((path) => path.endsWith('/home')), isEmpty);
  });

  testWidgets('collection Viewer uses the source More menu entries', (
    tester,
  ) async {
    await openHome(tester, dark: true, markdown: true);
    await tester.tap(find.text('Road map'));
    await tester.pumpAndSettle();
    final more = find.byKey(const Key('artifact-viewer-menu-trigger'));
    final menu = find.byKey(const Key('artifact-viewer-menu-surface'));
    await tester.tap(more);
    await tester.pumpAndSettle();

    RaftMenuItem item(String label) => tester.widget<RaftMenuItem>(
      find.descendant(
        of: menu,
        matching: find.byWidgetPredicate(
          (widget) => widget is RaftMenuItem && widget.label == label,
        ),
      ),
    );
    expect(item('Files').glyph, RaftGlyph.files);
    expect(item('Follow').glyph, RaftGlyph.followArtifact);
    expect(item('Version history').glyph, RaftGlyph.history);
    expect(item('Version history').submenuOpen, isFalse);
    await tester.tap(find.text('Version history'));
    await tester.pumpAndSettle();
    expect(find.text('v1 · Latest').hitTestable(), findsOneWidget);
    await tester.tap(find.text('v1 · Latest'));
    await tester.pumpAndSettle();
    expect(menu, findsNothing);
    expect(find.byKey(const Key('artifact-workspace-viewer')), findsOneWidget);
  });

  testWidgets('wide Viewer stays in the collection and Escape returns focus', (
    tester,
  ) async {
    final client = await openHome(tester);
    final nav = tester.getRect(find.text('Workspace navigation'));
    await tester.tap(find.text('Road map'));
    await tester.pumpAndSettle();
    final viewer = find.byKey(const Key('artifact-workspace-viewer'));
    expect(tester.getTopLeft(viewer).dy, greaterThanOrEqualTo(nav.bottom));
    expect(find.text('Workspace navigation'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(viewer, findsNothing);
    expect(find.text('Road map'), findsOneWidget);
    expect(
      client.requests.where(
        (path) => path.startsWith('GET /artifacts/dashboard/all'),
      ),
      hasLength(2),
    );
  });

  testWidgets('rename selects the old title and only enables a changed title', (
    tester,
  ) async {
    final client = await openHome(tester);
    await tester.tap(find.text('Road map'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('artifact-viewer-menu-trigger')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    final dialog = find.byKey(const Key('artifact-manage-dialog'));
    final input = find.descendant(
      of: dialog,
      matching: find.byType(EditableText),
    );
    final save = find.widgetWithText(RaftButton, 'Save');
    expect(tester.widget<RaftButton>(save).onPressed, isNull);
    final editor = tester.widget<EditableText>(input);
    expect(
      editor.controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 8),
    );
    expect(
      editor.selectionColor,
      RaftTokens.of(tester.element(input)).colors['selection'],
    );
    await tester.enterText(input, ' Road map ');
    await tester.pump();
    expect(tester.widget<RaftButton>(save).onPressed, isNull);
    await tester.enterText(input, 'New title');
    await tester.pump();
    expect(tester.widget<RaftButton>(save).onPressed, isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
    expect(find.byKey(const Key('artifact-workspace-viewer')), findsOneWidget);
    expect(client.requests.where((path) => path.startsWith('PATCH ')), isEmpty);
  });

  testWidgets('dark Rename selection uses the Web input color', (tester) async {
    await openHome(tester, size: const Size(390, 844), dark: true);
    await tester.tap(find.text('Road map'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('artifact-viewer-menu-trigger')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    final input = find.descendant(
      of: find.byKey(const Key('artifact-manage-dialog')),
      matching: find.byType(EditableText),
    );
    expect(
      tester.widget<EditableText>(input).selectionColor?.toARGB32(),
      0xff544b28,
    );
  });

  testWidgets('Rename source contract names the dialog and selected field', (
    tester,
  ) async {
    final client = await openHome(tester, size: const Size(390, 844));
    await tester.tap(find.text('Road map'));
    await tester.pumpAndSettle();
    await chooseViewerAction(tester, 'Rename');

    expect(find.bySemanticsLabel('Rename Artifact'), findsWidgets);
    expect(find.bySemanticsLabel('Artifact title'), findsOneWidget);
    final field = tester.widget<EditableText>(
      find.descendant(of: manageDialog, matching: find.byType(EditableText)),
    );
    expect(field.focusNode.hasFocus, isTrue);
    expect(
      field.controller.selection.textInside(field.controller.text),
      'Road map',
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(manageDialog, findsNothing);
    expect(
      client.requests.where((request) => request.startsWith('PATCH ')),
      isEmpty,
    );
  });

  for (final (size, platform) in [
    (const Size(390, 844), TargetPlatform.linux),
    (const Size(856, 944), TargetPlatform.android),
    (const Size(944, 856), TargetPlatform.android),
  ]) {
    testWidgets(
      'Rename refusal warns and clears on edit and success at $size',
      (tester) async {
        const path = 'PATCH /artifacts/$artifactId/title';
        const message = "You can't rename this Artifact.";
        final client = await openHome(tester, size: size, platform: platform);
        final response = Completer<Object?>();
        client.answers[path] = (_) => response.future;
        await tester.tap(find.text('Road map'));
        await tester.pumpAndSettle();
        await chooseViewerAction(tester, 'Rename');

        final input = find.descendant(
          of: manageDialog,
          matching: find.byType(EditableText),
        );
        final banner = find.widgetWithText(RaftBanner, message);
        final save = find.widgetWithText(RaftButton, 'Save');
        expect(banner, findsNothing);
        await tester.enterText(input, 'Rejected title');
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pump();

        final inputWidget = find.descendant(
          of: manageDialog,
          matching: find.byType(TextField),
        );
        expect(tester.widget<TextField>(inputWidget).enabled, isTrue);
        expect(tester.widget<EditableText>(input).readOnly, isTrue);
        expect(tester.widget<RaftButton>(save).busy, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        expect(manageDialog, findsOneWidget);
        expect(
          client.requests.where((request) => request == path),
          hasLength(1),
        );

        response.completeError(
          RaftApiException.response(
            'Refused.',
            status: 403,
            body: {'code': 'FORBIDDEN'},
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.widget<EditableText>(input).readOnly, isFalse);
        expect(tester.widget<RaftButton>(save).busy, isFalse);
        expect(client.bodies[path], {'title': 'Rejected title'});
        expect(
          tester.widget<EditableText>(input).controller.text,
          'Rejected title',
        );
        expect(find.text(message), findsOneWidget);
        expect(banner, findsOneWidget);
        final warning = tester.widget<RaftBanner>(banner);
        expect(warning.status, RaftBannerRecipeStatus.warning);
        expect(warning.glyph, RaftGlyph.triangleAlert);
        expect(warning.live, isTrue);

        client.answers[path] = (_) => artifactViewerJson(
          card: artifactCardJson(title: 'Accepted title'),
          frame: false,
        );
        await tester.enterText(input, 'Accepted title');
        await tester.pumpAndSettle();
        expect(banner, findsNothing);
        expect(find.text(message), findsNothing);
        await tester.tap(save);
        await tester.pumpAndSettle();

        expect(manageDialog, findsNothing);
        expect(find.text('Accepted title'), findsWidgets);
        expect(client.bodies[path], {'title': 'Accepted title'});
        expect(
          client.requests.where((request) => request == path),
          hasLength(2),
        );
        await chooseViewerAction(tester, 'Rename');
        expect(
          tester.widget<EditableText>(input).controller.text,
          'Accepted title',
        );
        expect(banner, findsNothing);
        expect(find.text(message), findsNothing);
      },
    );
  }

  testWidgets('collection Viewer reads Markdown on Linux', (tester) async {
    final client = await openHome(tester, markdown: true);
    await tester.tap(find.text('Road map'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('artifact-viewer-markdown')), findsOneWidget);
    expect(find.text('Launch plan', findRichText: true), findsOneWidget);
    expect(find.byType(ArtifactOpenInBrowser), findsNothing);
    expect(client.requests.where((path) => path.contains('/files/notes.md')), [
      'GET /artifacts/$artifactId/files/notes.md?version=1',
    ]);
  });

  testWidgets('cross-server Markdown keeps the browser fallback', (
    tester,
  ) async {
    final client = await openHome(tester, markdown: true, crossServer: true);
    await tester.tap(find.text('Road map'));
    await tester.pumpAndSettle();
    expect(find.byType(ArtifactOpenInBrowser), findsOneWidget);
    expect(find.byKey(const Key('artifact-viewer-markdown')), findsNothing);
    expect(client.requests.where((path) => path.contains('/files/')), isEmpty);
  });

  testWidgets('phone Viewer exposes its scope and one Back control', (
    tester,
  ) async {
    await openHome(tester, size: const Size(390, 844), markdown: true);
    await tester.tap(find.text('Road map'));
    await tester.pumpAndSettle();
    final scope = find.byKey(const Key('artifact-viewer-scope'));
    final back = find.byKey(const Key('artifact-viewer-close'));
    expect(scope.hitTestable(), findsOneWidget);
    expect(back.hitTestable(), findsOneWidget);
    await tester.tap(scope);
    await tester.pumpAndSettle();
    expect(find.text('Members of #general'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('artifact-workspace-viewer')), findsNothing);
    expect(find.text('Road map'), findsOneWidget);
  });

  testWidgets('phone Viewer opens its original message in the workspace', (
    tester,
  ) async {
    final client = await openHome(
      tester,
      size: const Size(390, 844),
      markdown: true,
      origin: true,
    );
    await tester.tap(find.text('Road map'));
    await tester.pumpAndSettle();
    final link = find.widgetWithText(RaftTextLink, '#project-notes');
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(client.requests, contains('GET /messages/context/source-message'));
    expect(find.byKey(const Key('artifact-workspace-viewer')), findsNothing);
  });

  for (final (viewport, cardWidth, folded) in [
    (const Size(390, 844), 390.0, true),
    (const Size(1280, 900), 439.0, true),
    (const Size(1280, 900), 440.0, false),
  ]) {
    testWidgets('collection Viewer Comments at card width $cardWidth', (
      tester,
    ) async {
      final client = await openHome(
        tester,
        size: viewport,
        collectionWidth: cardWidth,
        markdown: true,
      );
      final path = '/artifacts/$artifactId';
      client.answers['GET $path/comments'] = (_) => {
        'comments': [],
        'olderCursor': null,
      };
      client.answers['GET $path/review/drafts'] = (_) => {'drafts': []};
      client.answers['GET $path/will-notify'] = (_) => {'recipients': []};
      await tester.tap(find.text('Road map'));
      await tester.pumpAndSettle();

      final viewer = find.byKey(const Key('artifact-workspace-viewer'));
      final comments = find.byKey(const Key('artifact-comments-trigger'));
      final more = find.byKey(const Key('artifact-viewer-menu-trigger'));
      final menu = find.byKey(const Key('artifact-viewer-menu-surface'));
      final item = find.descendant(
        of: menu,
        matching: find.text('Comments (0)'),
      );
      expect(tester.getSize(viewer).width, cardWidth);
      expect(comments, folded ? findsNothing : findsOneWidget);

      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(item, folded ? findsOneWidget : findsNothing);
      expect(find.text("Doesn't display well here"), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      if (folded) {
        await tester.tap(item);
      } else {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        await tester.tap(comments);
      }
      await tester.pumpAndSettle();
      expect(menu, findsNothing);
      expect(find.text('No comments yet'), findsOneWidget);
      expect(
        client.requests.where((r) => r == 'GET $path/comments'),
        hasLength(1),
      );
      await tester.tap(find.byKey(const Key('artifact-comments-close')));
      await tester.pumpAndSettle();
      final focus = folded
          ? tester.widget<RaftPanelAction>(more).focusNode
          : tester.widget<RaftButton>(comments).focusNode;
      expect(focus?.hasFocus, isTrue);
      expect(viewer, findsOneWidget);
      expect(
        client.requests.where(
          (r) => r.startsWith('DELETE ') || r == 'POST $path/comments',
        ),
        isEmpty,
      );
    });
  }

  testWidgets('closing Comments after the card folds restores focus to More', (
    tester,
  ) async {
    final client = await openHome(
      tester,
      size: const Size(440, 844),
      markdown: true,
    );
    client.answers['GET /artifacts/$artifactId/comments'] = (_) => {
      'comments': [],
      'olderCursor': null,
    };
    await tester.tap(find.text('Road map'));
    await tester.pumpAndSettle();
    final viewer = find.byKey(const Key('artifact-workspace-viewer'));
    final comments = find.byKey(const Key('artifact-comments-trigger'));
    final more = find.byKey(const Key('artifact-viewer-menu-trigger'));
    final close = find.byKey(const Key('artifact-comments-close'));
    expect(tester.getSize(viewer).width, 440);
    await tester.tap(comments);
    await tester.pumpAndSettle();
    expect(close.hitTestable(), findsOneWidget);
    expect(find.text('No comments yet'), findsOneWidget);

    tester.view.physicalSize = const Size(439, 844);
    await tester.pumpAndSettle();
    expect(tester.getSize(viewer).width, 439);
    expect(comments, findsNothing);
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(close, findsNothing);
    expect(tester.widget<RaftPanelAction>(more).focusNode?.hasFocus, isTrue);
    expect(viewer, findsOneWidget);
  });

  testWidgets('visibility opens from More and the scope chip', (tester) async {
    final client = await openHome(tester);
    await tester.tap(find.text('Road map'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('artifact-viewer-menu-trigger')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Who can see'));
    await tester.pumpAndSettle();
    expect(find.text('Members of #general'), findsOneWidget);
    expect(find.text('Everyone in Example'), findsOneWidget);
    await tester.tap(find.text('Anyone with the link'));
    await tester.pumpAndSettle();
    expect(find.text('Turn on link sharing?'), findsOneWidget);
    expect(find.text('Turn on link sharing'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Turn on link sharing?'), findsNothing);
    expect(client.requests.where((path) => path.endsWith('/home')), isEmpty);

    await tester.tap(find.byKey(const Key('artifact-viewer-scope')));
    await tester.pumpAndSettle();
    expect(find.text('Members of #general'), findsOneWidget);
    expect(find.text('Anyone with the link'), findsOneWidget);
  });

  testWidgets('link sharing confirmation shows progress while saving', (
    tester,
  ) async {
    const path = 'POST /artifacts/$artifactId/home';
    final client = await openHome(tester);
    final response = Completer<Object?>();
    client.answers[path] = (_) => response.future;
    await tester.tap(find.text('Road map'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('artifact-viewer-scope')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anyone with the link'));
    await tester.pumpAndSettle();

    final confirm = find.widgetWithText(RaftButton, 'Turn on link sharing');
    await tester.tap(confirm);
    await tester.pump();

    expect(tester.widget<RaftButton>(confirm).busy, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Turn on link sharing?'), findsOneWidget);
    expect(client.requests.where((request) => request == path), hasLength(1));
    expect(client.bodies[path], {'to': 'public'});

    response.complete(artifactViewerJson(frame: false));
    await tester.pumpAndSettle();
    expect(find.text('Turn on link sharing?'), findsNothing);
  });

  testWidgets('desktop Artifact dialog titles use the mounted Web baseline', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final font = FontLoader('packages/raft_ui/SpaceGrotesk')
        ..addFont(
          rootBundle.load('packages/raft_ui/assets/fonts/SpaceGrotesk.ttf'),
        );
      await font.load();
    });
    await openHome(tester, dark: true);
    await tester.tap(find.text('Road map'));
    await tester.pumpAndSettle();
    await chooseViewerAction(tester, 'Rename');
    final renameBaseline = titleBaseline(tester, 'Rename Artifact');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('artifact-viewer-scope')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anyone with the link'));
    await tester.pumpAndSettle();
    expect(
      [renameBaseline, titleBaseline(tester, 'Turn on link sharing?')],
      [33, 33],
    );
  });

  for (final (size, platform) in [
    (const Size(390, 844), TargetPlatform.linux),
    (const Size(856, 944), TargetPlatform.android),
    (const Size(944, 856), TargetPlatform.android),
  ]) {
    testWidgets('Artifact dialog actions remain reachable at 3.1x on $size', (
      tester,
    ) async {
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final client = await openHome(tester, size: size, platform: platform);
      await tester.tap(find.text('Road map'));
      await tester.pumpAndSettle();
      await chooseViewerAction(tester, 'Rename');
      tester.platformDispatcher.textScaleFactorTestValue = 3.1;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final input = find.descendant(
        of: manageDialog,
        matching: find.byType(EditableText),
      );
      expect(input.hitTestable(), findsOneWidget);
      await tester.enterText(input, 'Updated title');
      await tester.pumpAndSettle();
      expect(find.text('Save').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(manageDialog, findsNothing);

      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('artifact-viewer-scope')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anyone with the link'));
      await tester.pumpAndSettle();
      tester.platformDispatcher.textScaleFactorTestValue = 3.1;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Turn on link sharing').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(manageDialog, findsNothing);
      expect(
        client.requests.where((path) => path.startsWith('PATCH ')),
        isEmpty,
      );
    });
  }
}
