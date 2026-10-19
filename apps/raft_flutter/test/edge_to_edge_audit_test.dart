// Edge-to-edge regression suite (docs/architecture.md, "Android 边到边"). It renders real
// mobile routes on a simulated Android phone whose system navigation bar is
// transparent (edge-to-edge), tints the bar region in the PNGs, and asserts:
//  * no opaque strip under the bar (no colour step at the bar line, uniform
//    colour in the band; brutal tab roots own a panel-coloured band),
//  * scroll lists can scroll their last text clear of the bar (and of the
//    floating tab capsule on elegant tab roots),
//  * bottom-anchored controls reach the screen bottom,
//  * keyboard up: composer sits on the keyboard with no double inset padding,
//    and the home tab bar never follows the keyboard.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/forward_composer_page.dart';
import 'package:raft_flutter/features/incoming_share_picker.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/platform/system_bars.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'app_global_server_selector_test.dart' show RootFixture;
import 'incoming_share_review_test.dart' show PickerClient;
import 'mobile_computer_navigation_test.dart' show loadComputerPageFonts;

/// Pixel 8-class phone: 412x915 dp at 2.625.
const _dpr = 2.625;
const _size = Size(1081, 2402);

enum Nav {
  gesture('gesture', 48, 'gesture bar 48px'),
  buttons('buttons', 126, '3-button bar 126px');

  const Nav(this.id, this.px, this.label);
  final String id, label;
  final double px;
}

Directory outDir() {
  final dir = Directory(
    Platform.environment['RAFT_EDGE_AUDIT_DIR'] ??
        '${Directory.current.path}/../../.local/edge-to-edge-after',
  )..createSync(recursive: true);
  return dir;
}

final metrics = <Map<String, Object?>>[];

/// Lowest wide [Scrollable] viewport: how far above the screen bottom it ends
/// (dp). 0 means the scroll view runs under the system bar; the bar height
/// means a SafeArea strip clips it. Null when the page has no scroll view.
double? scrollGap(WidgetTester t) {
  final screenH = _size.height / _dpr;
  double? best;
  for (final e in find.byType(Scrollable).evaluate()) {
    final box = e.renderObject;
    if (box is! RenderBox || !box.hasSize || !box.attached) continue;
    if (box.size.width < 300 || box.size.height < 150) continue;
    final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
    if (bottom > screenH + 1) continue;
    if (best == null || bottom > screenH - best) best = screenH - bottom;
  }
  return best;
}

String _hex(int argb) =>
    '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Renders the whole root layer and tints the status/navigation bar bands.
