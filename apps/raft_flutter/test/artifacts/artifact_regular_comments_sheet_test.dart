import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/artifacts/artifact_comments_panel.dart';
import 'package:raft_flutter/features/artifacts/artifact_models.dart';
import 'package:raft_flutter/features/artifacts/artifact_session.dart';
import 'package:raft_flutter/features/artifacts/artifact_viewer_page.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../flutter_test_config.dart' show leakDebt;
import '../parity/parity_harness.dart' show loadParityFonts;
import '../support/artifact_fake_client.dart';

const _artifact = '/artifacts/$artifactId';
const _drafts = '$_artifact/review/drafts';

void main() {
  // Flutter 3.47.8's modal sheet leaves its drag-end CurvedAnimation undisposed.
  leakDebt(const ['CurvedAnimation']);
  late ArtifactFakeClient client;
  late WorkspaceController workspace;
  late ArtifactSession session;
  late List<Map<String, Object?>> drafts;
  late int viewerCloses;
  const phone = Size(390, 844);
  const desktop = Size(1280, 900);
  final more = find.byKey(const Key('artifact-viewer-menu-trigger'));
  final regularTrigger = find.byKey(const Key('artifact-comments-trigger'));
  final panel = find.byKey(const Key('artifact-comments-panel'));
  final close = find.byKey(const Key('artifact-comments-close'));
  final handle = find.byKey(const Key('raft-sheet-handle'));
  final file = find.byKey(const Key('artifact-viewer-text'));
  final input = find.byKey(const Key('artifact-comment-input'));
  final saveDraft = find.byKey(const Key('artifact-comment-save-draft'));
  final send = find.byKey(const Key('artifact-comment-send'));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DevicePreferences.load();
    viewerCloses = 0;
    drafts = [];
    client = ArtifactFakeClient();
    workspace = WorkspaceController(client)
      ..server = RaftRecord({'id': 's1', 'role': 'owner'});
    session = ArtifactSession.of(workspace);
    client.answers.addAll({
      'GET $_artifact/files/probe.txt?version=1': (_) => 'Artifact text',
      'GET $_artifact/comments': (_) => {'comments': []},
      'GET $_artifact/will-notify': (_) => {'recipients': []},
      'GET $_drafts': (_) => {'drafts': drafts},
    });
  });

  tearDown(() async {
    workspace.dispose();
    await client.dispose();
  });

  Future<void> mount(
    WidgetTester tester, {
    bool writable = true,
    bool dark = false,
    int cardCount = 0,
    bool fileActionFixture = false,
    bool inCollection = true,
    Size size = phone,
    TargetPlatform platform = TargetPlatform.android,
  }) async {
    Map<String, Object?> viewer(int version) => {
      ...artifactViewerJson(
        card: artifactCardJson(
          kind: 'text',
          comments: cardCount,
          version: version,
          latest: fileActionFixture ? 2 : 1,
          pinned: fileActionFixture && version == 1,
        ),
        frame: false,
        versions: fileActionFixture ? const [1, 2] : const [1],
        files: [
          {'path': 'probe.txt', 'kind': 'text', 'entry': true},
          if (fileActionFixture) {'path': 'alternate.txt', 'kind': 'text'},
        ],
      ),
      'viewer': artifactActor(),
      'capabilities': {'comment': writable},
    };
    client.answers['GET $_artifact'] = (_) => viewer(fileActionFixture ? 2 : 1);
    if (fileActionFixture) {
      client.answers.addAll({
        'GET $_artifact?version=1': (_) => viewer(1),
        'GET $_artifact/files/probe.txt?version=2': (_) => 'Artifact text v2',
        'GET $_artifact/files/alternate.txt?version=1': (_) => 'Alternate text',
        for (final path in ['probe.txt', 'alternate.txt'])
          'GET $_artifact/will-notify?path=$path': (_) => {'recipients': []},
      });
    }
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(dark: dark).copyWith(platform: platform),
        builder: (context, child) => RaftToastHost(child: child!),
        home: Scaffold(
          body: Builder(
            builder: (context) => ArtifactWorkspaceViewer(
              session: session,
              target: ArtifactLinkTarget(
                artifactId,
                fileActionFixture ? 1 : null,
              ),
              page: RaftAdaptiveWorkspace.compactOf(context),
              inCollection: inCollection,
              onClose: () => viewerCloses++,
              operatingSystem: 'linux',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openPhoneComments(WidgetTester tester, {int count = 0}) async {
    expect(regularTrigger, findsNothing);
    await tester.tap(more.hitTestable());
    await tester.pumpAndSettle();
    final entry = find.text('Comments ($count)').hitTestable();
    expect(entry, findsOneWidget);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(panel.hitTestable(), findsOneWidget);
  }

  void expectPhoneClosed(WidgetTester tester) {
    expect(panel, findsNothing);
    expect(file.hitTestable(), findsOneWidget);
    expect(tester.widget<RaftPanelAction>(more).focusNode?.hasFocus, isTrue);
    expect(viewerCloses, 0);
  }

  for (final (size, platform) in [
    (phone, TargetPlatform.android),
    (desktop, TargetPlatform.linux),
  ]) {
    testWidgets('regular composer keeps audience on the controls at $size', (
      tester,
    ) async {
      final response = Completer<Object>();
      client.answers['GET $_artifact/will-notify'] = (_) => response.future;
      await mount(tester, size: size, platform: platform);
      if (size == phone) {
        await openPhoneComments(tester);
      } else {
        await tester.tap(regularTrigger.hitTestable());
        await tester.pumpAndSettle();
      }

      final frame = find.byKey(const ValueKey('artifact-comment-frame'));
      final notice = find.text('Will notify: Developer');
      expect(frame, findsOneWidget);
      expect(find.descendant(of: frame, matching: input), findsOneWidget);
      expect(find.descendant(of: frame, matching: saveDraft), findsOneWidget);
      expect(find.descendant(of: frame, matching: send), findsOneWidget);
      expect(notice, findsNothing);
      final frameBefore = tester.getRect(frame);
      final inputBefore = tester.getRect(input);

      response.complete({
        'recipients': [
          {'actor': artifactActor(), 'reason': 'participant'},
        ],
      });
      await tester.pumpAndSettle();
      expect(tester.getRect(frame), frameBefore);
      expect(tester.getRect(input), inputBefore);
      expect(notice, findsNothing);
      expect(
        tester.getSemantics(input).hint,
        contains('Will notify: Developer'),
      );

      if (platform == TargetPlatform.linux) {
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(5, 5));
        addTearDown(mouse.removePointer);
        await mouse.moveTo(tester.getCenter(send.hitTestable()));
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(notice, findsOneWidget);
        await mouse.moveTo(const Offset(5, 5));
        await tester.pumpAndSettle();
        expect(notice, findsNothing);
      }
    });
  }

  for (final (size, platform) in [
    (phone, TargetPlatform.android),
    (desktop, TargetPlatform.linux),
  ]) {
    testWidgets('file comment action uses the displayed file at $size', (
      tester,
    ) async {
      await tester.runAsync(loadParityFonts);
      final fileAction = find.text('Comment on this file');
      final refusal = RaftApiException.response(
        'Local refusal',
        status: 503,
        body: const {},
      );
      client.answers['POST $_artifact/comments'] = (_) => refusal;
      client.answers['POST $_drafts'] = (_) => refusal;
      await mount(
        tester,
        size: size,
        platform: platform,
        fileActionFixture: true,
      );

      Future<void> openMore() async {
        await tester.tap(more.hitTestable());
        await tester.pumpAndSettle();
      }

      Future<void> openFileComment() async {
        await openMore();
        expect(fileAction.hitTestable(), findsOneWidget);
        if (size == phone) {
          expect(
            tester.getTopLeft(fileAction).dy -
                tester.getTopLeft(find.text('Comments (0)').hitTestable()).dy,
            36,
          );
        }
        await tester.tap(fileAction.hitTestable());
        await tester.pumpAndSettle();
        expect(panel.hitTestable(), findsOneWidget);
      }

      Future<void> backToMore() async {
        if (size == phone) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        }
        await tester.pumpAndSettle();
        expect(panel, findsNothing);
        expect(
          tester.widget<RaftPanelAction>(more).focusNode?.hasFocus,
          isTrue,
        );
        expect(viewerCloses, 0);
      }

      Future<void> refuse(String path, {required int version}) async {
        expect(
          find.descendant(of: panel, matching: find.text(path)),
          findsOneWidget,
        );
        expect(
          client.requests,
          contains('GET $_artifact/will-notify?path=$path'),
        );
        await tester.enterText(input, 'Unsent on $path');
        await tester.pumpAndSettle();
        for (final (button, endpoint, message) in [
          (saveDraft, _drafts, "Couldn't save the draft. Try again."),
          (
            send,
            '$_artifact/comments',
            "Couldn't send the comment. Try again.",
          ),
        ]) {
          await tester.tap(button.hitTestable());
          await tester.pumpAndSettle();
          expect(find.text(message), findsOneWidget);
          final request = client.bodies['POST $endpoint'] as Map;
          expect(request['target'], {
            'scope': 'file',
            'path': path,
            'anchor': null,
          });
          expect(request['version'], version);
        }
        await backToMore();
      }

      expect(fileAction, findsNothing);
      await openFileComment();
      await refuse('probe.txt', version: 1);

      if (size == phone) {
        await openPhoneComments(tester);
      } else {
        await tester.tap(regularTrigger.hitTestable());
        await tester.pumpAndSettle();
      }
      expect(find.text('Whole Artifact'), findsNothing);
      expect(find.text('Unsent on probe.txt'), findsNothing);
      final list = find.descendant(of: panel, matching: find.byType(ListView));
      expect(tester.getBottomLeft(list).dy, size == phone ? 740 : 794);
      await tester.enterText(input, 'Whole comment');
      await tester.pumpAndSettle();
      await tester.tap(send.hitTestable());
      await tester.pumpAndSettle();
      expect((client.bodies['POST $_artifact/comments'] as Map)['target'], {
        'scope': 'artifact',
      });
      await tester.tap(close.hitTestable());
      await tester.pumpAndSettle();

      await openMore();
      await tester.tap(find.text('Files').hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('artifact-files-row-alternate.txt')).hitTestable(),
      );
      await tester.pumpAndSettle();
      expect(find.text('Alternate text'), findsOneWidget);
      if (size == desktop) {
        await tester.tap(find.byKey(const Key('artifact-files-close')));
        await tester.pumpAndSettle();
      }
      await openFileComment();
      await refuse('alternate.txt', version: 1);
      await openFileComment();
      expect(find.text('Unsent on alternate.txt'), findsOneWidget);
      await backToMore();

      await tester.tap(find.text('v1').hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('artifact-version-row-2')).hitTestable(),
      );
      await tester.pumpAndSettle();
      expect(find.text('Artifact text v2'), findsOneWidget);
      await openFileComment();
      expect(find.text('Unsent on probe.txt'), findsNothing);
      await refuse('probe.txt', version: 2);

      await openFileComment();
      final pendingAction = tester
          .widget<RaftButton>(size == phone ? send : saveDraft)
          .onPressed!;
      final writesBeforeRevocation = client.requests
          .where((request) => request.startsWith('POST $_artifact/'))
          .toList();
      session.debugSetEnabled(false);
      pendingAction();
      await tester.pumpAndSettle();
      expect(
        client.requests.where(
          (request) => request.startsWith('POST $_artifact/'),
        ),
        writesBeforeRevocation,
      );
      expect(panel, findsNothing);
      await openMore();
      expect(fileAction, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  testWidgets(
    'file comment action fences queued text across file and version',
    (tester) async {
      const post = 'POST $_artifact/comments';
      const draft = 'POST $_drafts';
      final posting = Completer<Object>();
      final saving = Completer<Object>();
      client.answers[post] = (_) => posting.future;
      client.answers[draft] = (_) => saving.future;
      await mount(
        tester,
        size: desktop,
        platform: TargetPlatform.linux,
        fileActionFixture: true,
      );

      Future<void> choose(String label) async {
        await tester.tap(more.hitTestable());
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).hitTestable());
        await tester.pumpAndSettle();
      }

      Map<dynamic, dynamic> requestFor(
        String endpoint,
        String path,
        String text,
      ) {
        expect(
          client.requests.where((request) => request == endpoint),
          hasLength(1),
        );
        final request = client.bodies[endpoint] as Map;
        expect(request['target'], {
          'scope': 'file',
          'path': path,
          'anchor': null,
        });
        expect(request['version'], 1);
        expect(request['body'], [
          {'type': 'text', 'text': text},
        ]);
        return request;
      }

      await choose('Comment on this file');
      await tester.enterText(input, 'Queued for entry');
      await tester.pumpAndSettle();
      expect(tester.widget<RaftButton>(send).onPressed, isNotNull);
      await tester.tap(send.hitTestable());
      await tester.pumpAndSettle();
      final posted = requestFor(post, 'probe.txt', 'Queued for entry');

      await choose('Files');
      await tester.tap(
        find.byKey(const Key('artifact-files-row-alternate.txt')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Alternate text'), findsOneWidget);
      await tester.tap(find.byKey(const Key('artifact-files-close')));
      await tester.pumpAndSettle();
      await choose('Comment on this file');
      expect(find.text('Queued for entry'), findsNothing);
      await tester.enterText(input, 'Queued for alternate');

      posting.complete({
        'comment': {
          ...posted,
          'id': 'posted-on-entry',
          'author': artifactActor(),
        },
      });
      await tester.pumpAndSettle();
      expect(find.text('Queued for alternate'), findsOneWidget);
      requestFor(post, 'probe.txt', 'Queued for entry');

      await tester.tap(saveDraft.hitTestable());
      await tester.pumpAndSettle();
      final saved = requestFor(draft, 'alternate.txt', 'Queued for alternate');

      await tester.tap(find.text('v1').hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('artifact-version-row-2')).hitTestable(),
      );
      await tester.pumpAndSettle();
      expect(find.text('Artifact text v2'), findsOneWidget);
      await choose('Comment on this file');
      final editor = find.descendant(
        of: input,
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(editor).controller.text, isEmpty);
      await tester.enterText(input, 'Unsent on version 2');

      saving.complete({
        'draft': {...saved, 'id': 'draft-on-alternate'},
      });
      await tester.pumpAndSettle();
      expect(
        tester.widget<EditableText>(editor).controller.text,
        'Unsent on version 2',
      );
      requestFor(draft, 'alternate.txt', 'Queued for alternate');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('file comment action preserves standalone phone entry points', (
    tester,
  ) async {
    await mount(tester, inCollection: false);
    await tester.tap(regularTrigger.hitTestable());
    await tester.pumpAndSettle();
    expect(input.hitTestable(), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      tester.widget<RaftButton>(regularTrigger).focusNode?.hasFocus,
      isTrue,
    );

    for (final (label, fileScoped) in [
      ('Comment on this file', true),
      ('Comments (0)', false),
    ]) {
      await tester.tap(more.hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).hitTestable().last);
      await tester.pumpAndSettle();
      expect(input.hitTestable(), findsOneWidget);
      expect(
        find.descendant(of: panel, matching: find.text('probe.txt')),
        fileScoped ? findsOneWidget : findsNothing,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(tester.widget<RaftButton>(more).focusNode?.hasFocus, isTrue);
    }
  });

  testWidgets('Comments count follows the complete posted discussion', (
    tester,
  ) async {
    Map<String, Object?> comment(
      String id, {
      String? replyTo,
      bool resolved = false,
      bool deleted = false,
    }) => {
      'id': id,
      'version': 1,
      'author': artifactActor(),
      'body': [
        {'type': 'text', 'text': id},
      ],
      'target': {'scope': 'artifact'},
      'replyTo': replyTo,
      'resolvedAt': resolved ? '2026-11-19T03:00:00Z' : null,
      'deletedAt': deleted ? '2026-11-19T03:00:00Z' : null,
    };

    final first = Completer<Object>();
    Object page = first.future;
    client.answers['GET $_artifact/comments'] = (_) => page;
    await mount(
      tester,
      size: desktop,
      platform: TargetPlatform.linux,
      writable: false,
      cardCount: 103,
    );
    final triggerCount = find.descendant(
      of: regularTrigger,
      matching: find.byKey(const ValueKey('artifact-comment-count')),
    );
    final control = find.descendant(
      of: regularTrigger,
      matching: find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.toggled != null,
      ),
    );
    void expectCount(int count, {bool open = false}) {
      final node = tester.getSemantics(control);
      expect(node.label, 'Comments ($count)');
      expect(
        node.flagsCollection.isToggled,
        open ? Tristate.isTrue : Tristate.isFalse,
      );
    }

    Color? triggerFill() {
      final box = tester.widget<RaftRecipeBox>(
        find.descendant(
          of: regularTrigger,
          matching: find.byType(RaftRecipeBox),
        ),
      );
      return box.style.backgroundColor?.resolve(box.tokens);
    }

    expect(triggerCount, findsOneWidget);
    expect(tester.widget<Text>(triggerCount).data, '99+');
    expectCount(103);
    expect(triggerFill()?.a ?? 0, 0);

    first.complete({
      'comments': [comment('last')],
      'olderCursor': 'earlier',
    });
    await tester.pumpAndSettle();
    expectCount(103);

    page = {
      'comments': [
        comment('root'),
        comment('reply', replyTo: 'root'),
        comment('resolved', resolved: true),
        comment('deleted', deleted: true),
      ],
    };
    client.ingress.add(RaftEvent('activity:changed', {'serverId': 's1'}));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(triggerCount).data, '3');
    expectCount(3);

    await tester.tap(regularTrigger.hitTestable());
    await tester.pumpAndSettle();
    expect(panel.hitTestable(), findsOneWidget);
    expect(input, findsNothing);
    expectCount(3, open: true);
    expect(triggerFill(), const Color(0xffffd440));

    page = {'comments': []};
    client.ingress.add(RaftEvent('activity:changed', {'serverId': 's1'}));
    await tester.pumpAndSettle();
    expect(triggerCount, findsNothing);
    expectCount(0, open: true);

    await tester.tap(close.hitTestable());
    await tester.pumpAndSettle();
    expectCount(0);
    expect(triggerFill()?.a ?? 0, 0);
    expect(
      tester.widget<RaftButton>(regularTrigger).focusNode?.hasFocus,
      isTrue,
    );
  });

  testWidgets('Comments count follows the folded More entry', (tester) async {
    final response = Completer<Object>();
    client.answers['GET $_artifact/comments'] = (_) => response.future;
    await mount(tester, cardCount: 4);
    expect(regularTrigger, findsNothing);
    await tester.tap(more.hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Comments (4)').hitTestable(), findsOneWidget);
    expect(find.byKey(const ValueKey('artifact-comment-count')), findsNothing);

    response.complete({'comments': []});
    await tester.pumpAndSettle();
    final zero = find.text('Comments (0)').hitTestable();
    expect(zero, findsOneWidget);
    await tester.tap(zero);
    await tester.pumpAndSettle();
    expect(panel.hitTestable(), findsOneWidget);
    await tester.tap(close.hitTestable());
    await tester.pumpAndSettle();
    expectPhoneClosed(tester);
  });

  testWidgets(
    'regular phone sheet keeps the Viewer under it and returns focus',
    (tester) async {
      await mount(tester);
      await openPhoneComments(tester);
      expect(handle.hitTestable(), findsOneWidget);
      expect(tester.getSize(panel).height, closeTo(phone.height * .7, 2));
      expect(file, findsOneWidget);
      expect(file.hitTestable(), findsNothing);

      await tester.tap(close.hitTestable());
      await tester.pumpAndSettle();
      expectPhoneClosed(tester);

      await openPhoneComments(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expectPhoneClosed(tester);

      await openPhoneComments(tester);
      await tester.tapAt(const Offset(20, 100));
      await tester.pumpAndSettle();
      expectPhoneClosed(tester);

      await openPhoneComments(tester);
      final openedTop = tester.getTopLeft(panel).dy;
      final drag = await tester.startGesture(tester.getCenter(handle));
      await drag.moveBy(const Offset(0, 32));
      await tester.pump();
      await drag.moveBy(const Offset(0, 440));
      await tester.pump();
      expect(tester.getTopLeft(panel).dy, greaterThan(openedTop + 300));
      await drag.up();
      await tester.pumpAndSettle();
      expectPhoneClosed(tester);
    },
  );

  testWidgets(
    'saved draft and edit survive in the regular discussion on resize',
    (tester) async {
      client.answers['POST $_drafts'] = (body) {
        final draft = {...body! as Map<String, Object?>, 'id': 'draft-1'};
        drafts = [draft];
        return {'draft': draft};
      };
      client.answers['PATCH $_drafts/draft-1'] = (body) {
        final updated = {...drafts.single, ...body! as Map<String, Object?>};
        drafts = [updated];
        return {'draft': updated};
      };
      await mount(tester);
      await openPhoneComments(tester);
      await tester.enterText(input.hitTestable(), 'Private note');
      await tester.pumpAndSettle();
      await tester.tap(saveDraft.hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('Private note').hitTestable(), findsOneWidget);

      await tester.tap(find.text('Edit').hitTestable());
      await tester.pumpAndSettle();
      await tester.enterText(input.hitTestable(), 'Edited private note');
      const resizedPhone = Size(415, 640);
      tester.view.physicalSize = resizedPhone;
      await tester.pumpAndSettle();
      expect(handle.hitTestable(), findsOneWidget);
      expect(
        tester.getSize(panel).height,
        closeTo(resizedPhone.height * .7, 2),
      );
      expect(find.text('Edited private note').hitTestable(), findsOneWidget);
      await tester.tap(send.hitTestable());
      await tester.pumpAndSettle();
      expect(client.requests, contains('PATCH $_drafts/draft-1'));
      expect(client.requests, isNot(contains('POST $_artifact/comments')));

      tester.view.physicalSize = desktop;
      await tester.pumpAndSettle();
      expect(handle, findsNothing);
      // The 340px desktop aside includes its 1px leading seam.
      expect(tester.getSize(panel).width, 339);
      expect(find.text('Edited private note').hitTestable(), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(
        tester.widget<RaftButton>(regularTrigger).focusNode?.hasFocus,
        isTrue,
      );

      tester.view.physicalSize = phone;
      await tester.pumpAndSettle();
      await openPhoneComments(tester);
      expect(find.text('Edited private note').hitTestable(), findsOneWidget);
      await tester.tap(close.hitTestable());
      await tester.pumpAndSettle();
      expectPhoneClosed(tester);
    },
  );

  testWidgets('Escape cancels a posted edit before dismissing the sheet', (
    tester,
  ) async {
    client.answers['GET $_artifact/comments'] = (_) => {
      'comments': [
        {
          'id': 'posted-root',
          'version': 1,
          'author': artifactActor(),
          'body': [
            {'type': 'text', 'text': 'Posted note'},
          ],
          'target': {'scope': 'artifact'},
        },
      ],
    };
    await mount(tester);
    await openPhoneComments(tester, count: 1);
    final actions = find.byKey(const Key('artifact-comment-more-posted-root'));
    await tester.tap(actions.hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit').hitTestable());
    await tester.pumpAndSettle();
    await tester.enterText(input.hitTestable(), 'Unsubmitted edit');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(panel.hitTestable(), findsOneWidget);
    expect(find.text('Posted note').hitTestable(), findsOneWidget);
    expect(
      client.requests,
      isNot(contains('PATCH $_artifact/comments/posted-root')),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expectPhoneClosed(tester);
  });

  for (final (size, platform) in [
    (phone, TargetPlatform.android),
    (phone, TargetPlatform.linux),
    (const Size(856, 944), TargetPlatform.android),
    (const Size(944, 856), TargetPlatform.android),
  ]) {
    testWidgets('activating a clipped comment reveals its nearest edge at '
        '$size on $platform', (tester) async {
      final comments = [
        for (var index = 0; index < 18; index++)
          {
            'id': 'comment-$index',
            'version': 1,
            'author': artifactActor(),
            'body': [
              {'type': 'text', 'text': 'Comment $index'},
            ],
            'target': {'scope': 'artifact'},
            'createdAt': DateTime.utc(2026, 11, 19, 3, index).toIso8601String(),
          },
        for (var index = 0; index < 30; index++)
          {
            'id': 'reply-$index',
            'version': 1,
            'author': artifactActor(),
            'body': [
              {'type': 'text', 'text': 'Reply $index'},
            ],
            'target': {'scope': 'artifact'},
            'replyTo': 'comment-12',
            'createdAt': DateTime.utc(2026, 11, 19, 4, index).toIso8601String(),
          },
      ];
      client.answers['GET $_artifact/comments'] = (_) => {'comments': comments};
      await mount(tester, size: size, platform: platform);
      if (regularTrigger.hitTestable().evaluate().isEmpty) {
        await openPhoneComments(tester, count: comments.length);
      } else {
        await tester.tap(regularTrigger.hitTestable());
        await tester.pumpAndSettle();
      }

      final list = find.descendant(of: panel, matching: find.byType(ListView));
      final position = tester.widget<ListView>(list).controller!.position;
      final viewport = tester.getRect(list);
      final panelRect = tester.getRect(panel);
      final primaryFocus = FocusManager.instance.primaryFocus;
      final scrollable = find
          .descendant(of: list, matching: find.byType(Scrollable))
          .first;

      Future<void> tapCard(Finder card) async {
        final bounds = tester.getRect(card);
        final visible = bounds.intersect(viewport);
        await tester.tapAt(Offset(bounds.left + 4, visible.center.dy));
      }

      Future<void> activate(Finder card) async {
        await tapCard(card);
        await tester.pumpAndSettle();
        expect(tester.widget<RaftCommentCard>(card).active, isTrue);
      }

      Future<Rect> clipAtBottom(Finder card) async {
        await tester.scrollUntilVisible(card, 120, scrollable: scrollable);
        await tester.pumpAndSettle();
        position.jumpTo(
          position.pixels + tester.getRect(card).bottom - viewport.bottom - 24,
        );
        await tester.pumpAndSettle();
        final bounds = tester.getRect(card);
        expect(bounds.top, greaterThan(viewport.top));
        expect(bounds.bottom - viewport.bottom, closeTo(24, .01));
        return bounds;
      }

      final visible = find.byKey(const ValueKey('comment-0'));
      final initialOffset = position.pixels;
      expect(viewport.contains(tester.getRect(visible).bottomRight), isTrue);
      await activate(visible);
      expect(position.pixels, initialOffset);

      final clipped = find.byKey(const ValueKey('comment-8'));
      final clippedBounds = await clipAtBottom(clipped);
      final clippedOffset = position.pixels;
      await activate(clipped);
      final revealedBounds = tester.getRect(clipped);
      // The active border can change the card's height before the reveal.
      final remainingOverflow =
          clippedBounds.top + revealedBounds.height - viewport.bottom;
      expect(position.pixels - clippedOffset, closeTo(remainingOverflow, .01));
      expect(revealedBounds.bottom, closeTo(viewport.bottom, .01));

      final oversized = find.byKey(const ValueKey('comment-12'));
      await tester.scrollUntilVisible(oversized, 120, scrollable: scrollable);
      await tester.pumpAndSettle();
      position.jumpTo(
        position.pixels + tester.getRect(oversized).top - viewport.top + 24,
      );
      await tester.pumpAndSettle();
      final oversizedBounds = tester.getRect(oversized);
      expect(oversizedBounds.top, lessThan(viewport.top));
      expect(oversizedBounds.bottom, greaterThan(viewport.bottom));
      final oversizedOffset = position.pixels;
      await activate(oversized);
      expect(position.pixels, oversizedOffset);

      final removed = find.byKey(const ValueKey('comment-9'));
      position.jumpTo(clippedOffset);
      await tester.pumpAndSettle();
      await clipAtBottom(removed);
      final offsetBeforeRefresh = position.pixels;
      await tapCard(removed);
      comments.removeWhere((comment) => comment['id'] == 'comment-9');
      client.ingress.add(RaftEvent('activity:changed', {'serverId': 's1'}));
      await tester.pumpAndSettle();
      expect(removed, findsNothing);
      expect(position.pixels, offsetBeforeRefresh);

      expect(tester.getRect(panel), panelRect);
      expect(FocusManager.instance.primaryFocus, same(primaryFocus));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  Map<String, Object?> spacingComment(
    String id, {
    String? replyTo,
    bool mention = false,
    bool resolved = false,
  }) => {
    'id': id,
    'version': 1,
    'author': replyTo == null
        ? artifactActor()
        : {...artifactActor(), 'id': 'u2'},
    'body': [
      {'type': 'text', 'text': mention ? 'For ' : id},
      if (mention) {'type': 'mention', 'actor': artifactActor()},
    ],
    'target': {'scope': 'artifact'},
    'replyTo': replyTo,
    if (resolved) 'resolvedAt': '2026-11-19T03:00:00Z',
  };

  for (final dark in [false, true]) {
    testWidgets('desktop resolved section follows group spacing (dark=$dark)', (
      tester,
    ) async {
      await tester.runAsync(loadParityFonts);
      drafts = [spacingComment('private-draft')];
      client.answers['GET $_artifact/comments'] = (_) => {
        'comments': [
          spacingComment('root'),
          spacingComment('resolved', resolved: true),
        ],
      };
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      await mount(
        tester,
        dark: dark,
        size: desktop,
        platform: TargetPlatform.linux,
      );
      await tester.tap(regularTrigger.hitTestable());
      await tester.pumpAndSettle();

      final list = find.descendant(of: panel, matching: find.byType(ListView));
      final disclosure = find.ancestor(
        of: find.text('Resolved (1)'),
        matching: find.byType(RaftButton),
      );
      final draft = find.byKey(const ValueKey('private-draft'));
      final draftBody = find.descendant(
        of: draft,
        matching: find.byType(ArtifactCommentBody),
      );
      final draftStyle = tester.widget<ArtifactCommentBody>(draftBody).style!;
      final theme = RaftTokens.of(tester.element(draftBody));
      expect(tester.getSize(draftBody).height, 24);
      expect(draftStyle.fontSize, 16);
      expect(draftStyle.color, theme.ui.foreground);

      final root = find.byKey(const ValueKey('root'));
      expect(tester.getRect(disclosure).top - tester.getRect(root).bottom, 16);
      await tester.tap(disclosure.hitTestable());
      await tester.pumpAndSettle();

      final heading = find
          .descendant(of: list, matching: find.text('Whole Artifact'))
          .last;
      final resolved = find.byKey(const ValueKey('resolved'));
      expect(
        tester.getRect(heading).top - tester.getRect(disclosure).bottom,
        8,
      );
      expect(tester.getRect(resolved).top - tester.getRect(heading).bottom, 8);
      // The resolved card inherits the full draft and posted group heights.
      // Web reaches it through the 118px draft, two 18px group labels,
      // the 34px disclosure, and the authored gaps between those blocks.
      expect(
        tester.getRect(resolved).top - tester.getRect(draft).top,
        118 + 16 + 18 + 8 + tester.getSize(root).height + 16 + 34 + 8 + 18 + 8,
      );
      for (final label in [find.text('Your drafts'), heading]) {
        final text = tester.widget<Text>(label);
        final theme = RaftTokens.of(tester.element(label));
        expect(text.style!.color, theme.ui.foregroundHint);
        expect(text.style!.fontWeight, FontWeight.w700);
        expect(tester.getSize(label).height, 18);
      }
    });
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.linux]) {
    testWidgets('real tap reveals a clipped Resolved disclosure on $platform', (
      tester,
    ) async {
      await tester.runAsync(loadParityFonts);
      const count = 9;
      client.answers['GET $_artifact/comments'] = (_) => {
        'comments': [
          for (var i = 0; i < count - 1; i++) spacingComment('open-$i'),
          spacingComment('resolved', resolved: true),
        ],
      };
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      await mount(tester, platform: platform);
      await openPhoneComments(tester, count: count);

      final list = find.descendant(of: panel, matching: find.byType(ListView));
      final disclosure = find.ancestor(
        of: find.text('Resolved (1)'),
        matching: find.byType(RaftButton),
      );
      final scrollable = find
          .descendant(of: list, matching: find.byType(Scrollable))
          .first;
      final position = tester.widget<ListView>(list).controller!.position;
      final viewport = tester.getRect(list);
      final panelBounds = tester.getRect(panel);
      await tester.scrollUntilVisible(disclosure, 100, scrollable: scrollable);
      await tester.pumpAndSettle();

      // Leave most of the control reachable and clip a measured part of it.
      const clippedHeight = 9.0;
      position.jumpTo(
        position.pixels +
            tester.getRect(disclosure).bottom -
            viewport.bottom -
            clippedHeight,
      );
      await tester.pumpAndSettle();
      final clipped = tester.getRect(disclosure);
      expect(clipped.bottom - viewport.bottom, closeTo(clippedHeight, .01));
      expect(clipped.top, greaterThan(viewport.top));
      final beforeTap = position.pixels;
      await tester.tapAt(
        clipped.intersect(viewport).center,
        kind: platform == TargetPlatform.android
            ? PointerDeviceKind.touch
            : PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<RaftButton>(disclosure).glyph,
        RaftGlyph.chevronDown,
      );
      expect(position.pixels - beforeTap, closeTo(clippedHeight, .01));
      expect(tester.getRect(disclosure).bottom, closeTo(viewport.bottom, .01));
      expect(tester.getRect(panel), panelBounds);
      final resolved = find.byKey(const ValueKey('resolved'));
      await tester.scrollUntilVisible(resolved, 80, scrollable: scrollable);
      await tester.pumpAndSettle();
      expect(resolved.hitTestable(), findsOneWidget);

      await tester.ensureVisible(disclosure);
      await tester.pumpAndSettle();
      await tester.tap(disclosure.hitTestable());
      await tester.pumpAndSettle();
      expect(viewport.contains(tester.getRect(disclosure).center), isTrue);
      final visibleOffset = position.pixels;
      await tester.tap(disclosure.hitTestable());
      await tester.pumpAndSettle();
      expect(position.pixels, visibleOffset);
    });
  }

  testWidgets('regular phone list uses the authored comment spacing', (
    tester,
  ) async {
    await tester.runAsync(loadParityFonts);
    drafts = [spacingComment('private-draft')];
    client.answers['GET $_artifact/comments'] = (_) => {
      'comments': [
        spacingComment('root', mention: true),
        spacingComment('reply', replyTo: 'root', mention: true),
        spacingComment('resolved', resolved: true),
      ],
    };
    await mount(tester);
    await openPhoneComments(tester, count: 3);

    final root = find.byKey(const ValueKey('root'));
    final entries = find.descendant(
      of: root,
      matching: find.byType(ArtifactCommentBody),
    );
    await tester.tap(entries.first.hitTestable());
    await tester.pumpAndSettle();
    expect(tester.widget<RaftCommentCard>(root).active, isTrue);
    expect(tester.getSize(entries.first).height, 22);
    expect(tester.getSize(entries.last).height, 22);

    final list = find.descendant(of: panel, matching: find.byType(ListView));
    final draftHeading = tester.getRect(find.text('Your drafts'));
    final draft = tester.getRect(find.byKey(const ValueKey('private-draft')));
    expect(draftHeading.top - tester.getTopLeft(list).dy, closeTo(12, .01));
    expect(draftHeading.left - draft.left, 4);
    expect(draftHeading.height, 18);
    expect(draft.top - draftHeading.bottom, closeTo(8, .01));

    final disclosure = find.ancestor(
      of: find.text('Resolved (1)'),
      matching: find.byType(RaftButton),
    );
    if (disclosure.hitTestable().evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        disclosure,
        80,
        scrollable: find.descendant(
          of: list,
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
    }
    expect(
      tester.getTopLeft(disclosure).dy - tester.getBottomLeft(root).dy,
      16,
    );
    await tester.tap(disclosure.hitTestable());
    await tester.pumpAndSettle();
    await tester.drag(list, const Offset(0, -64));
    await tester.pumpAndSettle();
    final resolvedHeading = find
        .descendant(of: list, matching: find.text('Whole Artifact'))
        .last;
    final resolvedCard = find.byKey(const ValueKey('resolved'));
    expect(
      tester.getTopLeft(resolvedHeading).dy -
          tester.getBottomLeft(disclosure).dy,
      8,
    );
    expect(
      tester.getTopLeft(resolvedCard).dy -
          tester.getBottomLeft(resolvedHeading).dy,
      8,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expectPhoneClosed(tester);
  });

  testWidgets('read-only discussion hides writing and closes on feature loss', (
    tester,
  ) async {
    await mount(tester, writable: false);
    await tester.tap(more.hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Comment on this file'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await openPhoneComments(tester);
    expect(handle.hitTestable(), findsOneWidget);
    expect(input, findsNothing);
    expect(client.requests, isNot(contains('GET $_drafts')));

    session.debugSetEnabled(false);
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    expect(handle, findsNothing);
    expect(file.hitTestable(), findsOneWidget);
    expect(viewerCloses, 0);
    await tester.tap(more.hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Comments (0)').hitTestable(), findsNothing);
  });

  testWidgets(
    'private draft batch anchors confirmation and keeps refused drafts',
    (tester) async {
      const submitPath = '$_artifact/review/submit';
      drafts = [
        {
          'id': 'draft-one',
          'version': 1,
          'target': {'scope': 'artifact'},
          'body': [
            {'type': 'text', 'text': 'My private draft'},
          ],
        },
      ];
      client.answers['DELETE $_drafts'] = (_) =>
          RaftApiException.response('Temporarily unavailable', status: 503);
      final submissions = <Object?>[];
      client.answers['POST $submitPath'] = (input) {
        submissions.add(input);
        if (submissions.length == 1) {
          return RaftApiException.response(
            'Temporarily unavailable',
            status: 503,
          );
        }
        return {
          'status': 'ok',
          'comments': [
            {...drafts.single, 'id': 'posted', 'author': artifactActor()},
          ],
        };
      };
      await mount(tester);

      final bar = find.byKey(const ValueKey('artifact-review-batch-bar'));
      final discard = find.byKey(const ValueKey('artifact-review-discard-all'));
      final sendBatch = find.byKey(const ValueKey('artifact-review-submit'));
      final popup = find.byKey(
        const ValueKey('artifact-review-discard-popover'),
      );
      final cancel = find.byKey(
        const ValueKey('artifact-review-discard-cancel'),
      );
      expect(bar.hitTestable(), findsOneWidget);
      expect(tester.getRect(bar).bottom, phone.height - 16);
      expect(tester.getCenter(bar).dx, phone.width / 2);
      expect(tester.getSize(bar).height, 40);
      expect(
        find.descendant(of: sendBatch, matching: find.text('Send 1')),
        findsOneWidget,
      );
      expect(
        tester.widget<RaftButton>(discard).tone,
        RaftButtonRecipeVariant.ghost,
      );
      expect(
        tester.widget<RaftButton>(sendBatch).tone,
        RaftButtonRecipeVariant.primary,
      );

      await openPhoneComments(tester);
      expect(discard.hitTestable(), findsNothing);
      expect(find.text('My private draft').hitTestable(), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expectPhoneClosed(tester);

      await tester.tap(discard.hitTestable());
      await tester.pumpAndSettle();
      expect(
        tester.getRect(popup).bottom,
        closeTo(tester.getRect(discard).top - 8, 1),
      );
      expect(tester.widget<RaftButton>(cancel).focusNode?.hasFocus, isTrue);
      expect(client.requests, isNot(contains('DELETE $_drafts')));
      await tester.tap(find.text('Discard drafts').hitTestable());
      await tester.pumpAndSettle();
      expect(popup.hitTestable(), findsOneWidget);
      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
      expect(
        client.requests.where((path) => path == 'DELETE $_drafts'),
        hasLength(1),
      );
      await tester.tap(cancel.hitTestable());
      await tester.pumpAndSettle();
      expect(popup, findsNothing);
      expect(tester.widget<RaftButton>(discard).focusNode?.hasFocus, isTrue);

      await tester.tap(sendBatch.hitTestable());
      await tester.pumpAndSettle();
      expect(
        find.text("Couldn't send. Your drafts are kept; try again."),
        findsOneWidget,
      );
      expect(sendBatch.hitTestable(), findsOneWidget);
      expect(panel, findsNothing);
      await tester.tap(sendBatch.hitTestable());
      await tester.pumpAndSettle();
      expect(submissions, hasLength(2));
      expect(submissions.last, submissions.first);
      expect(submissions.first, containsPair('summary', null));
      expect(bar, findsNothing);
      expect(
        find.text("Couldn't send. Your drafts are kept; try again."),
        findsNothing,
      );
      expect(find.text('Your drafts'), findsNothing);
      expect(find.text('My private draft').hitTestable(), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expectPhoneClosed(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('private draft batch clears on confirmed discard', (
    tester,
  ) async {
    drafts = [
      {
        'id': 'discarded-draft',
        'version': 1,
        'target': {'scope': 'artifact'},
        'body': [
          {'type': 'text', 'text': 'Private draft to discard'},
        ],
      },
    ];
    client.answers['DELETE $_drafts'] = (_) {
      drafts = [];
      return {};
    };
    await mount(tester);
    final discard = find.byKey(const ValueKey('artifact-review-discard-all'));
    await tester.tap(discard.hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard drafts').hitTestable());
    await tester.pumpAndSettle();
    expect(
      client.requests.where((path) => path == 'DELETE $_drafts'),
      hasLength(1),
    );
    expect(discard, findsNothing);
    expectPhoneClosed(tester);
    await openPhoneComments(tester);
    expect(find.text('Private draft to discard'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
