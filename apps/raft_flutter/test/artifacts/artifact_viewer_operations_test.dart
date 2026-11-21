import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/artifacts/artifact_dashboard.dart';
import 'package:raft_flutter/features/artifacts/artifact_models.dart';
import 'package:raft_flutter/features/artifacts/artifact_session.dart';
import 'package:raft_flutter/features/artifacts/artifact_viewer_page.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/artifact_fake_client.dart';

const _artifact = '/artifacts/$artifactId';
const _delete = 'DELETE $_artifact';
const _report = "Doesn't display well here";
const _dashboard = 'GET /artifacts/dashboard/all?sort=opened';
const _recipients = 'GET $_artifact/will-notify';
const _nobody = "Won't notify anyone.";

void main() {
  late ArtifactFakeClient client;
  late WorkspaceController workspace;
  late Map<String, Object?> card;
  late Map<String, Object?> viewer;

  setUp(() {
    client = ArtifactFakeClient();
    workspace = WorkspaceController(client)
      ..server = RaftRecord({'id': 's1', 'role': 'owner'});
    card = artifactCardJson(kind: 'text');
    viewer = artifactViewerJson(
      card: card,
      frame: false,
      files: [
        {'path': 'probe.txt', 'kind': 'text', 'entry': true},
        {'path': 'second.txt', 'kind': 'text', 'entry': false},
      ],
    );
    client.answers.addAll({
      _dashboard: (_) => {
        'rows': [
          {'card': card},
        ],
        'counts': {'total': 1, 'filtered': 1, 'relevant': 0},
      },
      'GET $_artifact': (_) => viewer,
      'GET $_artifact/files/probe.txt?version=1': (_) => 'Artifact text',
      'GET $_artifact/comments': (_) => {'comments': []},
      _recipients: (_) => {'recipients': []},
      'GET $_artifact/review/drafts': (_) => {'drafts': []},
    });
  });

  tearDown(() async {
    workspace.dispose();
    await client.dispose();
  });

  final menu = find.byKey(const Key('artifact-viewer-menu-trigger'));
  final viewerSurface = find.byKey(const Key('artifact-workspace-viewer'));
  final confirm = find.byKey(const Key('artifact-delete-confirm'));
  final input = find.byKey(const Key('artifact-comment-input'));
  final frame = find.byKey(const Key('artifact-comment-frame'));
  final attach = find.byKey(const Key('artifact-comment-attach'));
  final saveDraft = find.byKey(const Key('artifact-comment-save-draft'));
  final send = find.byKey(const Key('artifact-comment-send'));
  final closeComments = find.byKey(const Key('artifact-comments-close'));

  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(1024, 800),
    TargetPlatform platform = TargetPlatform.linux,
    bool collection = false,
    ValueNotifier<bool>? present,
    VoidCallback? onClose,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: platform),
        home: Scaffold(
          body: collection
              ? ArtifactDashboard(workspace: workspace)
              : ValueListenableBuilder(
                  valueListenable:
                      present ?? const AlwaysStoppedAnimation(true),
                  builder: (_, shown, _) => shown
                      ? ArtifactWorkspaceViewer(
                          session: ArtifactSession.of(workspace),
                          target: const ArtifactLinkTarget(artifactId),
                          page: size.width < 768,
                          onClose: onClose ?? () {},
                        )
                      : const Text('Other destination'),
                ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (collection) {
      await tester.tap(find.text('probe').hitTestable());
      await tester.pumpAndSettle();
    }
    expect(viewerSurface, findsOneWidget);
  }

  Future<void> pickDelete(WidgetTester tester) async {
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this Artifact?'), findsOneWidget);
  }

  testWidgets('collection phone header uses the source edges and menu anchor', (
    tester,
  ) async {
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await mount(
      tester,
      size: const Size(390, 844),
      platform: TargetPlatform.android,
      collection: true,
    );
    final back = find.byKey(const Key('artifact-viewer-close'));
    final scope = find.byKey(const Key('artifact-viewer-scope'));
    final chip = tester.widget<RaftBadge>(
      find.descendant(of: scope, matching: find.byType(RaftBadge)),
    );
    final trigger = tester.getRect(menu);
    expect(tester.getRect(back), const Rect.fromLTWH(9, 5.5, 44, 44));
    expect(trigger, const Rect.fromLTWH(337, 5.5, 44, 44));
    expect(chip.variant, RaftBadgeRecipeVariant.muted);
    expect(chip.glyphSize, 12);
    expect(scope.hitTestable(), findsOneWidget);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    final menuRect = tester.getRect(
      find.byKey(const Key('artifact-viewer-menu-surface')),
    );
    expect(menuRect.right, closeTo(trigger.right, 0.01));
    expect(menuRect.top, (trigger.bottom + 4).roundToDouble());
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.widget<RaftPanelAction>(menu).focusNode!.hasFocus, isTrue);
    expect(client.requests, isNot(contains(_delete)));
    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(viewerSurface, findsNothing);
  });

  for (final (size, platform) in [
    (const Size(390, 844), TargetPlatform.linux),
    (const Size(856, 944), TargetPlatform.android),
    (const Size(944, 856), TargetPlatform.android),
  ]) {
    testWidgets('plain-text preview wraps and copies on $platform $size', (
      tester,
    ) async {
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      final longWord = List.filled(60, 'abcdefghij').join();
      final text = 'Lead  text\n\n$longWord\nFinal line';
      client.answers['GET $_artifact/files/probe.txt?version=1'] = (_) =>
          '$text\n';
      String? copied;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await mount(tester, size: size, platform: platform, collection: true);
      final viewport = find.byKey(const Key('artifact-viewer-text'));
      final preview = find.descendant(
        of: viewport,
        matching: find.byWidgetPredicate(
          (widget) => widget is RichText && widget.text.toPlainText() == text,
        ),
      );
      final paragraph = tester.renderObject<RenderParagraph>(preview);
      expect(paragraph.size.width, lessThanOrEqualTo(size.width - 32));
      final style = paragraph.text.style!;
      final tokens = RaftTokens.of(tester.element(preview));
      final footnote = tokens.typeSlot('footnote');
      expect(style.fontFamily, tokens.monoFont);
      expect(style.fontSize, footnote.fontSize);
      expect(style.fontSize! * style.height!, footnote.lineHeight);
      expect(style.color, tokens.ink);
      expect(paragraph.size.height, greaterThan(4 * footnote.lineHeight));

      final firstWord = paragraph
          .getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 4),
          )
          .single
          .toRect();
      if (platform == TargetPlatform.linux) {
        await tester.dragFrom(
          paragraph.localToGlobal(firstWord.centerLeft),
          Offset(firstWord.width, 0),
          kind: PointerDeviceKind.mouse,
        );
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      } else {
        await tester.longPressAt(paragraph.localToGlobal(firstWord.center));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Select all').hitTestable());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Copy').hitTestable());
      }
      await tester.pumpAndSettle();
      expect(copied, text);
      expect(menu.hitTestable(), findsOneWidget);
      expect(
        find.byKey(const Key('artifact-viewer-scope')).hitTestable(),
        findsOneWidget,
      );
    });
  }

  Future<void> openReport(WidgetTester tester) async {
    await tester.tap(menu.hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text(_report).hitTestable());
    await tester.pumpAndSettle();
    expect(input.hitTestable(), findsOneWidget);
  }

  for (final crossServer in [false, true]) {
    testWidgets('denies both actions with crossServer=$crossServer', (
      tester,
    ) async {
      card['fromAnotherServer'] = crossServer;
      viewer['capabilities'] = {'delete': crossServer, 'comment': crossServer};
      await mount(tester);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      expect(find.text('Delete'), findsNothing);
      expect(find.text(_report), findsNothing);
      expect(client.requests, isNot(contains(_delete)));
    });
  }

  testWidgets('cancel returns focus and sends no write', (tester) async {
    await mount(tester);
    await pickDelete(tester);
    expect(
      find.text('Everyone loses access to “probe” and all of its versions.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(viewerSurface, findsOneWidget);
    expect(tester.widget<RaftButton>(menu).focusNode!.hasFocus, isTrue);
    expect(client.requests, isNot(contains(_delete)));
  });

  testWidgets('Delete source contract keeps the warning under a CSS heading', (
    tester,
  ) async {
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await mount(tester, size: const Size(1280, 900), collection: true);
    await pickDelete(tester);
    final title = find.text('Delete this Artifact?');
    expect(
      find.ancestor(of: title, matching: find.byType(RaftCssLineBox)),
      findsOneWidget,
    );
    final banner = tester.widget<RaftBanner>(find.byType(RaftBanner));
    expect(banner.status, RaftBannerRecipeStatus.destructive);
    expect(banner.live, isFalse);
    expect(banner.glyph, RaftGlyph.octagonAlert);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(title, findsNothing);
    expect(client.requests, isNot(contains(_delete)));
  });

  testWidgets(
    'delete waits for authority, then refreshes collection and references',
    (tester) async {
      final response = Completer<void>();
      var deleted = false;
      final list = client.answers[_dashboard]!;
      client.answers[_dashboard] = (body) => deleted
          ? {
              'rows': [],
              'counts': {'total': 0, 'filtered': 0, 'relevant': 0},
            }
          : list(body);
      client.answers[_delete] = (_) => response.future;
      const target = ArtifactLinkTarget(artifactId);
      client.answers['POST /objects/summaries'] = (_) => {
        'summaries': [
          if (deleted)
            {
              'ref': {'id': artifactId},
              'ok': false,
              'reason': 'deleted',
              'deleted': {'id': artifactId, 'kind': 'text', 'title': 'probe'},
            }
          else
            {
              'ref': {'id': artifactId},
              'ok': true,
              'summary': card,
            },
        ],
      };
      await mount(tester, collection: true);
      final summaries = ArtifactSession.of(workspace).summaries;
      summaries.stateOf(target);
      await tester.pump(const Duration(milliseconds: 20));
      expect(summaries.stateOf(target), isA<ArtifactLinkOk>());
      final staleSummary = Completer<Object?>();
      final readSummary = client.answers['POST /objects/summaries']!;
      final oldSummary = readSummary(null);
      client.answers['POST /objects/summaries'] = (_) => staleSummary.future;
      summaries.invalidate(artifactId);
      summaries.stateOf(target);
      await tester.pump(const Duration(milliseconds: 20));
      await pickDelete(tester);
      await tester.tap(confirm);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 250));
      expect(viewerSurface, findsOneWidget);
      expect(find.text('Delete this Artifact?'), findsOneWidget);
      expect(client.requests.where((path) => path.startsWith('DELETE ')), [
        _delete,
      ]);
      expect(client.requestAuthorization[_delete], isTrue);
      expect(client.bodies[_delete], isNull);
      deleted = true;
      client.answers['POST /objects/summaries'] = readSummary;
      response.complete();
      await tester.pumpAndSettle();
      expect(viewerSurface, findsNothing);
      expect(find.text('probe'), findsNothing);
      expect(client.requests.where((path) => path == _dashboard), hasLength(2));
      summaries.stateOf(target);
      await tester.pump(const Duration(milliseconds: 20));
      expect(summaries.stateOf(target), isA<ArtifactLinkDeleted>());
      staleSummary.complete(oldSummary);
      await tester.pump();
      expect(summaries.stateOf(target), isA<ArtifactLinkDeleted>());
    },
  );

  testWidgets(
    'backend refusal keeps the Viewer and permits an explicit retry',
    (tester) async {
      var attempts = 0;
      client.answers[_delete] = (_) {
        attempts++;
        return RaftApiException.response('Delete was refused.', status: 403);
      };
      await mount(tester);
      await pickDelete(tester);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(attempts, 1);
      expect(viewerSurface, findsOneWidget);
      expect(find.byType(RaftErrorBanner), findsOneWidget);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(attempts, 2);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(viewerSurface, findsOneWidget);
    },
  );

  testWidgets('switching server retires the confirmation before any DELETE', (
    tester,
  ) async {
    await mount(tester);
    await pickDelete(tester);
    client.selectServer('s2');
    workspace.server = RaftRecord({'id': 's2', 'role': 'owner'});
    workspace.notifyListeners();
    await tester.pump();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(client.requests, isNot(contains(_delete)));
  });

  for (final (size, platform) in [
    (const Size(390, 844), TargetPlatform.linux),
    (const Size(390, 844), TargetPlatform.android),
    (const Size(856, 944), TargetPlatform.android),
    (const Size(944, 856), TargetPlatform.android),
  ]) {
    testWidgets('display report measures the page on $platform $size', (
      tester,
    ) async {
      await mount(tester, size: size, platform: platform);
      final page = tester.getSize(
        find.byKey(const Key('artifact-viewer-text')),
      );
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text(_report));
      await tester.pumpAndSettle();
      final field = tester.widget<EditableText>(
        find.descendant(of: input, matching: find.byType(EditableText)),
      );
      expect(
        field.controller.text,
        startsWith(
          "Display report from Raft's viewer:\nVersion: v1\nShown file: probe.txt\n"
          'Page area: ${page.width.round()}x${page.height.round()} CSS px · Pixel ratio: 1x\n',
        ),
      );
      expect(field.controller.text, isNot(contains('https://')));
      expect(field.focusNode.hasFocus, platform == TargetPlatform.linux);
      expect(
        find.byType(RaftSheet),
        size.width < 768 ? findsOneWidget : findsNothing,
      );
      expect(
        client.requests.where((r) => r.startsWith('POST $_artifact/')),
        isEmpty,
      );
    });
  }

  for (final (result, notice) in [
    (const <Object>[], _nobody),
    (
      [
        {'actor': artifactActor(), 'reason': 'participant'},
      ],
      'Will notify: Developer',
    ),
  ]) {
    testWidgets('phone display report describes $notice without a row', (
      tester,
    ) async {
      final response = Completer<Object>();
      client.answers[_recipients] = (_) => response.future;
      await mount(
        tester,
        size: const Size(390, 844),
        platform: TargetPlatform.android,
      );
      await openReport(tester);
      final noticeText = find.text(notice);
      final boundsBefore = [
        for (final target in [frame, input, attach, saveDraft, send])
          tester.getRect(target),
      ];
      final panel = find.byKey(const ValueKey('artifact-comments-panel'));
      final closeBounds = tester.getRect(closeComments);
      expect(closeBounds.size, const Size(44, 44));
      expect(tester.getRect(panel).right - closeBounds.right, 5);
      expect(noticeText, findsNothing);
      expect(tester.getSemantics(input).hint, isNot(contains(notice)));

      response.complete({'recipients': result});
      await tester.pumpAndSettle();
      expect(noticeText, findsNothing);
      expect([
        for (final target in [frame, input, attach, saveDraft, send])
          tester.getRect(target),
      ], boundsBefore);
      expect(tester.getSemantics(input).hint, contains(notice));
      for (final control in [attach, saveDraft, send]) {
        expect(find.descendant(of: frame, matching: control), findsOneWidget);
        expect(control.hitTestable(), findsOneWidget);
      }
      await tester.tap(input.hitTestable(), kind: PointerDeviceKind.touch);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.tap(
        closeComments.hitTestable(),
        kind: PointerDeviceKind.touch,
      );
      await tester.pumpAndSettle();
      expect(input, findsNothing);
      expect(noticeText, findsNothing);
      expect(
        client.requests.where((r) => r.startsWith('POST $_artifact/')),
        isEmpty,
      );
    });
  }

  for (final size in [const Size(390, 844), const Size(1024, 800)]) {
    testWidgets(
      'desktop display report keeps Send and editor in one frame at $size',
      (tester) async {
        await mount(tester, size: size);
        await openReport(tester);
        expect(find.text(_nobody), findsNothing);
        expect(tester.getSemantics(input).hint, contains(_nobody));
        for (final child in [input, attach, saveDraft, send]) {
          expect(find.descendant(of: frame, matching: child), findsOneWidget);
          expect(child.hitTestable(), findsOneWidget);
        }
        expect(
          find.descendant(of: send, matching: find.text('Send')),
          findsOneWidget,
        );
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(5, 5));
        addTearDown(mouse.removePointer);
        await mouse.moveTo(tester.getCenter(saveDraft.hitTestable()));
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(find.text(_nobody), findsNothing);
        await mouse.moveTo(tester.getCenter(send.hitTestable()));
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(find.text(_nobody), findsOneWidget);
        await mouse.moveTo(const Offset(5, 5));
        await tester.pumpAndSettle();
        await tester.tap(closeComments.hitTestable());
        await tester.pumpAndSettle();
        expect(find.text(_nobody), findsNothing);
      },
    );
  }

  testWidgets('failed display report preview leaves audience unknown', (
    tester,
  ) async {
    client.answers[_recipients] = (_) =>
        RaftApiException.response('Failed', status: 503);
    await mount(
      tester,
      size: const Size(390, 844),
      platform: TargetPlatform.android,
    );
    await openReport(tester);
    expect(client.requests, contains(_recipients));
    expect(find.text(_nobody), findsNothing);
    expect(tester.getSemantics(input).hint, isNot(contains(_nobody)));
    expect(send.hitTestable(), findsOneWidget);
  });

  for (final switchServer in [false, true]) {
    testWidgets(
      'late success after leaving the Viewer with switchServer=$switchServer',
      (tester) async {
        final present = ValueNotifier(true);
        addTearDown(present.dispose);
        final response = Completer<void>();
        client.answers[_delete] = (_) => response.future;
        var closed = 0;
        await mount(tester, present: present, onClose: () => closed++);
        final session = ArtifactSession.of(workspace);
        await pickDelete(tester);
        await tester.tap(confirm);
        await tester.pump();
        present.value = false;
        if (switchServer) {
          client.selectServer('s2');
          workspace.server = RaftRecord({'id': 's2', 'role': 'owner'});
          workspace.notifyListeners();
        }
        await tester.pump();
        response.complete();
        await tester.pumpAndSettle();
        expect(viewerSurface, findsNothing);
        expect(find.text('Other destination'), findsOneWidget);
        expect(find.text('Delete this Artifact?'), findsNothing);
        expect(closed, 0);
        expect(client.requests.where((r) => r.startsWith('DELETE ')), [
          _delete,
        ]);
        expect(session.deletedArtifacts.value, switchServer ? 0 : 1);
      },
    );
  }

  testWidgets(
    'report appends to the private draft and only explicit Send posts',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await DevicePreferences.load();
      const post = 'POST $_artifact/comments';
      client.answers[post] = (body) => {
        'comment': {
          ...body as Map,
          'id': 'reported',
          'author': artifactActor(),
          'createdAt': '2026-11-20T03:00:00Z',
        },
        'notified': [],
      };
      await mount(tester);
      await tester.tap(find.byKey(const Key('artifact-comments-trigger')));
      await tester.pumpAndSettle();
      await tester.enterText(input, 'My private notes');
      await tester.tap(find.byKey(const Key('artifact-comments-close')));
      await tester.pumpAndSettle();
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text(_report));
      await tester.pumpAndSettle();
      final field = tester.widget<EditableText>(
        find.descendant(of: input, matching: find.byType(EditableText)),
      );
      final text = field.controller.text;
      expect(
        text,
        startsWith("My private notes\n\nDisplay report from Raft's viewer:"),
      );
      expect(field.controller.selection.baseOffset, text.length);
      expect(client.requests, isNot(contains(post)));
      await tester.tap(find.byKey(const Key('artifact-comment-send')));
      await tester.pumpAndSettle();
      expect(client.requests.where((r) => r == post), [post]);
      final body = client.bodies[post] as Map;
      expect(body['target'], {'scope': 'artifact'});
      expect(body['version'], 1);
      expect(body['body'], [
        {'type': 'text', 'text': text},
      ]);
    },
  );
}