/// Also records what colour the app itself leaves under the bar.
Future<Map<String, Object?>> shoot(
  WidgetTester t,
  String name, {
  required Nav nav,
  double keyboardPx = 0,
  String? probe,
}) async {
  late Map<String, Object?> result;
  final renderView = t.binding.renderViews.first;
  final layer = renderView.debugLayer! as OffsetLayer;
  final bounds = Offset.zero & (renderView.size * _dpr);
  final gap = scrollGap(t);
  await t.runAsync(() async {
    final image = await layer.toImage(bounds, pixelRatio: 1);
    final raw = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    int px(int x, int y) {
      final o = (y * image.width + x) * 4;
      return 0xFF000000 |
          raw.getUint8(o) << 16 |
          raw.getUint8(o + 1) << 8 |
          raw.getUint8(o + 2);
    }

    final w = image.width, h = image.height;
    final bandTop = h - nav.px.round();
    final bandY = h - (nav.px / 2).round();
    final band = {
      for (final x in [3, w ~/ 2, w - 4]) px(x, bandY),
    };
    final above = px(3, bandTop - 8);
    // Strip detection on the two edge columns (no content lives there): the
    // colour must not step at the bar line and must be uniform inside it.
    bool noStep = true, uniform = true;
    for (final x in [3, w - 4]) {
      final over = px(x, bandTop - 3), under = px(x, bandTop + 3);
      if (over != under) noStep = false;
      for (var y = bandTop + 3; y < h; y += 7) {
        if (px(x, y) != under) uniform = false;
      }
    }
    result = {
      'name': name,
      'nav': nav.id,
      'noStep': noStep,
      'bandUniform': uniform,
      'bandColour': _hex(px(3, bandY)),
      'colourAboveBar': _hex(px(3, bandTop - 3)),
    };
    metrics.add({
      'name': name,
      'nav': nav.id,
      'bandColour': band.map(_hex).join('/'),
      'bandUniform': band.length == 1,
      'above8px': _hex(above),
      'bandEqualsAbove': band.length == 1 && band.first == above,
      'scrollViewportGapDp': gap?.toStringAsFixed(1),
      'probe': ?probe,
    });

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(image, Offset.zero, Paint());
    final navTop = h - nav.px;
    canvas.drawRect(
      Rect.fromLTWH(0, navTop, w.toDouble(), nav.px),
      Paint()..color = const Color(0x55FF00FF),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, navTop, w.toDouble(), 3),
      Paint()..color = const Color(0xFFFF00FF),
    );
    if (keyboardPx > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, h - keyboardPx, w.toDouble(), keyboardPx),
        Paint()..color = const Color(0x4400AAFF),
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), 100),
      Paint()..color = const Color(0x3300AA00),
    );
    final picture = recorder.endRecording();
    final out = await picture.toImage(w, h);
    picture.dispose();
    final bytes = await out.toByteData(format: ui.ImageByteFormat.png);
    File(
      '${outDir().path}/$name.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
    out.dispose();
  });
  return result;
}

String mq(BuildContext c) {
  final m = MediaQuery.of(c);
  String d(double v) => (v * _dpr).round().toString();
  return 'padding.bottom=${d(m.padding.bottom)}px viewPadding.bottom='
      '${d(m.viewPadding.bottom)}px viewInsets.bottom=${d(m.viewInsets.bottom)}px';
}

void setInsets(WidgetTester t, Nav nav, {double keyboardPx = 0}) {
  t.view.viewPadding = FakeViewPadding(top: 100, bottom: nav.px);
  // Android: the IME replaces the nav bar inset, so padding.bottom drops to 0
  // while viewPadding keeps reporting the bar.
  t.view.padding = FakeViewPadding(
    top: 100,
    bottom: keyboardPx > 0 ? 0 : nav.px,
  );
  t.view.viewInsets = FakeViewPadding(bottom: keyboardPx);
}

Future<RootFixture> mountAt(
  WidgetTester t,
  String theme,
  String path,
  Nav nav, {
  RootFixture? fixture,
}) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  await loadComputerPageFonts(t);
  final f = fixture ?? RootFixture();
  await f.mount(t, theme, 412, uri: Uri.parse(path));
  t.view.devicePixelRatio = _dpr;
  t.view.physicalSize = _size;
  setInsets(t, nav);
  addTearDown(() {
    t.view.resetPadding();
    t.view.resetViewPadding();
    t.view.resetViewInsets();
  });
  await f.flush(t);
  // Some pages keep a spinner alive; settle for a bounded time instead.
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  return f;
}

Map<String, dynamic> _task(int i) => {
  'id': 'task-$i',
  'taskNumber': i,
  'title': i == 14 ? 'Scoped actual task' : 'Audit task number $i',
  'description': 'Accepted task description',
  'channelId': 'ca',
  'channelName': 'general-a',
  'messageId': 'task-parent',
  'threadChannelId': 'task-thread',
  'status': 'todo',
  'createdByType': 'user',
  'createdById': 'alice',
  'createdByName': 'Alice',
};

