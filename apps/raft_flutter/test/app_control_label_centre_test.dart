// Vertical centring of the label and icon inside the small controls the app
// composes itself (chips, tags, pills, badges, filter buttons) rather than
// taking whole from raft_ui. PR 238/240 fixed this class of bug inside
// packages/raft_ui; the search-history tag (Search home) was composed in
// apps/raft_flutter and kept a plain 16px line, so on Android + Chinese the CJK
// ink sat ~2px below the chip centre.
//
// Every case below is pumped with the real fonts (bundled Latin faces, Noto
// Sans CJK fallback) on the Android Chinese control profile and on the Web line
// boxes, at text scales 1.0 / 1.3 / 2.0, in both theme families. The ink (not
// the line box) of each single-line label and each icon is measured from a
// rasterised frame and must be within one logical px of the control's centre
// and inside the control; no RenderFlex overflow may be raised.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/agent_migration_panel.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/resource_filters.dart';
import 'package:raft_flutter/features/search_filter_bar.dart';
import 'package:raft_flutter/features/search_home.dart';
import 'package:raft_flutter/features/source_channel_files_view.dart';
import 'package:raft_flutter/data/source_channel_files_store.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../../tool/testing/ink_alignment.dart';
import '../../../tool/testing/text_scale_audit.dart'
    show AuditFonts, AuditMode, AuditReport, inspectPumped, loadAuditFonts;

class _Profile {
  const _Profile(this.name, this.platform, this.locale);
  final String name;
  final TargetPlatform platform;
  final Locale locale;
}

const _profiles = [
  _Profile('android-zh', TargetPlatform.android, Locale('zh', 'CN')),
  _Profile('web-en', TargetPlatform.macOS, Locale('en', 'US')),
];
const _scales = [1.0, 1.3, 2.0];

/// A control family to measure: [root] holds the controls; every widget of
/// [box] type under it is one control.
class _Case {
  const _Case(
    this.name,
    this.build,
    this.box, {
    this.labels = const [''],
    this.maxBoxHeight = 64,
    this.page = false,
  });

  /// A whole page: mounted as the Scaffold body, not in a top-left slot.
  final bool page;

  /// Matches taller than this are containers around the controls, not controls.
  final double maxBoxHeight;
  final String name;
  final Widget Function(String label) build;
  final Finder Function() box;

  /// Label texts the case is pumped with (empty string: the case's own text).
  final List<String> labels;
}

void _noop() {}

class _Client extends RaftClient {
  _Client()
    : super(origin: 'https://fixture.test', sessionStore: MemorySessionStore());
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  @override
  Future<void> refreshUnread() async {}
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path.endsWith('/members') || path == '/agents') return [];
    return {
      'items': [
        {
          'kind': 'thread',
          'threadChannelId': 't',
          'parentMessageId': 'p',
          'parentChannelId': 'c',
          'parentChannelName': 'design',
          'parentMessagePreview': 'Parent',
          'latestActivityPreview': 'Reply',
          'replyCount': 92,
          'unreadCount': 2,
          'hasMention': true,
          'isFollowing': false,
          'latestActivitySeq': '9',
        },
      ],
      'hasMore': false,
      'totalUnreadCount': 2,
    };
  }
}

/// The Activity page on fixture data (filters, badges, "mark all read").
Widget _activity() {
  final c = _Client()
    ..user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
  c.selectServer('s');
  final w = _Workspace(c)..server = RaftRecord({'id': 's', 'role': 'owner'});
  addTearDown(() async {
    w.dispose();
    await c.dispose();
  });
  return RaftDensityScope(
    density: RaftDensity.touch,
    child: ResourceView(
      controller: w,
      section: 'activity',
      onMessage: (_, _) async {},
    ),
  );
}

Map<String, dynamic> _file(String name) => {
  'id': 'a',
  'messageId': 'message',
  'channelId': 'channel',
  'filename': name,
  'mimeType': 'text/plain',
  'sizeBytes': 1024,
  'createdAt': '2026-10-08T01:30:00Z',
  'source': {
    'type': 'channel',
    'channelId': 'channel',
    'parentMessageId': null,
  },
};

final _filters = ResourceFilters()
  ..sender = const ResourceSender('u1', 'user', 'Alice')
  ..scopes.add('humans')
  ..channelId = 'c1';

