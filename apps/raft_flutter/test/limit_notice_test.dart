import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/attachment_limit_decision.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/composer_attachments_view.dart';
import 'package:raft_flutter/features/limit_notice.dart';
import 'package:raft_flutter/platform/web_billing.dart';
import 'package:raft_ui/raft_ui.dart';

// WP-BILL part C: the Free-plan limit notice. Where Web v1.24 opens its
// upgrade dialog for a limit, the app shows the dialog header's words and one
// "Upgrade to Pro" that opens the Web's Plan & Billing page for that paywall.
const mb = 1024 * 1024;

class _Client extends RaftClient {
  _Client(this.capabilities)
    : super(
        origin: 'https://api.raft.build',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
    serverId = 's';
  }
  Map<String, dynamic> capabilities;
  final uploaded = <String>[];
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async =>
      path == '/attachments/upload-capabilities' ? capabilities : [];

  @override
  Future<List<Map<String, dynamic>>> upload(
    String channelId,
    Uint8List bytes,
    String filename, {
    UploadCancellation? cancellation,
    void Function(int, int)? onProgress,
    String? mimeType,
  }) async {
    uploaded.add(filename);
    return [
      {'id': 'att-$filename'},
    ];
  }

  @override
  void connect() {}
  @override
  void joinChannel(String id) {}
}

String _text(String key, Map<String, Object> args) => args.entries.fold(
  key,
  (text, e) => text.replaceAll('{${e.key}}', '${e.value}'),
);

({String name, Uint8List bytes}) _file(String name, int size) =>
    (name: name, bytes: Uint8List(size));

class _Rig {
  _Rig(this.w, this.client, this.opened);
  final WorkspaceController w;
  final _Client client;
  final List<Uri> opened;
}