RootFixture richFixture() {
  final f = RootFixture();
  f.overrides['GET /messages/context/ma'] = (_) => {
    'messages': [_message('ma', 'Accepted a')],
  };
  f.overrides['GET /messages/channel/ca'] = (_) => {
    'messages': [
      for (var i = 1; i <= 6; i++)
        {
          ..._message(
            'm$i',
            i.isEven ? 'Reply number $i' : 'Edge to edge sample $i',
            seq: i,
          ),
          if (i == 6)
            'attachments': [
              {
                'id': 'preview-attachment',
                'filename': 'research.md',
                'mimeType': 'text/markdown',
              },
            ],
        },
    ],
    'hasMore': false,
    'hasNewer': false,
  };
  f.overrides['GET /servers/a/members'] = (_) => [
    {'userId': 'alice', 'name': 'Alice', 'role': 'owner'},
    {'userId': 'bob', 'name': 'Bob', 'role': 'member'},
  ];
  f.overrides['GET /servers/a/machines'] = (_) => {
    'machines': [
      for (var i = 1; i <= 16; i++)
        {
          'id': 'computer-$i',
          'name': 'Audit computer $i',
          'status': 'online',
          'isComputer': true,
        },
    ],
  };
  f.overrides['GET /tasks/server'] = (_) => {
    'tasks': [for (var i = 1; i <= 14; i++) _task(i)],
    'next_cursor': null,
  };
  f.overrides['GET /tasks/task-14/history'] = (_) => {'events': <dynamic>[]};
  f.overrides['GET /tasks/channel/ca/number/14'] = (_) => {'task': _task(14)};
  f.overrides['GET /messages/context/task-parent'] = (_) => {
    'messages': [_message('task-parent', 'Parent')],
  };
  f.overrides['GET /messages/channel/task-thread'] = (_) => {
    'messages': <dynamic>[],
  };
  f.overrides['POST /channels/task-thread/read'] = (_) => {};
  f.overrides['GET /messages/attachment-preview/enabled'] = (_) => {
    'enabled': true,
  };
  f.overrides['GET /attachments/preview-attachment/preview'] = (_) => {
    'status': 'ok',
    'data': {'kind': 'text', 'text': 'Fixture document'},
  };
  return f;
}

Map<String, dynamic> _message(String id, String text, {int seq = 1}) => {
  'id': id,
  'channelId': 'ca',
  'seq': '$seq',
  'senderId': 'alice',
  'senderName': 'Alice',
  'content': text,
  'createdAt': '2026-10-10T00:0$seq:00Z',
};

class Scenario {
  const Scenario(
    this.name,
    this.path, {
    this.act,
    this.nav = Nav.gesture,
    this.root = false,
    this.bottomControl = false,
    this.dark = false,
    this.tabBarSurface = false,
  });
  final String name, path;
  final Nav nav;
  final Future<void> Function(WidgetTester t, RootFixture f)? act;

  /// One of the four tab roots (the tab bar owns the bottom inset).
  final bool root;

  /// A bottom-anchored control (composer, footer, sheet) must reach the
  /// screen bottom.
  final bool bottomControl;

  /// Also captured in the dark elegant theme.
  final bool dark;

  /// The Bottom bar settings preview keeps the same Brutal bottom border as
  /// the real tab bar. That intentional line is not an opaque system-bar strip.
  final bool tabBarSurface;
}

