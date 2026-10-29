// A layout-class change (fold / unfold, rotation, desktop window resize, the
// soft keyboard) must never throw away what the user has open. Every kind of
// page and panel is opened, then the window is moved across the 768 dp cut and
// back, and the keyboard is raised on touch sizes (inset only, and inset plus
// a shrunken window as `adjustResize` devices report it): the location, the
// page stack, the typed draft and the pages pushed without a URL must all
// still be there.
@Tags(['slow'])
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/forward_composer_page.dart';
import 'package:raft_flutter/features/mobile_workspace_pages.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_client/raft_client.dart';

import 'app_global_server_selector_test.dart' show RootFixture;
import 'edge_to_edge_audit_test.dart' show richFixture, settle, openChannel;
import 'foldable_layout_routing_test.dart'
    show mountedPages, phoneShown, wideShown, where;

const dpr = 2.625;
const folded = Size(360, 780), phone = Size(412, 900);
const unfolded = Size(856, 944), desktop = Size(1280, 800);
// Compact but rail-sized (600-767 dp): a rotated phone / split window.
const landscape = Size(700, 360);

const dm = {
  'id': 'dm1',
  'name': 'cindy',
  'type': 'dm',
  'joined': true,
  'peerId': 'agent-1',
  'peerType': 'agent',
  'peerDisplayName': 'Cindy',
};

Future<RootFixture> mount(WidgetTester t, Size dp, String path) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  final f = richFixture();
  f.overrides['GET /agents'] = (_) => [
    {
      'id': 'agent-1',
      'name': 'cindy',
      'displayName': 'Cindy',
      'description': 'Engineering operator',
      'status': 'online',
    },
  ];
  f.overrides['GET /channels/dm'] = (_) => [dm];
  f.overrides['GET /channels/dm1'] = (_) => dm;
  f.overrides['GET /messages/channel/dm1'] = (_) => {
    'messages': <dynamic>[],
    'hasMore': false,
    'hasNewer': false,
  };
  f.overrides['POST /channels/dm1/read'] = (_) => {};
  await f.mount(t, 'elegant-light', dp.width, uri: Uri.parse(path));
  t.view.devicePixelRatio = dpr;
  t.view.physicalSize = dp * dpr;
  const top = 40 * dpr;
  t.view.viewPadding = const FakeViewPadding(top: top, bottom: 126);
  t.view.padding = const FakeViewPadding(top: top, bottom: 126);
  addTearDown(() {
    t.view.resetPadding();
    t.view.resetViewPadding();
    t.view.resetViewInsets();
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
  });
  await f.flush(t);
  await settle(t);
  return f;
}

Future<void> resize(WidgetTester t, RootFixture f, Size dp) async {
  t.view.physicalSize = dp * dpr;
  await f.flush(t);
  await settle(t);
}

/// The keyboard: always the inset; [shrink] also takes the keyboard's height
/// off the window the way an `adjustResize` activity does.
Future<void> keyboard(
  WidgetTester t,
  RootFixture f,
  Size dp, {
  required bool up,
  bool shrink = false,
}) async {
  const kb = 300.0;
  t.view.viewInsets = FakeViewPadding(bottom: up ? kb * dpr : 0);
  if (shrink) {
    t.view.physicalSize = Size(dp.width, dp.height - (up ? kb : 0)) * dpr;
  }
  await f.flush(t);
  await settle(t);
}

/// RenderFlex overflows at the tiny sizes of this matrix (a 360 dp window with
/// the keyboard up, a rotated phone) are a different audit's business
/// (text_scale_audit, the layout suites); this matrix asserts that navigation
/// state survives, so they are not failures here.
void scenario(String name, Future<void> Function(WidgetTester t) body) =>
    testWidgets(name, (t) async {
      final prior = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        prior?.call(details);
      };
      try {
        await body(t);
        expect(t.takeException(), isNull);
      } finally {
        FlutterError.onError = prior;
        debugDefaultTargetPlatformOverride = null;
      }
    });

bool wideAt(Size dp) => dp.width >= 768;

void expectShell(WidgetTester t, Size dp, String reason) {
  expect(phoneShown(t), !wideAt(dp), reason: 'phone shell at $dp: $reason');
  expect(wideShown(t), wideAt(dp), reason: 'wide shell at $dp: $reason');
}

/// Every kind of page / panel the location can name.
const pages = <String, String>{
  'channel': '/s/alpha/channel/ca',
  'dm': '/s/alpha/dm/dm1',
  'thread': '/s/alpha/channel/ca?thread=ca:ma',
  'agent profile': '/s/alpha/channel/ca?profile=agent:agent-1',
  'human profile': '/s/alpha/channel/ca?profile=human:bob',
  'thread + profile': '/s/alpha/channel/ca?thread=ca:ma&profile=human:bob',
  'tasks': '/s/alpha/tasks',
  'members': '/s/alpha/members',
  'settings': '/s/alpha/settings',
  'appearance': '/s/alpha/settings/appearance',
  'agent page': '/s/alpha/agent/agent-1',
  'human page': '/s/alpha/human/bob',
  'search': '/s/alpha/search',
  'activity': '/s/alpha/activity',
};