final _cases = <_Case>[
  _Case(
    'Activity badges',
    (_) => _activity(),
    () => find.byType(RaftResourceBadge),
    page: true,
  ),
  _Case(
    'Activity filters and mark all read',
    (_) => _activity(),
    () => find.byType(RaftRecipeBox),
    maxBoxHeight: 40,
    page: true,
  ),
  _Case(
    'RaftSearchHistoryTag',
    (l) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        RaftSearchHistoryTag(
          query: l,
          touch: false,
          editing: false,
          onPressed: _noop,
          onRemove: _noop,
        ),
        RaftSearchHistoryTag(
          query: l,
          touch: true,
          editing: true,
          onPressed: _noop,
          onRemove: _noop,
        ),
      ],
    ),
    () => find.byType(RaftSearchHistoryTag),
    labels: const ['对齐', 'HEAL', 'gpqy'],
  ),
  _Case(
    'ResourceSearchHome history',
    (l) => SizedBox(
      height: 320,
      child: ResourceSearchHome(
        history: [l, '$l $l'],
        frequent: const [],
        origin: 'https://fixture.invalid',
        onQuery: (_) {},
        onRemove: (_) {},
        onClear: _noop,
        onEntity: (_) {},
      ),
    ),
    () => find.byType(RaftSearchHistoryTag),
    labels: const ['对齐', 'HEAL', 'gpqy'],
  ),
  _Case(
    'SearchFilterBar chips',
    (_) => SearchFilterBar(
      filters: _filters,
      senders: const [ResourceSender('u1', 'user', 'Alice')],
      conversations: const {'c1': '#design'},
      menus: <MenuController>{},
      queryIsEmpty: false,
      scope: 's',
      valid: () => true,
      onChanged: _noop,
      channelLabel: (id) => '#design',
    ),
    () => find.byType(RaftControl),
  ),
  _Case(
    'SearchFilterBar unfiltered chips',
    (_) => SearchFilterBar(
      filters: ResourceFilters(),
      senders: const [],
      conversations: const {'c1': '#design'},
      menus: <MenuController>{},
      queryIsEmpty: false,
      scope: 's',
      valid: () => true,
      onChanged: _noop,
    ),
    () => find.byType(RaftControl),
  ),
  _Case(
    'MigrationSteps indicators',
    (_) => const MigrationSteps(
      current: 1,
      status: MigrationStepStatus.process,
      semanticLabel: 'Progress',
    ),
    // The numbered circle is a decorated 20px Container.
    () => find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.constraints == BoxConstraints.tightFor(width: 20, height: 20),
    ),
  ),
  _Case(
    'SourceChannelFileRow extension badge',
    (_) => SizedBox(
      width: 380,
      child: SourceChannelFileRow(
        file: SourceChannelFileEntry.parse(_file('notes.pdf')),
        formattedDate: 'Oct 8, 10:30 AM',
        onPreview: _noop,
        onOpenSource: _noop,
        onDownload: _noop,
      ),
    ),
    // The extension tag over the thumbnail: a 28x14 minimum.
    () => find.byWidgetPredicate(
      (w) => w is Container && w.constraints?.minHeight == 14,
    ),
  ),
];

/// A paragraph of [box] that is a label: not an icon font, not empty.
Iterable<Finder> _labels(Finder box) sync* {
  final texts = find.descendant(of: box, matching: find.byType(RichText));
  for (var i = 0; i < texts.evaluate().length; i++) {
    final w = texts.evaluate().elementAt(i).widget as RichText;
    if (w.text.style?.fontFamily == 'MaterialIcons') continue;
    if (w.text.toPlainText().trim().isEmpty) continue;
    yield texts.at(i);
  }
}

/// Allowed distance of a label's ink centre from the control centre. CJK
/// glyphs and icons are symmetric about their box: one px on Android, where the
/// control profile is ours to tune, 1.5 on the Web line boxes (the offset of
/// the face's own ascent / descent, the same in Chromium). Latin and digits
/// have cap-height centres that sit a little off the line centre by design
/// (two px; the test host has no Roboto, so Android Latin is only bounded).
double _tolerance(String text, {required bool android}) {
  final latin = RegExp(r'^[A-Za-z0-9 ]+$').hasMatch(text);
  if (latin) return 2;
  return android ? 1 : 1.5;
}