Future<_Rig> _boot(
  WidgetTester t, {
  required Map<String, dynamic> capabilities,
  String plan = 'free',
  Size size = const Size(390, 844),
  TargetPlatform platform = TargetPlatform.linux,
  Locale? locale,
}) async {
  final opened = <Uri>[];
  webBillingLauncher = (uri) async {
    opened.add(uri);
    return true;
  };
  final client = _Client(capabilities);
  final w = WorkspaceController(client)
    ..server = RaftRecord({
      'id': 's',
      'name': 'Acme',
      'slug': 'acme',
      'role': 'owner',
      'plan': plan,
    })
    ..channel = RaftChannel({'id': 'channel', 'name': 'general'});
  await t.binding.setSurfaceSize(size);
  addTearDown(() async {
    webBillingLauncher = (_) async => false;
    await t.pumpWidget(const SizedBox.shrink());
    w.dispose();
    await client.dispose();
    await t.binding.setSurfaceSize(null);
  });
  await t.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: raftTheme(platform: platform),
      builder: (context, child) => RaftToastHost(child: child!),
      home: LimitNoticeHost(
        controller: w,
        queue: w.composer.uploads.limitNotices,
        child: Scaffold(
          body: Builder(
            builder: (context) => ListenableBuilder(
              listenable: Listenable.merge([
                w,
                w.composer.changes(w.draftScope()),
              ]),
              builder: (context, _) =>
                  composerAttachmentsFor(
                    context,
                    w,
                    thread: false,
                    onPreview: (_) {},
                  ) ??
                  const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    ),
  );
  await t.pump();
  return _Rig(w, client, opened);
}

Future<void> _select(
  WidgetTester t,
  _Rig rig,
  List<({String name, Uint8List bytes})> files,
) async {
  await rig.w.attachSelection(files, text: _text);
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  const fileSizeCaps = {'maxBytes': 50 * mb};

  group('copy: the words of the Web upgrade dialog header', () {
    Future<LimitNoticeCopy> copy(
      WidgetTester t, {
      required String gate,
      UploadLimitContext? upload,
      HistoryLimitNotice? history,
      ExternalLimitNotice? external,
      int agentTries = 0,
      Locale? locale,
    }) async {
      late LimitNoticeCopy out;
      await t.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: raftTheme(),
          home: Builder(
            builder: (context) {
              out = limitNoticeCopyFor(
                context,
                serverName: 'Acme',
                gate: gate,
                upload: upload,
                history: history,
                external: external,
                agentTries: agentTries,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return out;
    }

    testWidgets('file size: one file and several', (t) async {
      var c = await copy(
        t,
        gate: WebBillingGate.uploadFileSize,
        upload: const UploadLimitContext.fileSize([
          (name: 'demo.mov', size: 63 * mb),
        ]),
      );
      expect(c.title, 'Upload larger files');
      expect(
        c.hint,
        'demo.mov is 63 MB. Free uploads files up to 50 MB each; on Pro, a file can be up to 200 MB.',
      );
      c = await copy(
        t,
        gate: WebBillingGate.uploadFileSize,
        upload: const UploadLimitContext.fileSize([
          (name: 'a', size: 60 * mb),
          (name: 'b', size: 70 * mb),
        ]),
      );
      expect(
        c.hint,
        '2 files are over 50 MB. Free uploads files up to 50 MB each; on Pro, a file can be up to 200 MB.',
      );
      c = await copy(t, gate: WebBillingGate.uploadFileSize);
      expect(
        c.hint,
        'Free uploads files up to 50 MB each. On Pro, a file can be up to 200 MB.',
      );
    });

    testWidgets('monthly quota: some left, used up, no file named', (t) async {
      const quota = MonthlyUploadQuota(
        month: '2026-11',
        limitBytes: 100 * mb,
        remainingBytes: 12 * mb,
      );
      var c = await copy(
        t,
        gate: WebBillingGate.uploadMonthlyQuota,
        upload: const UploadLimitContext.monthlyQuota(quota, [
          (name: 'deck.pdf', size: 30 * mb),
        ]),
      );
      expect(c.title, 'Not enough uploads left this month');
      expect(
        c.hint,
        "deck.pdf is 30 MB, and Acme has 12 MB left of this month's 100 MB of uploads; it resets on Dec 1. Pro has no monthly limit.",
      );
      c = await copy(
        t,
        gate: WebBillingGate.uploadMonthlyQuota,
        upload: const UploadLimitContext.monthlyQuota(quota, [
          (name: 'a', size: 30 * mb),
          (name: 'b', size: 30 * mb),
        ]),
      );
      expect(
        c.hint,
        "Acme has 12 MB left of this month's 100 MB of uploads, not enough for these 2 files; it resets on Dec 1. Pro has no monthly limit.",
      );
      const empty = MonthlyUploadQuota(
        month: '2026-11',
        limitBytes: 100 * mb,
        remainingBytes: 1000,
      );
      c = await copy(
        t,
        gate: WebBillingGate.uploadMonthlyQuota,
        upload: const UploadLimitContext.monthlyQuota(empty, []),
      );
      expect(c.title, "This month's uploads are used up");
      expect(
        c.hint,
        "Acme has used this month's 100 MB of uploads; it resets on Dec 1. Pro has no monthly limit.",
      );
    });

    testWidgets('history, external channel and general', (t) async {
      var c = await copy(
        t,
        gate: WebBillingGate.history,
        history: const HistoryLimitNotice.counted(
          scope: HistoryLimitScope.channel,
          count: 1200,
          channel: '#roadmap',
        ),
        agentTries: 3,
      );
      expect(c.title, 'See your whole chat history');
      expect(
        c.hint,
        "#roadmap has 1,200 messages older than 30 days that you and your agents can't read on Free, and your agents ran into this 3 times in the past 7 days.",
      );
      c = await copy(
        t,
        gate: WebBillingGate.history,
        history: const HistoryLimitNotice.counted(
          scope: HistoryLimitScope.thread,
          count: 1,
          capped: false,
        ),
        agentTries: 1,
      );
      expect(
        c.hint,
        "This thread has 1 reply older than 30 days that you and your agents can't read on Free, and your agents ran into this once in the past 7 days.",
      );
      c = await copy(t, gate: WebBillingGate.history);
      expect(
        c.hint,
        "On Free, you and your agents can only read the last 30 days of messages, while on Pro all of Acme's history can be read and searched.",
      );
      c = await copy(
        t,
        gate: WebBillingGate.externalChannelFreeLimit,
        external: const ExternalLimitNotice.slot(
          channel: '#launch',
          openInvite: true,
        ),
      );
      expect(c.title, 'Share more channels outside Acme');
      expect(
        c.hint,
        'Free includes 1 external channel, and Acme has an open invite to #launch. On Pro, Acme can share as many as it needs.',
      );
      c = await copy(t, gate: WebBillingGate.general);
      expect(c.title, 'Upgrade Acme to Pro');
      expect(
        c.hint,
        'Pro lifts the Free limits on chat history, file uploads and Joint Channels.',
      );
    });

    testWidgets('Chinese is the Web zh-cn text', (t) async {
      final c = await copy(
        t,
        gate: WebBillingGate.uploadFileSize,
        upload: const UploadLimitContext.fileSize([
          (name: 'demo.mov', size: 63 * mb),
        ]),
        locale: const Locale('zh', 'CN'),
      );
      expect(c.title, '上传更大的文件');
      expect(c.hint, 'demo.mov 有 63 MB。免费版单个文件最大 50 MB，升级到 Pro 可以到 200 MB。');
    });
  });

  group('selection on a Free server', () {
    final sizes = <(String, Size, TargetPlatform)>[
      ('fold 856x944 (Android)', const Size(856, 944), TargetPlatform.android),
      ('fold 944x856 (Android)', const Size(944, 856), TargetPlatform.android),
      (
        'narrow desktop 390x844 (Linux)',
        const Size(390, 844),
        TargetPlatform.linux,
      ),
    ];
    for (final (name, size, platform) in sizes) {
      testWidgets(
        'a file over Free but within Pro: notice, Upgrade opens the Web, no row ($name)',
        (t) async {
          final rig = await _boot(
            t,
            capabilities: fileSizeCaps,
            size: size,
            platform: platform,
          );
          await _select(t, rig, [_file('demo.mov', 63 * mb)]);
          expect(rig.w.uploads(), isEmpty);
          expect(find.byKey(const ValueKey('limit-notice')), findsOneWidget);
          expect(find.text('Upload larger files'), findsOneWidget);
          expect(
            find.text(
              'demo.mov is 63 MB. Free uploads files up to 50 MB each; on Pro, a file can be up to 200 MB.',
            ),
            findsOneWidget,
          );
          expect(find.text('Upgrade to Pro'), findsOneWidget);
          expect(find.text('Close'), findsOneWidget);
          expect(rig.opened, isEmpty, reason: 'nothing opens by itself');

          await t.tap(find.byKey(const ValueKey('limit-notice-upgrade')));
          await t.pump();
          await t.pump(const Duration(milliseconds: 300));
          expect(
            rig.opened.single.toString(),
            startsWith('https://app.raft.build/s/acme/settings/billing'),
          );
          expect(rig.opened.single.queryParameters, {
            'upgrade': 'upload_file_size',
            'upgradeCanceled': '1',
          });
          // Resolved: the notice is gone and does not come back by itself.
          expect(find.byKey(const ValueKey('limit-notice')), findsNothing);
          await t.pump(const Duration(seconds: 1));
          expect(find.byKey(const ValueKey('limit-notice')), findsNothing);
          expect(rig.client.uploaded, isEmpty);
        },
      );
    }

    testWidgets(
      'a browser that cannot open shows a toast, not a silent close',
      (t) async {
        final rig = await _boot(t, capabilities: fileSizeCaps);
        webBillingLauncher = (_) async => false;
        await _select(t, rig, [_file('demo.mov', 63 * mb)]);
        await t.tap(find.byKey(const ValueKey('limit-notice-upgrade')));
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));
        expect(find.text('Could not open this address.'), findsOneWidget);
      },
    );

    testWidgets('Close and Escape leave without opening the Web', (t) async {
      final rig = await _boot(t, capabilities: fileSizeCaps);
      await _select(t, rig, [_file('demo.mov', 63 * mb)]);
      await t.tap(find.text('Close'));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('limit-notice')), findsNothing);
      await _select(t, rig, [_file('demo2.mov', 63 * mb)]);
      expect(find.byKey(const ValueKey('limit-notice')), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('limit-notice')), findsNothing);
      expect(rig.opened, isEmpty);
    });

    testWidgets('files beyond the monthly quota: quota notice and gate', (
      t,
    ) async {
      final rig = await _boot(
        t,
        capabilities: {
          'maxBytes': 50 * mb,
          'monthlyUpload': {
            'month': '2026-11',
            'limitBytes': 100 * mb,
            'remainingBytes': 12 * mb,
          },
        },
      );
      await _select(t, rig, [
        _file('deck.pdf', 30 * mb),
        _file('note.txt', 1000),
      ]);
      expect(rig.w.uploads().map((d) => d.filename), ['note.txt']);
      expect(find.text('Not enough uploads left this month'), findsOneWidget);
      expect(
        find.text(
          "deck.pdf is 30 MB, and Acme has 12 MB left of this month's 100 MB of uploads; it resets on Dec 1. Pro has no monthly limit.",
        ),
        findsOneWidget,
      );
      await t.tap(find.byKey(const ValueKey('limit-notice-upgrade')));
      await t.pump(const Duration(milliseconds: 300));
      expect(
        rig.opened.single.queryParameters['upgrade'],
        'upload_monthly_quota',
      );
      expect(rig.client.uploaded, ['note.txt']);
    });

    testWidgets(
      'a file over Pro too stays in the row, failed, with its reason; no notice',
      (t) async {
        final handle = t.ensureSemantics();
        final rig = await _boot(t, capabilities: fileSizeCaps);
        await _select(t, rig, [_file('disk.iso', 201 * mb)]);
        expect(find.byKey(const ValueKey('limit-notice')), findsNothing);
        final kept = rig.w.uploads().single;
        expect(kept.notAttached!.reason, NotAttachedReason.size);
        expect(find.text('Too large'), findsOneWidget);
        expect(
          find.bySemanticsLabel(
            "It's 201 MB. Free uploads files up to 50 MB each, and Pro up to 200 MB. Share a link instead.",
          ),
          findsWidgets,
        );
        // Sending is blocked until it is removed.
        expect(
          composerSendBlockNotice(
            t.element(find.byType(Scaffold)),
            rig.w.uploads(),
          ),
          "Remove files that can't be attached",
        );
        rig.w.removeUpload(kept);
        await t.pump();
        expect(find.text('Too large'), findsNothing);
        handle.dispose();
      },
    );

    testWidgets('an empty file and an unknown ceiling stay failed', (t) async {
      final rig = await _boot(t, capabilities: fileSizeCaps);
      await _select(t, rig, [_file('empty.txt', 0)]);
      expect(find.text('Empty'), findsOneWidget);
      rig.client.capabilities = {};
      await _select(t, rig, [_file('a.txt', 10)]);
      expect(find.text('Not checked'), findsOneWidget);
      expect(find.byKey(const ValueKey('limit-notice')), findsNothing);
    });
  });

  group('selection on a Pro server', () {
    testWidgets('files within its ceiling attach with no notice', (t) async {
      final rig = await _boot(
        t,
        plan: 'pro',
        capabilities: const {'maxBytes': 200 * mb},
      );
      await _select(t, rig, [_file('demo.mov', 63 * mb)]);
      expect(find.byKey(const ValueKey('limit-notice')), findsNothing);
      expect(rig.client.uploaded, ['demo.mov']);
    });

    testWidgets('a file over its ceiling stays failed: no upgrade can lift it', (
      t,
    ) async {
      final handle = t.ensureSemantics();
      final rig = await _boot(
        t,
        plan: 'pro',
        capabilities: const {'maxBytes': 200 * mb},
      );
      await _select(t, rig, [_file('disk.iso', 201 * mb)]);
      expect(find.byKey(const ValueKey('limit-notice')), findsNothing);
      expect(find.text('Too large'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          "It's 201 MB. Files can be up to 200 MB each. Share a link instead.",
        ),
        findsWidgets,
      );
      handle.dispose();
    });
  });
}