/// One walk through every layout class the app meets: fold / unfold, rotate,
/// a phone-width desktop window and back, wide-to-wide, and the keyboard on
/// each touch size (inset only, then inset plus a shrunken window).
const walk = <(String, Size)>[
  ('folded', folded),
  ('unfolded', unfolded),
  ('folded again', folded),
  ('phone', phone),
  ('desktop', desktop),
  ('phone again', phone),
  ('rotated phone', landscape),
  ('portrait again', phone),
  ('desktop again', desktop),
  ('narrow desktop window', landscape),
  ('desktop third time', desktop),
  ('unfolded again', unfolded),
];

void main() {
  for (final MapEntry(key: kind, value: path) in pages.entries) {
    scenario('$kind survives every layout class and the keyboard', (t) async {
      final f = await mount(t, folded, path);
      final start = where(f, t);
      final stack = mountedPages(t);
      expectShell(t, folded, 'start');
      for (final (label, dp) in walk) {
        await resize(t, f, dp);
        expectShell(t, dp, '$kind at $label');
        expect(where(f, t), start, reason: '$kind kept its location: $label');
      }
      // Back on a phone-sized window the stack is the one we started with.
      await resize(t, f, folded);
      expect(mountedPages(t), stack, reason: '$kind phone page stack');
      for (final dp in [folded, phone, unfolded]) {
        await resize(t, f, dp);
        final field = find.byType(EditableText);
        if (field.evaluate().isNotEmpty) {
          await t.tap(field.last, warnIfMissed: false);
          await settle(t, 3);
        }
        for (final shrink in [false, true]) {
          await keyboard(t, f, dp, up: true, shrink: shrink);
          expectShell(t, dp, '$kind keyboard up at $dp shrink=$shrink');
          expect(
            where(f, t),
            start,
            reason: '$kind keyboard up at $dp shrink=$shrink',
          );
          // A window the keyboard really shrinks (adjustResize) can turn a
          // 360 dp-wide portrait phone into the rail's aspect (see
          // RaftWindowClass.isRailSized): the root tabs, and so the stack,
          // may differ there. The inset alone changes nothing.
          if (!wideAt(dp) && !shrink) {
            expect(
              mountedPages(t),
              stack,
              reason: '$kind pages, keyboard up at $dp',
            );
          }
          await keyboard(t, f, dp, up: false, shrink: shrink);
          expect(where(f, t), start, reason: '$kind keyboard down at $dp');
        }
        FocusManager.instance.primaryFocus?.unfocus();
      }
    });
  }

  // The composer draft belongs to the conversation, not to the layout.
  for (final path in ['/s/alpha/channel/ca', '/s/alpha/dm/dm1']) {
    scenario('the draft in $path survives every layout class', (t) async {
      final f = await mount(t, phone, path);
      if (find.byType(EditableText).evaluate().isEmpty) {
        await openChannel(t, f);
      }
      await t.enterText(find.byType(EditableText).last, 'half-written');
      await settle(t, 3);
      for (final (label, dp) in walk) {
        await resize(t, f, dp);
        expect(
          find.text('half-written'),
          findsOneWidget,
          reason: 'draft kept: $label',
        );
      }
    });
  }

  // Pages pushed on the app navigator with no URL (forward composer, fleet
  // detail, notification centre pages...) belong to the user's task, not to
  // the layout: crossing the cut leaves them open.
  scenario('a page pushed without a URL survives every layout class', (
    t,
  ) async {
    final f = await mount(t, phone, '/s/alpha');
    final ctx = t.element(find.byType(WorkspaceView).first);
    final w = f.workspace(t);
    final nav = Navigator.of(ctx, rootNavigator: true);
    nav.push<void>(
      MaterialPageRoute(
        builder: (_) => const Scaffold(body: Text('Pushed page')),
      ),
    );
    nav.push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => ForwardComposerPage(
          controller: w,
          messages: [RaftMessage(forwardable)],
        ),
      ),
    );
    await settle(t);
    expect(find.byType(ForwardComposerPage), findsOneWidget);
    for (final (label, dp) in walk) {
      await resize(t, f, dp);
      expect(
        find.byType(ForwardComposerPage),
        findsOneWidget,
        reason: 'forward composer kept: $label',
      );
    }
    nav.pop();
    await settle(t);
    expect(find.text('Pushed page'), findsOneWidget);
    for (final (label, dp) in walk.reversed) {
      await resize(t, f, dp);
      expect(find.text('Pushed page'), findsOneWidget, reason: label);
    }
  });

  // The same opened the way the app opens it, from inside a phone page
  // (`Navigator.of(context)` there is the phone shell's own navigator, which
  // the wide layout does not have): the helper must reach the app navigator.
  scenario('a forward composer opened from a phone page survives unfolding', (
    t,
  ) async {
    final f = await mount(t, folded, '/s/alpha/channel/ca');
    final inPage = find.descendant(
      of: find.byType(MobileWorkspacePages),
      matching: find.byType(Scaffold),
    );
    expect(inPage, findsWidgets);
    unawaited(
      showForwardComposerPage(t.element(inPage.first), f.workspace(t), [
        RaftMessage(forwardable),
      ]),
    );
    await settle(t);
    expect(find.byType(ForwardComposerPage), findsOneWidget);
    for (final (label, dp) in walk) {
      await resize(t, f, dp);
      expect(
        find.byType(ForwardComposerPage),
        findsOneWidget,
        reason: 'kept: $label',
      );
    }
  });
}

const forwardable = {
  'id': 'ma',
  'channelId': 'ca',
  'seq': '1',
  'messageType': 'chat',
  'content': 'Forward me',
  'senderId': 'alice',
  'senderType': 'user',
  'createdAt': '2026-06-22T02:30:00.000Z',
};