Future<void> settle(WidgetTester t, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// Opens the channel the way a user does: a cold URL launch does not load the
/// message window in this fixture.
Future<void> openChannel(WidgetTester t, RootFixture f) async {
  await t.tap(find.byKey(const ValueKey('sidebar-channel-ca')));
  await f.flush(t);
  await settle(t);
}

Future<void> scrollToEnd(WidgetTester t, RootFixture f) async {
  final list = find.byType(Scrollable).evaluate().where((e) {
    final b = e.renderObject;
    return b is RenderBox && b.size.width >= 300 && b.size.height >= 300;
  }).first;
  await t.fling(
    find.byElementPredicate((e) => e == list),
    const Offset(0, -3000),
    8000,
  );
  await settle(t, 20);
}

Future<void> openTask(WidgetTester t, RootFixture f) async {
  await t.tap(find.text('Scoped actual task'));
  await f.flush(t);
  await settle(t);
}

Future<void> openAttachment(WidgetTester t, RootFixture f) async {
  await openChannel(t, f);
  await t.tap(find.textContaining('research.md').first);
  await f.flush(t);
  await settle(t);
}

Future<void> openForward(WidgetTester t, RootFixture f) async {
  await openChannel(t, f);
  final w = f.workspace(t);
  final ctx = t.element(find.byType(WorkspaceView));
  final messages = w.messageDomain.messages.take(1).toList();
  unawaited(showForwardComposerPage(ctx, w, messages));
  await f.flush(t);
  await settle(t);
}

final scenarios = <Scenario>[
  const Scenario('01-home-root', '/s/alpha', root: true),
  const Scenario('02-tasks-root', '/s/alpha/tasks', root: true),
  const Scenario(
    '05-tasks-root-scrolled-end',
    '/s/alpha/tasks',
    act: scrollToEnd,
    root: true,
  ),
  const Scenario(
    '06-settings-root-scrolled-end',
    '/s/alpha/settings',
    act: scrollToEnd,
    root: true,
  ),
  const Scenario(
    '07-home-root-scrolled-end',
    '/s/alpha',
    act: scrollToEnd,
    root: true,
  ),
  const Scenario('03-members-root', '/s/alpha/members', root: true),
  const Scenario('04-settings-root', '/s/alpha/settings', root: true),
  const Scenario(
    '10-channel-chat',
    '/s/alpha',
    act: openChannel,
    bottomControl: true,
    dark: true,
  ),
  const Scenario(
    '11-thread',
    '/s/alpha/channel/ca?thread=ca:ma',
    bottomControl: true,
  ),
  const Scenario('12-search', '/s/alpha/search', dark: true),
  const Scenario('13-activity', '/s/alpha/activity'),
  const Scenario('14-saved', '/s/alpha/saved'),
  const Scenario('15-settings-account', '/s/alpha/settings/account'),
  const Scenario(
    '16-settings-workspace',
    '/s/alpha/settings/server',
    dark: true,
  ),
  const Scenario('17-computers', '/s/alpha/computers'),
  const Scenario('17-computers', '/s/alpha/computers', nav: Nav.buttons),
  const Scenario(
    '19-bottom-bar-settings',
    '/s/alpha/settings/bottom-bar',
    bottomControl: true,
    dark: true,
    tabBarSurface: true,
  ),
  const Scenario(
    '19-bottom-bar-settings',
    '/s/alpha/settings/bottom-bar',
    nav: Nav.buttons,
    bottomControl: true,
    tabBarSurface: true,
  ),
  const Scenario('18-member-detail', '/s/alpha/human/bob'),
  const Scenario(
    '20-channel-settings-page',
    '/s/alpha/channel/ca?channelPage=settings:ca',
  ),
  const Scenario(
    '21-channel-members-page',
    '/s/alpha/channel/ca?channelPage=members:ca',
  ),
  const Scenario(
    '22-task-detail',
    '/s/alpha/tasks',
    act: openTask,
    bottomControl: true,
    dark: true,
  ),
  const Scenario(
    '23-attachment-preview',
    '/s/alpha',
    act: openAttachment,
    bottomControl: true,
  ),
  const Scenario('24-forward-composer', '/s/alpha', act: openForward),
  // Same pages with a 3-button bar (126px).
  const Scenario(
    '10-channel-chat',
    '/s/alpha',
    act: openChannel,
    nav: Nav.buttons,
    bottomControl: true,
  ),
  const Scenario('01-home-root', '/s/alpha', nav: Nav.buttons, root: true),
  const Scenario('12-search', '/s/alpha/search', nav: Nav.buttons),
  const Scenario(
    '16-settings-workspace',
    '/s/alpha/settings/server',
    nav: Nav.buttons,
  ),
];

/// What a page body sees under a bare Scaffold (no SafeArea) when the nav bar
/// is up, and when the IME replaces it: the numbers the shared helper relies on.
void mqProbeTests() {
  for (final resize in [true, false]) {
    testWidgets('40-mq-probe Scaffold resizeToAvoidBottomInset=$resize', (
      t,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      t.view.devicePixelRatio = _dpr;
      t.view.physicalSize = _size;
      addTearDown(() {
        t.view.resetPadding();
        t.view.resetViewPadding();
        t.view.resetViewInsets();
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
      });
      late BuildContext inner;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            resizeToAvoidBottomInset: resize,
            body: Builder(
              builder: (c) {
                inner = c;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
      for (final (label, kb) in [
        ('nav bar only', 0.0),
        ('keyboard 300dp', 300 * _dpr),
      ]) {
        setInsets(t, Nav.gesture, keyboardPx: kb);
        await t.pump();
        metrics.add({
          'name': 'mq-probe resize=$resize $label',
          'probe': mq(inner),
        });
      }
      debugDefaultTargetPlatformOverride = null;
    });
  }
}

/// Rect of the first element of [type] (global dp).
Rect rectOf(WidgetTester t, Finder f) => t.getRect(f.first);

/// Scrolls the lowest wide scroll view that runs under the bar to its end and
/// returns the lowest visible text bottom (dp), or null if there is none.
Future<double?> lowestTextAfterScrollToEnd(WidgetTester t) async {
  final screenH = _size.height / _dpr;
  Element? target;
  double targetBottom = -1;
  for (final e in find.byType(Scrollable).evaluate()) {
    final box = e.renderObject;
    if (box is! RenderBox || !box.hasSize || !box.attached) continue;
    if (box.size.width < 300 || box.size.height < 150) continue;
    final axis = (e.widget as Scrollable).axisDirection;
    if (axis == AxisDirection.left || axis == AxisDirection.right) continue;
    final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
    if (bottom < screenH - 1) continue; // ends above the bar: not under it
    if (bottom > targetBottom) {
      target = e;
      targetBottom = bottom;
    }
  }
  if (target == null) return null;
  final state = t.state<ScrollableState>(
    find.byElementPredicate((e) => e == target),
  );
  if (state.position.axis != Axis.vertical) return null;
  state.position.jumpTo(state.position.maxScrollExtent);
  await settle(t, 4);
  double? lowest;
  for (final e
      in find
          .descendant(
            of: find.byElementPredicate((e) => e == target),
            matching: find.byType(RichText),
          )
          .evaluate()) {
    final box = e.renderObject;
    if (box is! RenderBox || !box.hasSize || !box.attached) continue;
    final r = box.localToGlobal(Offset.zero) & box.size;
    if (r.top >= screenH || r.bottom <= 0 || r.isEmpty) continue;
    if (lowest == null || r.bottom > lowest) lowest = r.bottom;
  }
  return lowest;
}

/// A bottom-anchored control whose own background reaches the screen bottom.
bool bottomControlReachesEdge(WidgetTester t) {
  final screenH = _size.height / _dpr;
  for (final e in find.byType(RaftNavigationBarStyle).evaluate()) {
    final box = e.renderObject;
    if (box is! RenderBox || !box.hasSize || !box.attached) continue;
    final r = box.localToGlobal(Offset.zero) & box.size;
    if ((r.bottom - screenH).abs() < .5 && r.width > 300 && r.height > 20) {
      return true;
    }
  }
  return false;
}

/// Asserts what every captured page must satisfy under the system bar.
Future<void> assertEdgeToEdge(
  WidgetTester t,
  Scenario s,
  String theme,
  Map<String, Object?> m,
) async {
  final label = '${s.name} $theme ${s.nav.id}';
  final brutalRoot = (s.root || s.tabBarSurface) && theme == 'brutal';
  if (brutalRoot) {
    // The in-flow brutal tab bar owns the bar band and paints it panel-coloured.
    expect(m['bandUniform'], isTrue, reason: '$label: band not uniform');
  } else {
    expect(
      m['noStep'],
      isTrue,
      reason:
          '$label: opaque strip: colour above the bar ${m['colourAboveBar']} '
          'differs from the band ${m['bandColour']}',
    );
    expect(m['bandUniform'], isTrue, reason: '$label: band not uniform');
  }
  if (s.bottomControl) {
    expect(
      bottomControlReachesEdge(t),
      isTrue,
      reason: '$label: bottom control does not reach the screen bottom',
    );
  }
  if (s.tabBarSurface) {
    final nav = find.descendant(
      of: find.byKey(const Key('mobile-tabbar-preview')),
      matching: find.byType(RaftMobileNav),
    );
    expect(
      t.getRect(nav).bottom,
      closeTo(_size.height / _dpr - s.nav.px / _dpr, .5),
    );
  }
  // Last item scrolls clear of the bar (and of the floating capsule).
  final gap = scrollGap(t);
  if (gap != null && gap < 1) {
    final inset = s.nav.px / _dpr;
    final floating = s.root && theme != 'brutal';
    // Capsule: 8 gap + 52 capsule + 8 + inset = Web's 68 + inset.
    final barTop = _size.height / _dpr - inset - (floating ? 60 : 0);
    final lowest = await lowestTextAfterScrollToEnd(t);
    metrics.add({
      'name': '$label scroll-end',
      'lowestTextDp': lowest?.toStringAsFixed(1),
      'barTopDp': barTop.toStringAsFixed(1),
    });
    if (lowest != null) {
      expect(
        lowest,
        lessThanOrEqualTo(barTop + .5),
        reason:
            '$label: last text ends at $lowest dp, under the bar '
            '(bar top $barTop dp)',
      );
    }
  }
}

/// Keyboard up / down on a bottom composer (chat or thread).
Future<void> composerKeyboardScenario(
  WidgetTester t,
  String theme,
  String name,
  String path, {
  Future<void> Function(WidgetTester t, RootFixture f)? act,
}) async {
  final f = await mountAt(t, theme, path, Nav.gesture, fixture: richFixture());
  await act?.call(t, f);
  final screenH = _size.height / _dpr;
  final inset = Nav.gesture.px / _dpr;
  final host = find.byKey(const ValueKey('composer-host-slot'));
  final shell = find.byKey(const ValueKey('composer-shell-slot'));
  double padBelowShell() => rectOf(t, host).bottom - rectOf(t, shell).bottom;
  // Resting: the host background reaches the bottom and pads by the inset.
  expect(rectOf(t, host).bottom, closeTo(screenH, .5), reason: '$name rest');
  final restPad = padBelowShell();
  // The composer's visual editor can cover its read-only EditableText (e.g.
  // an unresolved thread). Target the actual composition surface for this
  // synthetic-IME layout probe; interactive IME acceptance is separate.
  await t.tap(find.byKey(const ValueKey('composer-editor-slot')).last);
  await settle(t, 3);
  const kb = 300 * _dpr;
  setInsets(t, Nav.gesture, keyboardPx: kb);
  await settle(t, 5);
  final kbTop = screenH - kb / _dpr;
  // Keyboard up: the composer sits exactly on the keyboard, and the inset is
  // not counted twice (the nav bar is under the keyboard).
  expect(rectOf(t, host).bottom, closeTo(kbTop, .5), reason: '$name on IME');
  expect(
    padBelowShell(),
    closeTo(restPad - inset, .5),
    reason: '$name: keyboard up must drop the nav inset (no double padding)',
  );
  await shoot(
    t,
    '$name-up-$theme',
    nav: Nav.gesture,
    keyboardPx: kb,
    probe: mq(t.element(find.byType(EditableText).last)),
  );
  setInsets(t, Nav.gesture);
  FocusManager.instance.primaryFocus?.unfocus();
  await settle(t, 8);
  expect(rectOf(t, host).bottom, closeTo(screenH, .5), reason: '$name down');
  expect(padBelowShell(), closeTo(restPad, .5), reason: '$name restored');
  await shoot(
    t,
    '$name-down-$theme',
    nav: Nav.gesture,
    probe: mq(t.element(find.byType(EditableText).last)),
  );
  debugDefaultTargetPlatformOverride = null;
}

void main() {
  mqProbeTests();
  tearDownAll(() {
    File(
      '${outDir().path}/metrics.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(metrics));
  });
  for (final theme in raftThemeMatrix([
    'brutal',
    'elegant-light',
    'elegant-dark',
  ], full: true)) {
    final dark = theme == 'elegant-dark';
    for (final s in scenarios) {
      if (dark && (!s.dark || s.nav != Nav.gesture)) continue;
      testWidgets('${s.name} $theme ${s.nav.id}', (t) async {
        final f = await mountAt(
          t,
          theme,
          s.path,
          s.nav,
          fixture: richFixture(),
        );
        await s.act?.call(t, f);
        if (Platform.environment['RAFT_EDGE_DEBUG'] != null) {
          await f.flush(t);
          await settle(t, 20);
          debugPrint(
            f.adapter.calls
                .map((c) => '${c.method} ${c.path} ${c.queryParameters}')
                .join('\n'),
          );
        }
        final m = await shoot(t, '${s.name}-$theme-${s.nav.id}', nav: s.nav);
        await assertEdgeToEdge(t, s, theme, m);
        debugDefaultTargetPlatformOverride = null;
      });
    }
    testWidgets('30-chat-keyboard $theme', (t) async {
      await composerKeyboardScenario(
        t,
        theme,
        '30-chat-keyboard',
        '/s/alpha',
        act: openChannel,
      );
    });
    testWidgets('32-thread-keyboard $theme', (t) async {
      await composerKeyboardScenario(
        t,
        theme,
        '32-thread-keyboard',
        '/s/alpha/channel/ca?thread=ca:ma',
      );
    });
    if (dark) continue;
    // Home tab bar: the keyboard must not lift it (owner report 2).
    testWidgets('40-home-keyboard $theme', (t) async {
      await mountAt(t, theme, '/s/alpha', Nav.gesture, fixture: richFixture());
      const key = Key('workspace-mobile-navigation');
      double lift() => _size.height / _dpr - rectOf(t, find.byKey(key)).bottom;
      final rest = lift();
      await shoot(t, '40-home-keyboard-rest-$theme', nav: Nav.gesture);
      const kb = 300 * _dpr;
      setInsets(t, Nav.gesture, keyboardPx: kb);
      await settle(t, 5);
      expect(lift(), closeTo(rest, .5), reason: 'tab bar must not follow IME');
      await shoot(
        t,
        '41-home-keyboard-up-$theme',
        nav: Nav.gesture,
        keyboardPx: kb,
      );
      setInsets(t, Nav.gesture);
      await settle(t, 5);
      expect(lift(), closeTo(rest, .5), reason: 'tab bar restored');
      await shoot(t, '42-home-keyboard-down-$theme', nav: Nav.gesture);
      debugDefaultTargetPlatformOverride = null;
    });
    testWidgets('25-share-picker $theme', (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await loadComputerPageFonts(t);
      t.view.devicePixelRatio = _dpr;
      t.view.physicalSize = _size;
      setInsets(t, Nav.gesture);
      addTearDown(() {
        t.view.resetPadding();
        t.view.resetViewPadding();
        t.view.resetViewInsets();
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
      });
      await t.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: raftTheme(
            theme == 'brutal' ? RaftFamily.brutal : RaftFamily.elegant,
          ),
          home: RaftSystemBars(
            child: IncomingSharePicker(
              client: PickerClient(),
              servers: [
                RaftRecord({'id': 'a', 'name': 'Server A'}),
              ],
              valid: () => true,
              onContinue: (server, target) async {},
            ),
          ),
        ),
      );
      await settle(t, 6);
      final m = await shoot(
        t,
        '25-share-picker-$theme-gesture',
        nav: Nav.gesture,
      );
      // The destinations page is the Web forward page: no bottom bar.
      await assertEdgeToEdge(
        t,
        const Scenario('25-share-picker', ''),
        theme,
        m,
      );
      // Choosing a row opens "Add shared content"; its Continue bar reaches
      // the screen bottom.
      await t.tap(find.byKey(const ValueKey('incoming-target-a-c')));
      await settle(t, 6);
      final next = await shoot(
        t,
        '25-share-picker-continue-$theme-gesture',
        nav: Nav.gesture,
      );
      await assertEdgeToEdge(
        t,
        const Scenario('25-share-picker-continue', '', bottomControl: true),
        theme,
        next,
      );
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
