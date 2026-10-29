// Status bar standard audit. One rule for every layout: for each vertical
// column under the status bar, the band over that column is the colour of the
// column's topmost visible surface (its page header, else the column
// background) and the column dividers continue up through the band. See
// docs/status-bar.md.
//
// Every route of the statusbar audit page list is rendered at phone (390x844),
// foldable (816x900) and desktop (1280x800) sizes in the three themes. The
// band row (middle of the 40dp inset) must equal the row just below the inset
// across the whole window width: that covers every column's centre and every
// divider between columns. `RAFT_STATUSBAR_STANDARD_DIR` writes the top of each
// render as `<dir>/<size>/<theme>/<page>.png` for contact sheets.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:raft_flutter/data/navigation_registry.dart';
import 'package:raft_ui/raft_ui.dart'
    show RaftMountedSidebarFrame, RaftWorkspaceRail;
import 'package:raft_ui/test_themes.dart';

import 'app_global_server_selector_test.dart' show RootFixture;
import 'edge_to_edge_audit_test.dart' show richFixture, settle;
import 'mobile_computer_navigation_test.dart' show loadComputerPageFonts;
import 'statusbar_audit_test.dart' show Page, pages, withDirectory;
import 'flutter_test_config.dart' show leakDebt;
import 'support/test_parts.dart';

const _dpr = 2.625;
const _topDp = 40.0;
const _themes = ['light', 'dark'];
const _sizes = {
  'phone-390': Size(390, 844),
  'fold-816': Size(816, 900),
  'desktop-1280': Size(1280, 800),
};

String _hex(int c) => '#${(c & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

Future<RootFixture> _mount(
  WidgetTester t,
  String theme,
  Size dp,
  Page p,
) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  await loadComputerPageFonts(t);
  final f = richFixture();
  p.prepare?.call(f);
  await f.mount(t, theme, dp.width, uri: Uri.parse(p.path));
  t.view.devicePixelRatio = _dpr;
  t.view.physicalSize = dp * _dpr;
  const top = _topDp * _dpr;
  t.view.viewPadding = const FakeViewPadding(top: top, bottom: 126);
  t.view.padding = const FakeViewPadding(top: top, bottom: 126);
  addTearDown(() {
    t.view.resetPadding();
    t.view.resetViewPadding();
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
  });
  await f.flush(t);
  await settle(t);
  return f;
}

/// Whether the gate runs [theme] at [size]: every size on the default theme,
/// the others everywhere but the desktop width (measured: the extra desktop
/// cells cover no line the phone and foldable cells of the same theme miss).
bool _gateRuns(String theme, String size) =>
    raftFullMatrix || theme == _themes.first || size != 'desktop-1280';

/// The vertical columns under the status bar and where to sample them: the
/// column centre, plus its divider (the right edge of the rail / sidebar, the
/// left edge of the thread / profile panels). Phones are one column.
List<({String name, double x})> _samples(WidgetTester t, Size window) {
  double? right(Finder f) =>
      f.evaluate().isEmpty ? null : t.getRect(f.first).right;
  double? left(Finder f) =>
      f.evaluate().isEmpty ? null : t.getRect(f.first).left;
  final rail = right(find.byType(RaftWorkspaceRail));
  // Navigation columns between the rail and the content: the shell sidebar,
  // the settings navigation and the Members / Computers directory column.
  final navigation = <double>{
    for (final f in [
      find.byKey(const Key('workspace-sidebar-panel')),
      find.byKey(const Key('settings-navigation')),
      find.byType(RaftMountedSidebarFrame),
    ])
      for (final e in f.evaluate())
        (t.getRect(find.byElementPredicate((x) => x == e)).right * 10)
                .roundToDouble() /
            10,
  }.toList()..sort();
  final thread = left(find.byKey(const Key('workspace-thread-panel')));
  final profile = left(find.byKey(const Key('workspace-profile-panel')));
  final out = <({String name, double x})>[];
  var from = 0.0;
  if (rail != null) {
    out.add((name: 'rail', x: rail / 2));
    out.add((name: 'rail divider', x: rail - 2 / _dpr));
    from = rail;
  }
  for (final right in navigation) {
    out.add((name: 'column @${right.round()}', x: (from + right) / 2));
    out.add((name: 'divider @${right.round()}', x: right - 2 / _dpr));
    from = right;
  }
  final panels = [?thread, ?profile]..sort();
  final to = panels.isEmpty ? window.width : panels.first;
  // A phone's navigation column is the whole window: no separate content.
  if (to - from >= 1) out.add((name: 'content', x: (from + to) / 2));
  for (var i = 0; i < panels.length; i++) {
    final next = i + 1 < panels.length ? panels[i + 1] : window.width;
    out.add((name: 'panel ${i + 1}', x: (panels[i] + next) / 2));
    out.add((name: 'panel ${i + 1} divider', x: panels[i] + 1 / _dpr));
  }
  return out;
}

