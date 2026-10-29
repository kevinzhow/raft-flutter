// Guards the Android Chinese control-label profile (RaftControlTypography) on
// real product surfaces: the Activity page's filter buttons, badges and
// "mark all read" button. A local TextStyle that restates height or leading
// would bypass the recipes and fail here (a style-propagation leak).
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

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

bool isProfile(TextStyle? style) =>
    style != null &&
    style.height == RaftControlTypographyTokens.androidChineseLineHeight &&
    style.leadingDistribution == TextLeadingDistribution.proportional;

void main() {
  late _Client c;
  late _Workspace w;
  setUp(() {
    c = _Client()..user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
    c.selectServer('s');
    w = _Workspace(c)..server = RaftRecord({'id': 's', 'role': 'owner'});
  });
  tearDown(() async {
    w.dispose();
    await c.dispose();
  });

  Future<void> mount(
    WidgetTester t, {
    required Locale locale,
    required TargetPlatform platform,
  }) async {
    final theme = raftTheme(locale: locale, platform: platform);
    await t.pumpWidget(
      MaterialApp(
        theme: theme.copyWith(platform: platform),
        // The touch Activity list refreshes by pulling: RefreshIndicator needs
        // Material localizations for every locale this test mounts.
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
        home: Builder(
          builder: (context) => Localizations.override(
            context: context,
            locale: locale,
            child: RaftDensityScope(
              density: RaftDensity.touch,
              child: Scaffold(
                body: ResourceView(
                  controller: w,
                  section: 'activity',
                  onMessage: (_, _) async {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  /// Label paragraphs of each control (icon glyphs excluded).
  Map<String, List<TextStyle?>> controlLabels(
    WidgetTester t, {
    String markAll = '全部已读',
  }) {
    List<TextStyle?> styles(Finder root) => [
      for (final p in t.widgetList<RichText>(
        find.descendant(of: root, matching: find.byType(RichText)),
      ))
        if (p.text.style?.fontFamily != 'MaterialIcons' &&
            p.text.toPlainText().trim().isNotEmpty)
          p.text.style,
    ];
    expect(find.text(markAll), findsOneWidget);
    return {
      'filters': styles(find.byType(RaftSegmentedControl<String>)),
      'badges': styles(find.byType(RaftResourceBadge)),
      // The button's own text: the box wraps nothing else.
      'mark all read': styles(find.byType(RaftResourceMarkReadButton)),
    };
  }

  testWidgets('Activity controls take the profile on Android Chinese', (
    t,
  ) async {
    await mount(
      t,
      locale: const Locale('zh', 'CN'),
      platform: TargetPlatform.android,
    );
    expect(find.text('全部'), findsWidgets);
    expect(find.text('全部已读'), findsOneWidget);
    expect(find.byType(RaftResourceBadge), findsNWidgets(4));
    final labels = controlLabels(t);
    for (final entry in labels.entries) {
      expect(entry.value, isNotEmpty, reason: entry.key);
      for (final style in entry.value) {
        expect(isProfile(style), isTrue, reason: '${entry.key}: $style');
      }
    }
  });

  testWidgets('Activity controls are unchanged on iOS and in English', (
    t,
  ) async {
    for (final (locale, platform) in [
      (const Locale('zh', 'CN'), TargetPlatform.iOS),
      (const Locale('en'), TargetPlatform.android),
    ]) {
      await mount(t, locale: locale, platform: platform);
      final markAll = locale.languageCode == 'zh' ? '全部已读' : 'Mark all read';
      for (final entry in controlLabels(t, markAll: markAll).entries) {
        expect(entry.value, isNotEmpty, reason: entry.key);
        for (final style in entry.value) {
          expect(
            isProfile(style),
            isFalse,
            reason: '$locale $platform ${entry.key}: $style',
          );
        }
      }
    }
  });
}
