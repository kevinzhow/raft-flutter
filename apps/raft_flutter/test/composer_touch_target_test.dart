// Composer attach / send tap-area regression (owner report: image-attach and
// Send became hard to tap after the section pager reserved Android's Back
// edges for every control inside it). Probes a 0.5dp grid around each
// RaftComposerAction on the real phone channel page (412x915 dp, DPR 2.625,
// 48px gesture inset) and measures the hit-testable region.
@Tags(['slow'])
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

/// Pixel 8-class phone: 412x915 dp at DPR 2.625, 48px gesture bar.
const _dpr = 2.625;
const _size = Size(1081, 2402);
const _gesturePx = 48.0;
const _edgeDp = 40.0;

/// The two attach buttons sit 6-8dp apart and split that gap, so they reach
/// 40.5-41.5dp wide; every button reaches 48dp tall. Before the regression
/// (15865354) the Android Back-edge reservation cut image / send to 8-10dp.
const _minWidth = 40.0, _minHeight = 44.0;

Map<String, dynamic> _message(String id, String text, int seq) => {
  'id': id,
  'channelId': 'ca',
  'seq': '$seq',
  'senderId': 'alice',
  'senderName': 'Alice',
  'content': text,
  'createdAt': '2026-10-10T00:0$seq:00Z',
};

Future<void> _settle(WidgetTester t, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// The conversation under test: a channel, a human DM or an agent DM.
enum _Kind {
  channel('ca', null),
  humanDm('dm-human', 'user'),
  agentDm('dm-agent', 'agent');

  const _Kind(this.id, this.peerType);
  final String id;
  final String? peerType;
}

/// Mounts the real phone shell with a gesture-bar inset and opens [kind].
Future<void> _openPhoneChannel(WidgetTester t, String theme, _Kind kind) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  final f = RootFixture();
  f.overrides['GET /messages/channel/${kind.id}'] = (_) => {
    'messages': [
      for (var i = 1; i <= 4; i++)
        {..._message('m$i', 'Message $i', i), 'channelId': kind.id},
    ],
    'hasMore': false,
    'hasNewer': false,
  };
  if (kind.peerType != null) {
    f.overrides['GET /channels/dm'] = (_) => [
      {
        'id': kind.id,
        'name': 'Peer',
        'type': 'dm',
        'serverId': 'alpha',
        'joined': true,
        'latestSeq': '1',
        'peerType': kind.peerType,
        'peerId': 'peer-1',
        'peerDisplayName': 'Peer',
        'peerName': 'peer',
      },
    ];
    f.overrides['POST /channels/${kind.id}/read'] = (_) => {};
  }
  await f.mount(t, theme, 412, uri: Uri.parse('/s/alpha'));
  t.view.devicePixelRatio = _dpr;
  t.view.physicalSize = _size;
  t.view.viewPadding = const FakeViewPadding(top: 100, bottom: _gesturePx);
  t.view.padding = const FakeViewPadding(top: 100, bottom: _gesturePx);
  // Android gesture navigation reserves the display's side edges for Back
  // (Flutter reports them as systemGestureInsets). 40dp is typical OEM width.
  t.view.systemGestureInsets = const FakeViewPadding(
    left: _edgeDp * _dpr,
    right: _edgeDp * _dpr,
    bottom: _gesturePx,
  );
  addTearDown(() {
    debugDefaultTargetPlatformOverride = null;
    t.view.resetPadding();
    t.view.resetViewPadding();
    t.view.resetViewInsets();
  });
  await f.flush(t);
  await _settle(t);
  await t.tap(find.byKey(ValueKey('sidebar-channel-${kind.id}')));
  await f.flush(t);
  await _settle(t);
  // The probe must run on the conversation under test, not the sidebar.
  expect(
    find.text(kind == _Kind.channel ? 'Message #general-a' : 'Message @Peer'),
    findsOneWidget,
    reason: 'composer of ${kind.name} is not on screen',
  );
}

/// Hit-testable bounds (dp) of [action], found by probing a grid around it.
Rect probeHitRegion(WidgetTester t, Finder action) {
  final root = t.renderObject<RenderBox>(action.first);
  final visual = t.getRect(action.first);
  double? left, top, right, bottom;
  const step = .5, reach = 40.0;
  for (var y = visual.top - reach; y <= visual.bottom + reach; y += step) {
    for (var x = visual.left - reach; x <= visual.right + reach; x += step) {
      final result = t.hitTestOnBinding(Offset(x, y));
      final hit = result.path.any((entry) {
        final target = entry.target;
        if (target is! RenderObject) return false;
        RenderObject? node = target;
        while (node != null) {
          if (identical(node, root)) return true;
          node = node.parent;
        }
        return false;
      });
      if (!hit) continue;
      left = left == null ? x : (x < left ? x : left);
      right = right == null ? x : (x > right ? x : right);
      top = top == null ? y : (y < top ? y : top);
      bottom = bottom == null ? y : (y > bottom ? y : bottom);
    }
  }
  if (left == null) return Rect.zero;
  return Rect.fromLTRB(left, top!, right! + step, bottom! + step);
}

void main() {
  for (final kind in _Kind.values) {
    for (final theme in const ['light']) {
      testWidgets(
        'composer attach and send keep a phone-sized tap area on Android gesture navigation ${kind.name} $theme',
        (t) async {
          await _openPhoneChannel(t, theme, kind);
          final actions = find.byType(RaftComposerAction);
          expect(actions, findsAtLeastNWidgets(2));
          final report = StringBuffer();
          final failures = <String>[];
          for (final e in actions.evaluate()) {
            final w = e.widget as RaftComposerAction;
            final f = find.byWidget(w);
            final visual = t.getRect(f);
            final hit = probeHitRegion(t, f);
            report.writeln(
              'PROBE ${kind.name} $theme ${w.glyph.name} visual=${visual.width}x${visual.height}'
              ' hit=${hit.width}x${hit.height} at ${hit.left},${hit.top}',
            );
            if (hit.width < _minWidth || hit.height < _minHeight) {
              failures.add('${w.glyph.name} tappable $hit (visual $visual)');
            }
          }
          stdout.write(report);
          debugDefaultTargetPlatformOverride = null;
          expect(failures, isEmpty, reason: '$report');
        },
      );
    }
  }
}