Future<void> _check(
  WidgetTester t,
  String sizeName,
  String theme,
  Page p, {
  String? shots,
}) async {
  final renderView = t.binding.renderViews.first;
  final layer = renderView.debugLayer! as OffsetLayer;
  final samples = _samples(t, renderView.size);
  final mismatches = <String>[];
  await t.runAsync(() async {
    final image = await layer.toImage(
      Offset.zero & (renderView.size * _dpr),
      pixelRatio: 1,
    );
    final raw = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    int px(int x, int y) {
      final o = (y * image.width + x) * 4;
      return 0xFF000000 |
          raw.getUint8(o) << 16 |
          raw.getUint8(o + 1) << 8 |
          raw.getUint8(o + 2);
    }

    final strip = (_topDp / 2 * _dpr).round();
    final below = (_topDp * _dpr).round() + 3;
    for (final s in samples) {
      final x = (s.x * _dpr).round().clamp(0, image.width - 1);
      final a = px(x, strip), b = px(x, below);
      if (a != b) {
        mismatches.add(
          '${s.name} (x=${s.x.toStringAsFixed(1)}dp) band ${_hex(a)} != below ${_hex(b)}',
        );
      }
    }
    if (shots != null) {
      final h = (120 * _dpr).round();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), h.toDouble()),
        Rect.fromLTWH(0, 0, image.width.toDouble(), h.toDouble()),
        Paint(),
      );
      canvas.drawRect(
        Rect.fromLTWH(0, _topDp * _dpr - 1, image.width.toDouble(), 2),
        Paint()..color = const Color(0xFFFF00FF),
      );
      final picture = recorder.endRecording();
      final ui.Image out;
      try {
        out = await picture.toImage(image.width, h);
      } finally {
        picture.dispose();
      }
      final bytes = await out.toByteData(format: ui.ImageByteFormat.png);
      File('$shots/$sizeName/$theme/${p.name}.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes!.buffer.asUint8List());
      out.dispose();
    }
    image.dispose();
  });
  expect(
    mismatches,
    isEmpty,
    reason:
        '${p.name} $sizeName $theme: the status bar band must continue each '
        'column\'s top surface (and dividers)',
  );
  final style = layer.find<SystemUiOverlayStyle>(
    Offset(renderView.size.width / 2, _topDp / 2),
  );
  expect(style, isNotNull, reason: '${p.name} $sizeName $theme: no style');
}

/// Every navigation target of the registry that the audit page list does not
/// already render: sections and settings pages, with the layouts they exist
/// on. The audit page list adds the routes that are not sections (channel,
/// thread, DM, profiles, detail pages, modals).
List<({Page page, bool phone, bool wide})> _registryPages() {
  final known = {for (final p in pages) p.path};
  final extra = <String, ({bool phone, bool wide})>{};
  void add(String path, {bool phone = true, bool wide = true}) {
    if (known.contains(path)) return;
    extra[path] = (phone: phone, wide: wide);
  }

  for (final section in NavigationRegistry.sections) {
    final tab = section.settingsTab;
    add(switch (section.id) {
      'home' || 'chat' => '/s/alpha',
      'agents' || 'members' => '/s/alpha/members',
      'settings' => '/s/alpha/settings',
      _ when tab != null => '/s/alpha/settings/$tab',
      _ => '/s/alpha/${section.id}',
    });
  }
  for (final tab in NavigationRegistry.settingsTabs.where((t) => t.page)) {
    add('/s/alpha/settings/${tab.id}', phone: tab.phone, wide: tab.wide);
  }
  return [
    for (final e in extra.entries)
      (
        page: Page(
          'reg-${e.key.substring('/s/alpha/'.length).replaceAll('/', '-')}',
          e.key,
        ),
        phone: e.value.phone,
        wide: e.value.wide,
      ),
  ];
}

