import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' as chat_ui;
import 'package:integration_test/integration_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'primary_route_tabs_fixture.dart';

import 'package:raft_flutter/features/source_channel_files_view.dart';

class _PublicClient extends RaftClient {
  _PublicClient(this.fixture)
    : super(
        origin: 'https://public-fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord(Map<String, dynamic>.from(fixture['context']['user']));
    selectServer('visual-server');
  }
  final Map<String, dynamic> fixture;
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  Completer<void>? loading;
  final requests = <String>[];
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void joinChannel(String id) {}
  @override
  void connect() {}
  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async {
    requests.add('GET /messages/channel/$id');
    if (id == 'channel-design' && loading != null) await loading!.future;
    return Map<String, dynamic>.from(
      fixture['routes']['GET /messages/channel/$id'],
    );
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    requests.add(
      'GET $path${query == null ? '' : '?${Uri(queryParameters: query.map((key, value) => MapEntry(key, '$value'))).query}'}',
    );
    final answer = fixture['routes']['GET $path'];
    if (answer != null) return answer;
    if (path.endsWith('/setup-projection')) {
      return {'phase': 'complete', 'surface': 'complete', 'blocksChat': false};
    }
    if (path.endsWith('/sidebar-order')) {
      return {'pinned': [], 'customSections': [], 'sectionPlacements': []};
    }
    if (path.endsWith('/saved/count')) return {'count': 0};
    if (path.endsWith('/message-display-settings')) {
      return {'collapseLongMessages': false, 'prefsVersion': 0};
    }
    if (path.endsWith('/notification-settings')) {
      return {'activityMuted': false, 'muteFromSeq': null, 'prefsVersion': 0};
    }
    if (path == '/channels/threads/followers' ||
        path == '/channels/threads/followed') {
      return {'threads': []};
    }
    return [];
  }

  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    requests.add('POST $path');
    if (path.endsWith('/read')) {
      return {'maxReadSeq': '3', 'readStateVersion': '1'};
    }
    return fixture['routes']['POST $path'] ?? {};
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets(
    'public mounted main and thread loading, System, avatar and retained draft',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      final output = Directory(
        const String.fromEnvironment('RAFT_TEST_REPORT'),
      );
      await output.create(recursive: true);
      const hash = String.fromEnvironment('RAFT_TEST_SOURCE_HASH');
      const item = String.fromEnvironment(
        'RAFT_PRIMARY_ITEM',
        defaultValue: 'all',
      );
      const platform = String.fromEnvironment(
        'RAFT_TEST_PLATFORM',
        defaultValue: 'linux',
      );
      final runId = DateTime.now().toUtc().toIso8601String();
      final captures = <Map<String, dynamic>>[];
      const requestedWidth = int.fromEnvironment('RAFT_PRIMARY_WIDTH');
      const requestedHeight = int.fromEnvironment(
        'RAFT_PRIMARY_HEIGHT',
        defaultValue: 720,
      );
      final viewport = requestedWidth > 0
          ? Size(requestedWidth.toDouble(), requestedHeight.toDouble())
          : Platform.isAndroid
          ? const Size(390, 720)
          : const Size(1280, 720);
      // This is a controlled native component viewport, not a raw OS screenshot.
      // SizedBox alone cannot exceed the real host's logical constraints.
      await t.binding.setSurfaceSize(viewport);
      addTearDown(() => t.binding.setSurfaceSize(null));
      Future<void> until(bool Function() check) async {
        for (var step = 0; step < 120 && !check(); step++) {
          await t.pump(const Duration(milliseconds: 50));
        }
        expect(check(), isTrue);
      }

      for (final (family, dark, theme) in [
        (RaftFamily.brutal, false, 'brutal-light'),
        (RaftFamily.elegant, false, 'elegant-light'),
        (RaftFamily.elegant, true, 'elegant-dark'),
      ]) {
        final fixture = primaryRouteTabsFixture();
        final client = _PublicClient(fixture)..loading = Completer<void>();
        final w = WorkspaceController(client)
          ..server = RaftRecord(
            Map<String, dynamic>.from(fixture['context']['server']),
          )
          ..channels = (fixture['context']['channels'] as List)
              .map((e) => RaftChannel(Map<String, dynamic>.from(e)))
              .toList();
        w.ledger.switchServer('visual-server');
        final selection = viewport.width < 768
            ? null
            : w.selectChannel(w.channels.first, autoRead: false);
        final shotKey = GlobalKey();
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            builder: (context, child) => Align(
              alignment: Alignment.topLeft,
              child: RepaintBoundary(
                key: shotKey,
                child: SizedBox(
                  width: viewport.width,
                  height: viewport.height,
                  child: MediaQuery(
                    data: MediaQueryData(size: viewport, devicePixelRatio: 1),
                    child: RaftDensityScope(
                      density: Platform.isAndroid
                          ? RaftDensity.touch
                          : RaftDensity.desktop,
                      child: RaftTooltipProvider(
                        delay: const Duration(milliseconds: 600),
                        child: child!,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            home: WorkspaceView(
              controller: w,
              appearance: RaftAppearance(light: family),
              onAppearance: (_) async {},
              onLogout: () async {},
            ),
          ),
        );
        Future<void> capture(String state) async {
          if (item == 'thread-composer' &&
              state != 'thread-open' &&
              state != 'thread-input-focused') {
            return;
          }
          if ((item == 'surface' ||
                  item == 'timeline' ||
                  item == 'row-inset' ||
                  item == 'body-typography') &&
              state != 'main-rest' &&
              state != 'thread-open') {
            return;
          }
          if ((item == 'composer' ||
                  item == 'header' ||
                  item == 'reaction-add') &&
              state != 'main-rest' &&
              state != 'main-draft' &&
              !state.startsWith('reaction-picker-')) {
            return;
          }
          if (item == 'human-author' &&
              state != 'main-rest' &&
              state != 'human-author-mention') {
            return;
          }
          if (item == 'tabs-date' &&
              (state == 'loading-before-ack' || state.startsWith('thread-'))) {
            return;
          }
          await t.pump(const Duration(milliseconds: 250));
          final boundary =
              shotKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          expect(
            boundary.size,
            viewport,
            reason: 'Measured fixture viewport must match the source',
          );
          final image = await boundary.toImage(pixelRatio: 1);
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final name = '$platform-primary-$theme-$state.png';
            await File('${output.path}/$name')
                .writeAsBytes(bytes!.buffer.asUint8List());
            final geometry = <Map<String, dynamic>>[];
            for (final finder in [
              find.byType(RaftChatView),
              find.byType(RaftComposer),
              find.byType(RaftSystemMessage),
              find.byType(RaftMessageRow),
              find.byType(RaftMountedReaction),
              find.byType(RaftMountedMessageTaskChip),
              find.byType(RaftComposerTaskToggle),
              find.byType(RaftConversationTabs),
              find.byType(RaftThreadHeader),
              find.byType(RaftTimelineFooter),
              find.byType(RaftConversationDateHeader),
              find.byType(RaftControl),
            ]) {
              for (final element in finder.evaluate()) {
                if (!Visibility.of(element)) continue;
                final box = element.findRenderObject();
                if (box is RenderBox && box.hasSize && box.attached) {
                  final at =
                      box.localToGlobal(Offset.zero) -
                      boundary.localToGlobal(Offset.zero);
                  geometry.add({
                    'name': element.widget.runtimeType.toString(),
                    'x': at.dx,
                    'y': at.dy,
                    'width': box.size.width,
                    'height': box.size.height,
                    if (element.widget is RaftMessageRow) ...{
                      'rowContext':
                          (element.widget as RaftMessageRow).rowContext.name,
                      'author': (element.widget as RaftMessageRow).author,
                    },
                    if (element.widget is RaftChatView) ...{
                      'surfaceRole': (element.widget as RaftChatView).thread
                          ? 'ordinary-thread-replies'
                          : 'channel-timeline',
                      'timelineBackground': t
                          .widget<chat_ui.Chat>(
                            find
                                .descendant(
                                  of: find.byWidget(element.widget),
                                  matching: find.byType(chat_ui.Chat),
                                )
                                .first,
                          )
                          .backgroundColor
                          ?.toARGB32(),
                    },
                    if (element.widget is RaftControl) ...{
                      'kind': (element.widget as RaftControl).kind.name,
                      'label': (element.widget as RaftControl).semanticLabel,
                      'paintHeight':
                          (element.widget as RaftControl).visualHeight,
                      'paintWidth': (element.widget as RaftControl).visualWidth,
                      'minimumTarget':
                          (element.widget as RaftControl).minimumTargetSize,
                    },
                  });
                }
              }
            }
            final timelineLayouts = <Map<String, dynamic>>[];
            for (final element in find.byType(RaftChatView).evaluate()) {
              if (!Visibility.of(element)) continue;
              final view = find.byWidget(element.widget);
              final sparseFinder = find.descendant(
                of: view,
                matching: find.byType(RaftSparseTimelineSliver),
              );
              if (sparseFinder.evaluate().isEmpty) continue;
              final sparse = t.renderObject<RenderRaftSparseTimelineSliver>(
                sparseFinder,
              );
              final thread = (element.widget as RaftChatView).thread;
              final list = t.widget<chat_ui.ChatAnimatedList>(
                find.descendant(
                  of: view,
                  matching: find.byType(chat_ui.ChatAnimatedList),
                ),
              );
              final chatRect = t.getRect(
                find.descendant(of: view, matching: find.byType(chat_ui.Chat)),
              );
              final footerRect = t.getRect(
                find.descendant(
                  of: view,
                  matching: find.byType(RaftTimelineFooter),
                ),
              );
              if (item == 'timeline') {
                expect(
                  sparse.anchor,
                  thread
                      ? RaftTimelineSparseAnchor.top
                      : RaftTimelineSparseAnchor.bottom,
                );
                expect(sparse.leadingExtent, thread ? 0 : greaterThan(0));
                expect(
                  find.descendant(
                    of: view,
                    matching: find.byType(RaftConversationDateHeader),
                  ),
                  thread ? findsNothing : findsOneWidget,
                );
                if (!thread) {
                  expect(footerRect.bottom, closeTo(chatRect.bottom, .01));
                }
              }
              timelineLayouts.add({
                'host': thread ? 'threadPanel' : 'chatPanel',
                'anchor': sparse.anchor.name,
                'leadingExtent': sparse.leadingExtent,
                'viewportExtent': sparse.constraints.viewportMainAxisExtent,
                'precedingExtent': sparse.constraints.precedingScrollExtent,
                'tailExtent': sparse.child?.geometry?.scrollExtent,
                'footerHeight': footerRect.height,
                'footerBottom': footerRect.bottom,
                'viewportBottom': chatRect.bottom,
                'scrollPixels': list.scrollController?.position.pixels,
                'maxScrollExtent':
                    list.scrollController?.position.maxScrollExtent,
                'dateDividers': find
                    .descendant(
                      of: view,
                      matching: find.byType(RaftConversationDateHeader),
                    )
                    .evaluate()
                    .length,
              });
            }
            captures.add({
              'timelineComposition': timelineLayouts,
              'state': state,
              'item': item,
              'theme': theme,
              'image': name,
              'runId': runId,
              'sourceHash': hash,
              'hostPhysicalViewport': {
                'width': t.view.physicalSize.width,
                'height': t.view.physicalSize.height,
                'dpr': t.view.devicePixelRatio,
              },
              'viewportAdmission': 'IntegrationTest binding.setSurfaceSize + measured RepaintBoundary; native widget raster, not raw OS frame',
              'viewport': {
                'width': viewport.width,
                'height': viewport.height,
                'dpr': 1,
              },
              'geometry': geometry,
              'bodyParagraphs': [
                for (final element in find.byType(RaftMessageBody).evaluate())
                  if (Visibility.of(element))
                    for (final rich
                        in find
                            .descendant(
                              of: find.byWidget(element.widget),
                              matching: find.byType(RichText),
                            )
                            .evaluate())
                      if (rich.findRenderObject()
                          case final RenderParagraph paragraph)
                        {
                          'text': paragraph.text.toPlainText(),
                          'width': paragraph.size.width,
                          'height': paragraph.size.height,
                          'lineCount':
                              (TextPainter(
                                    text: paragraph.text,
                                    textDirection: paragraph.textDirection,
                                    textScaler: paragraph.textScaler,
                                  )..layout(maxWidth: paragraph.size.width))
                                  .computeLineMetrics()
                                  .length,
                          'mountedMessage': (element.widget as RaftMessageBody)
                              .mountedMessage,
                          'fontSizePreference':
                              (element.widget as RaftMessageBody).fontSize,
                        },
              ],
              'requests': List<String>.from(client.requests),
              'draft': w.drafts[w.draftScope()] ?? '',
              'activeThreadId': w.threadChannelId,
              'renderedComposerText': [
                for (final field in find.byType(TextField).evaluate())
                  if (Visibility.of(field))
                    (field.widget as TextField).controller?.text,
              ],
              'renderedComposerFocus': [
                for (final field in find.byType(TextField).evaluate())
                  if (Visibility.of(field))
                    {
                      'placeholder':
                          (field.widget as TextField).decoration?.hintText,
                      'hasFocus':
                          (field.widget as TextField).focusNode?.hasFocus,
                    },
              ],
              'fixtureExtensions': 'Observed Task10, Files metadata only, explicit activity inputs',
              'fixtureSha256': '0d0c0b14d714d64cdd557fc5d9374def8ff29ced29dcf3d78955d5230d140721',
              'controlledAPI': 'public-canned-responses; no authentication or backend execution',
              'density': Platform.isAndroid ? 'touch' : 'desktop',
              'API': 'NOT_RUN',
              'pixelParity': 'UNACCEPTED',
            });
            await File('${output.path}/$platform-primary-captures.json')
                .writeAsString(
                  jsonEncode({
                    'runId': runId,
                    'sourceHash': hash,
                    'completed': false,
                    'captures': captures,
                  }),
                );
          } finally {
            image.dispose();
          }
        }

        if (viewport.width < 768) {
          final homeChannel = find.byKey(
            const ValueKey('sidebar-channel-channel-design'),
          );
          expect(homeChannel, findsOneWidget);
          await t.tap(homeChannel);
        }
        await until(() => find.byType(RaftComposer).evaluate().isNotEmpty);
        expect(w.channelLoading, isTrue);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        await capture('loading-before-ack');
        client.loading!.complete();
        if (selection != null) await selection;
        await until(() => find.byType(RaftMessageRow).evaluate().length >= 2);
        for (var i = 0; i < 30; i++) {
          await t.pump(const Duration(milliseconds: 16));
        }
        expect(find.byType(RaftSystemMessage), findsOneWidget);
        expect(find.byType(RaftAvatarContent), findsWidgets);
        await until(
          () => find.byType(RaftMountedMessageTaskChip).evaluate().isNotEmpty,
        );
        expect(find.text('#10'), findsOneWidget);
        final reaction = find.byType(RaftMountedReaction);
        expect(reaction, findsOneWidget);
        expect(t.getSize(reaction).height, 20);
        await capture('main-rest');
        if (item == 'human-author') {
          final row = find.byWidgetPredicate(
            (widget) => widget is RaftMessageRow && widget.author == 'artin',
          );
          expect(row, findsOneWidget);
          expect(
            find.descendant(of: row, matching: find.text('Owner')),
            findsOneWidget,
          );
          final editor = find.descendant(
            of: find.byType(RaftComposer),
            matching: find.byType(TextField),
          );
          final composerState = t.state(find.byType(RaftComposer));
          expect(t.widget<TextField>(editor).controller!.text, '');
          await t.tap(find.descendant(of: row, matching: find.text('artin')));
          await t.pump();
          expect(t.widget<TextField>(editor).controller!.text, '@artin ');
          expect(t.widget<TextField>(editor).focusNode!.hasFocus, true);
          expect(
            identical(t.state(find.byType(RaftComposer)), composerState),
            true,
          );
          expect(w.threadParent, isNull);
          expect(
            w.messages
                .firstWhere((message) => message.json['senderName'] == 'artin')
                .string('senderType'),
            'user',
          );
          await capture('human-author-mention');
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
          await t.pump(const Duration(milliseconds: 200));
          w.dispose();
          await client.stream.close();
          continue;
        }
        if (item == 'reaction-add' && viewport.width < 768) {
          final add = find.byKey(const ValueKey('message-reaction-add'));
          expect(add, findsOneWidget);
          expect(t.getSize(add).height, 20);
          await t.tap(add);
          await until(
            () => find.byType(RaftQuickReactionPicker).evaluate().isNotEmpty,
          );
          await capture('reaction-picker-open');
          await t.sendKeyEvent(LogicalKeyboardKey.escape);
          await t.pump(const Duration(milliseconds: 800));
          expect(find.byType(RaftQuickReactionPicker), findsNothing);
          expect(
            find.byKey(const ValueKey('raft-tooltip-surface')),
            findsNothing,
          );
          await capture('reaction-picker-closed');
        }
        final mainComposer = t.state(find.byType(RaftComposer));
        await t.enterText(
          find.byType(TextField).last,
          'Public retained draft 中文',
        );
        await t.pump();
        await capture('main-draft');
        if (item == 'reaction-add' && viewport.width < 768) {
          final before = t.state(find.byType(RaftComposer));
          await t.tap(find.byKey(const ValueKey('message-reaction-add')));
          await until(
            () => find.byType(RaftQuickReactionPicker).evaluate().isNotEmpty,
          );
          expect(
            t.widget<TextField>(find.byType(TextField).last).controller!.text,
            'Public retained draft 中文',
          );
          expect(identical(t.state(find.byType(RaftComposer)), before), true);
          await capture('reaction-picker-open-draft');
          await t.sendKeyEvent(LogicalKeyboardKey.escape);
          await t.pump(const Duration(milliseconds: 800));
          expect(find.byType(RaftQuickReactionPicker), findsNothing);
          expect(
            find.byKey(const ValueKey('raft-tooltip-surface')),
            findsNothing,
          );
          expect(identical(t.state(find.byType(RaftComposer)), before), true);
          expect(
            t.widget<TextField>(find.byType(TextField).last).controller!.text,
            'Public retained draft 中文',
          );
          await capture('reaction-picker-closed-draft');
        }
        if (item == 'composer' || item == 'header' || item == 'reaction-add') {
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
          await t.pump(const Duration(milliseconds: 200));
          w.dispose();
          await client.stream.close();
          continue;
        }
        await t.tap(find.byKey(const ValueKey('panel-tab-tasks')));
        await until(
          () => find
              .text(
                fixture['routes']['GET /tasks/channel/channel-design']['tasks'][0]['title'],
              )
              .evaluate()
              .isNotEmpty,
        );
        expect(
          client.requests.where(
            (r) => r == 'GET /tasks/channel/channel-design',
          ),
          isNotEmpty,
        );
        await capture('tasks-tab');
        await t.tap(find.byKey(const ValueKey('panel-tab-files')));
        await until(
          () => find.text('Android visual notes.pdf').evaluate().isNotEmpty,
        );
        expect(find.byType(SourceChannelFilesView), findsOneWidget);
        expect(
          client.requests.where(
            (r) => r.startsWith('GET /channels/channel-design/files?limit=50'),
          ),
          isNotEmpty,
        );
        await capture('files-tab');
        await t.tap(find.byKey(const ValueKey('panel-tab-chat')));
        await until(() => find.byType(RaftComposer).evaluate().length == 1);
        expect(t.state(find.byType(RaftComposer)), same(mainComposer));
        expect(
          t.widget<TextField>(find.byType(TextField).last).controller!.text,
          'Public retained draft 中文',
        );
        await capture('chat-tab-retained-draft');
        if (item == 'tabs-date') {
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
          await t.pump(const Duration(milliseconds: 200));
          w.dispose();
          await client.stream.close();
          continue;
        }
        final replies = find.byType(RaftInlineThreadSurface);
        expect(replies, findsOneWidget);
        await t.tap(replies);
        await until(
          () =>
              w.threadParent != null &&
              !w.threadLoading &&
              w.replies.length == 2,
        );
        await until(
          () => find
              .byWidgetPredicate(
                (widget) => widget is RaftChatView && widget.thread,
              )
              .evaluate()
              .isNotEmpty,
        );
        for (var i = 0; i < 30; i++) {
          await t.pump(const Duration(milliseconds: 16));
        }
        if (item == 'thread-composer') {
          final visibleEditors = find.byType(TextField);
          expect(visibleEditors, findsOneWidget);
          final field = t.widget<TextField>(visibleEditors);
          expect(field.decoration?.hintText, 'Message thread');
          expect(field.focusNode!.hasFocus, !Platform.isAndroid);
          expect(field.controller!.text, '');
          final beforeFocus = t.state(find.byType(RaftComposer));
          await capture('thread-open');
          await t.tap(visibleEditors);
          await t.pump();
          expect(field.focusNode!.hasFocus, isTrue);
          expect(t.state(find.byType(RaftComposer)), same(beforeFocus));
          expect(w.drafts[w.draftScope()] ?? '', 'Public retained draft 中文');
          await capture('thread-input-focused');
        } else {
          await capture('thread-open');
        }
        await t.tap(find.byTooltip('Close thread').first);
        await until(
          () =>
              w.threadParent == null &&
              find.byType(RaftComposer).evaluate().length == 1 &&
              find
                  .byWidgetPredicate(
                    (widget) => widget is RaftChatView && widget.thread,
                  )
                  .evaluate()
                  .isEmpty,
        );
        final active = find.byType(RaftComposer);
        expect(active, findsOneWidget);
        expect(t.state(active), same(mainComposer));
        expect(
          t.widget<TextField>(find.byType(TextField).last).controller!.text,
          'Public retained draft 中文',
        );
        await capture('thread-close-retained-draft');
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(milliseconds: 200));
        w.dispose();
        await client.stream.close();
      }
      await File('${output.path}/$platform-primary-result.json').writeAsString(
        jsonEncode({
          'sourceHash': hash,
          'runId': runId,
          'completed': true,
          'captures': captures.length,
          'item': item,
          'scope': 'controlled mounted main/thread cohort; no API/auth/pixel certification',
        }),
      );
      // Give the host collector a real opportunity to read this terminal device
      // receipt before flutter test uninstalls its owned debug app.
      if (Platform.isAndroid) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 600)),
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