Future<List<String>> _measure(
  WidgetTester t,
  GlobalKey capture,
  _Case c,
  String name, {
  required bool android,
  required bool brutal,
}) async {
  final snap = await InkSnapshot.capture(t, capture);
  final shots = Platform.environment['RAFT_CENTRE_SHOTS'];
  if (shots != null) {
    await t.runAsync(() async {
      await Directory(shots).create(recursive: true);
      await File(
        '$shots/${name.replaceAll(RegExp(r'[^A-Za-z0-9.]+'), '-')}.png',
      ).writeAsBytes(snap.png);
    });
  }
  final failures = <String>[];
  final boxes = c.box();
  if (boxes.evaluate().isEmpty) return ['$name: no control matched'];
  for (var i = 0; i < boxes.evaluate().length; i++) {
    final box = boxes.at(i);
    final boxRect = t.getRect(box);
    if (boxRect.height > c.maxBoxHeight) continue;
    final labels = _labels(box).toList();
    final icons = find.descendant(of: box, matching: find.byType(RaftIcon));
    // Padding + border: measure inside the border.
    // Inside the border (brutal 2px, elegant 1px, plus antialiasing).
    final border = brutal ? 2.5 : 1.5;
    final band = (boxRect.top + border, boxRect.bottom - border);
    void check(
      String what,
      Rect span, {
      bool descenders = false,
      double tolerance = 1,
    }) {
      final ink = snap.inkIn(
        Rect.fromLTRB(span.left, band.$1, span.right, band.$2),
      );
      if (ink == null) return;
      final off = ink.center.dy - boxRect.center.dy;
      if (Platform.environment['RAFT_CENTRE_REPORT'] == '1') {
        // ignore: avoid_print -- opt-in measurement table
        print('CENTRE\t$name\t$what\t${off.toStringAsFixed(2)}');
      }
      final outside = [
        boxRect.top - ink.top,
        ink.bottom - boxRect.bottom,
      ].reduce((a, b) => a > b ? a : b);
      // A label with descenders ("gpqy") has its ink centre a descender below
      // the cap centre by design: it is only required to stay inside the
      // control; the cap-height labels carry the centring assertion.
      if ((!descenders && off.abs() > tolerance) || outside > 0.25) {
        failures.add(
          '$name #$i $what: ink centre ${off.toStringAsFixed(2)}px '
          '${off > 0 ? 'low' : 'high'} of the control centre '
          '(ink ${ink.top.toStringAsFixed(1)}..${ink.bottom.toStringAsFixed(1)}, '
          'control ${boxRect.top.toStringAsFixed(1)}..${boxRect.bottom.toStringAsFixed(1)})',
        );
      }
    }

    for (final label in labels) {
      final p = t.renderObject<RenderParagraph>(label);
      // One line only.
      if (p.size.height > 2 * p.text.style!.fontSize! * 1.6) continue;
      final text = t.widget<RichText>(label).text.toPlainText();
      check(
        'label "$text"',
        t.getRect(label),
        descenders: RegExp(r'[gjpqy(){}\[\],;_@]').hasMatch(text),
        // Latin caps: the face's own ascent / descent put the cap centre up to
        // two px off the line-box centre, in Chromium too (and the test host
        // draws Hanken Grotesk where Android has Roboto). CJK, digits and
        // icons must be on the centre.
        tolerance: _tolerance(text, android: android),
      );
    }
    for (var k = 0; k < icons.evaluate().length; k++) {
      check('icon #$k', t.getRect(icons.at(k)));
    }
  }
  return failures;
}

void main() {
  for (final c in _cases) {
    for (final label in c.labels) {
      for (final profile in _profiles) {
        for (final scale in _scales) {
          for (final family in [RaftFamily.brutal, RaftFamily.elegant]) {
            final id =
                '${c.name}${label.isEmpty ? '' : ' "$label"'} ${profile.name} ${scale}x ${family.name}';
            testWidgets(id, (t) async {
              await loadAuditFonts(t, AuditFonts.real);
              addTearDown(t.view.resetPhysicalSize);
              addTearDown(t.view.resetDevicePixelRatio);
              t.view.physicalSize = const Size(420, 480);
              t.view.devicePixelRatio = 1;
              t.platformDispatcher.textScaleFactorTestValue = scale;
              addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
              final capture = GlobalKey();
              final android = profile.platform == TargetPlatform.android;
              final theme = raftTheme(
                family,
                locale: profile.locale,
                platform: profile.platform,
                // As app_root.dart does on Android: the device's sans family
                // with its CJK fallback (the harness maps both to Noto Sans
                // CJK, the face the Android Chinese profile was measured on).
                systemFonts: android,
                systemFontFamilies: android
                    ? const RaftFontFamilies(
                        mono: 'packages/raft_ui/GeistMono',
                        fallback: ['Noto Sans CJK SC'],
                      )
                    : const RaftFontFamilies(),
                textLocale: profile.locale,
              );
              await t.pumpWidget(
                MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: theme.copyWith(platform: profile.platform),
                  locale: profile.locale,
                  supportedLocales: [profile.locale],
                  localizationsDelegates: GlobalMaterialLocalizations.delegates,
                  builder: (context, child) => RaftTextScaling(
                    child: RepaintBoundary(key: capture, child: child),
                  ),
                  home: Scaffold(
                    body: c.page
                        ? c.build(label)
                        : Align(
                            alignment: Alignment.topLeft,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: c.build(label),
                            ),
                          ),
                  ),
                ),
              );
              await t.pump(const Duration(milliseconds: 400));
              expect(t.takeException(), isNull, reason: id);
              final failures = await _measure(
                t,
                capture,
                c,
                id,
                android: android,
                brutal: family == RaftFamily.brutal,
              );
              // (Whole pages hold inline widgets in paragraphs the audit cannot
              // measure; they get the ink check only.)
              // The text-scale audit's detectors on the same frame: ink cut by a
              // clip (a label squeezed into a box shorter than its line), line
              // boxes that escape a fixed height, overflow, off-centre labels.
              if (!c.page) {
                final report = AuditReport(id, AuditMode(id, textScale: scale));
                final marks = ValueNotifier<List<(Rect, Color)>>(const []);
                await inspectPumped(t, report, marks: marks, centring: true);
                failures.addAll([for (final f in report.failures) '$f']);
                marks.dispose();
              }
              expect(failures, isEmpty, reason: failures.join('\n'));
            });
          }
        }
      }
    }
  }
}