/// Wide-only routes where a column is covered by a later one: a profile panel
/// folds over the whole conversation column below the side-by-side breakpoint
/// (the covered header stays mounted and flush with the top), over a thread,
/// and over the activity / search detail. The covering surface decides the band.
const _coverSizes = {
  'fold-816': Size(816, 900),
  'fold-841': Size(841, 900),
  'desktop-1280': Size(1280, 800),
};

const _wideCoverPages = <Page>[
  Page('60-profile-alone', '/s/alpha/channel/ca?profile=human:bob'),
  Page('61-profile-home', '/s/alpha?profile=human:bob'),
  Page(
    '62-profile-agent',
    '/s/alpha/channel/ca?profile=agent:agent-1',
    prepare: withDirectory,
  ),
  Page(
    '63-profile-over-thread',
    '/s/alpha/channel/ca?thread=ca:ma&profile=human:bob',
  ),
  Page('64-activity-open', '/s/alpha/activity?open=channel:ca'),
  Page('65-search-open', '/s/alpha/search?open=channel:ca'),
  Page(
    '66-activity-open-profile',
    '/s/alpha/activity?open=channel:ca&profile=human:bob',
  ),
  Page(
    '67-search-open-profile',
    '/s/alpha/search?open=channel:ca&profile=human:bob',
  ),
];

/// Four files share this suite (`statusbar_standard_part2_test.dart` ...), each
/// registering a fourth of the cases.
void main() => registerStatusbarStandardTests(TestPart(0, 4));

void registerStatusbarStandardTests(TestPart part) {
  // Leak debt (other): see docs/development.md, Leak tracking.
  leakDebt(const ['ValueNotifier<bool>']);
  final shots = Platform.environment['RAFT_STATUSBAR_STANDARD_DIR'];
  final registry = _registryPages();
  // matrix: nightly-full -- the gate drops the other themes at 1280 wide
  // (default theme at every size, the others on the phone and the foldable;
  // those cells add no line of coverage); RAFT_TEST_TIER=full runs the product.
  for (final size in _sizes.entries) {
    final wide = size.value.width >= 768;
    final routes = [
      for (final p in pages)
        if (!wide || !p.phoneOnly) p,
      for (final r in registry)
        if (wide ? r.wide : r.phone) r.page,
    ];
    for (final theme in raftThemeMatrix(_themes, full: true)) {
      if (!_gateRuns(theme, size.key)) continue;
      for (final p in routes) {
        if (!part.claim()) continue;
        testWidgets('statusbar standard ${p.name} ${size.key} $theme', (
          t,
        ) async {
          try {
            final f = await _mount(t, theme, size.value, p);
            await p.act?.call(t, f);
            await _check(t, size.key, theme, p, shots: shots);
          } finally {
            debugDefaultTargetPlatformOverride = null;
          }
        });
      }
    }
  }
  for (final size in _coverSizes.entries) {
    for (final theme in raftThemeMatrix(_themes, full: true)) {
      if (!_gateRuns(theme, size.key)) continue;
      for (final p in _wideCoverPages) {
        if (!part.claim()) continue;
        testWidgets('statusbar standard ${p.name} ${size.key} $theme', (
          t,
        ) async {
          try {
            final f = await _mount(t, theme, size.value, p);
            await p.act?.call(t, f);
            await _check(t, size.key, theme, p, shots: shots);
          } finally {
            debugDefaultTargetPlatformOverride = null;
          }
        });
      }
    }
  }
}
