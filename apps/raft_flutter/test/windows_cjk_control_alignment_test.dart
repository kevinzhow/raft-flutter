// Exercise the actual Windows fallback face, not Noto substituted for YaHei.
// Native-engine acceptance is recorded separately; this guards the same ink
// alignment across the shared control family after a Windows regression.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../../tool/testing/ink_alignment.dart';
import '../../../tool/testing/text_scale_audit.dart'
    show AuditFonts, loadAuditFonts;

final _yahei = File(
  '${Platform.environment['WINDIR'] ?? 'C:/Windows'}/Fonts/msyh.ttc',
);
bool _loaded = false;

Future<void> _fonts(WidgetTester tester) async {
  await loadAuditFonts(tester, AuditFonts.real);
  if (_loaded) return;
  await tester.runAsync(() async {
    final faces = [
      for (final name in ['msyh.ttc', 'msyhbd.ttc'])
        ByteData.sublistView(
          await File('${_yahei.parent.path}/$name').readAsBytes(),
        ),
    ];
    // The tester has no OS fallback discovery. Bind absent CJK aliases to the
    // same YaHei bytes Windows selects after skipping those absent families,
    // so an unresolved alias cannot silently paint an Ahem square.
    for (final family in [
      'PingFang SC',
      'Hiragino Sans GB',
      'Microsoft YaHei',
      'Noto Sans SC',
      'Noto Sans CJK SC',
      'Noto Sans CJK JP',
      'sans-serif',
    ]) {
      final loader = FontLoader(family);
      for (final bytes in faces) {
        loader.addFont(Future.value(bytes));
      }
      await loader.load();
    }
  });
  _loaded = true;
}

void main() {
  testWidgets('Windows Chinese tabs align glyph ink with their icons', (
    tester,
  ) async {
    await _fonts(tester);
    // Match the Windows native-engine measurement host (150% display scale).
    tester.view.physicalSize = const Size(1650, 975);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => RaftControlTypography.debugDisabled = false);
    final failures = <String>[];
    var improved = 0;
    for (final (theme, scale) in [
      for (final theme in ['raft', 'elegant', 'brutal'])
        for (final scale in [1.0, 1.3, 2.0]) (theme, scale),
    ]) {
      final boundary = GlobalKey();
      Future<InkSnapshot> mount(bool disabled) async {
        RaftControlTypography.debugDisabled = disabled;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(
              pack: packForThemeId(theme),
              locale: const Locale('zh', 'CN'),
              platform: TargetPlatform.windows,
            ).copyWith(platform: TargetPlatform.windows),
            locale: const Locale('zh', 'CN'),
            supportedLocales: const [Locale('zh', 'CN')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: RepaintBoundary(
                  key: boundary,
                  child: const SizedBox(
                    width: 900,
                    child: RaftConversationTabs(
                      tabs: [
                        RaftConversationTab(
                          id: RaftConversationTabId.chat,
                          label: '聊天',
                        ),
                        RaftConversationTab(
                          id: RaftConversationTabId.tasks,
                          label: '任务',
                        ),
                        RaftConversationTab(
                          id: RaftConversationTabId.files,
                          label: '文件',
                        ),
                      ],
                      value: RaftConversationTabId.chat,
                      onChanged: _select,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return InkSnapshot.capture(tester, boundary);
      }

      final before = await mount(true);
      final shot = await mount(false);
      final evidence = Platform.environment['RAFT_CJK_EVIDENCE'];
      if (evidence != null) {
        await tester.runAsync(() async {
          await Directory(evidence).create(recursive: true);
          await File('$evidence/widget-$theme-$scale.png')
              .writeAsBytes(shot.png);
        });
      }
      final origin = tester.getTopLeft(find.byKey(boundary));
      for (final name in ['聊天', '文件']) {
        final tab = find.ancestor(
          of: find.text(name),
          matching: find.byType(RaftTabButton),
        );
        final text = find.descendant(of: tab, matching: find.byType(RichText));
        final paragraph = tester.renderObject<RenderParagraph>(text);
        final textRect = (paragraph.localToGlobal(Offset.zero) & paragraph.size)
            .shift(-origin);
        final icon = find.descendant(of: tab, matching: find.byType(RaftIcon));
        final iconRect = tester.getRect(icon).shift(-origin);
        final box = tester.getRect(tab).shift(-origin);
        final ink = shot.inkIn(
          Rect.fromLTRB(
            textRect.left,
            box.top + 3,
            textRect.right,
            box.bottom - 3,
          ),
        );
        final iconInk = shot.inkIn(iconRect);
        expect(ink, isNotNull);
        expect(iconInk, isNotNull);
        final delta = ink!.center.dy - iconInk!.center.dy;
        final oldInk = before.inkIn(
          Rect.fromLTRB(
            textRect.left,
            box.top + 3,
            textRect.right,
            box.bottom - 3,
          ),
        )!;
        final oldIcon = before.inkIn(iconRect)!;
        final oldDelta = oldInk.center.dy - oldIcon.center.dy;
        if (oldDelta.abs() - delta.abs() >= .25) improved++;
        // The native 1.5x device has a 2/3 dp pixel. The 4x raster samples
        // that tolerance in quarter-dp steps, so the bound is .75 dp.
        if (delta.abs() > .75 || delta.abs() > oldDelta.abs() + .25) {
          failures.add('$theme $scale $name: ink/icon offset $delta');
        }
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(failures, isEmpty);
    expect(
      improved,
      greaterThan(0),
      reason: 'The fix must reduce measured ink offsets, not only change a style value.',
    );
    // A missing Windows face skips this device-font check; never substitute Noto.
  }, skip: !_yahei.existsSync());

  testWidgets(
    'Mac, Linux and Windows English controls paint identically with the correction disabled',
    (tester) async {
      await _fonts(tester);
      addTearDown(() => RaftControlTypography.debugDisabled = false);
      final capture = GlobalKey();
      for (final (platform, locale) in [
        (TargetPlatform.macOS, const Locale('zh', 'CN')),
        (TargetPlatform.linux, const Locale('zh', 'CN')),
        (TargetPlatform.windows, const Locale('en')),
      ]) {
        for (final theme in ['raft', 'elegant', 'brutal']) {
          Future<InkSnapshot> mount(bool disabled) async {
            RaftControlTypography.debugDisabled = disabled;
            await tester.pumpWidget(
              MaterialApp(
                theme: raftTheme(
                  pack: packForThemeId(theme),
                  locale: locale,
                  platform: platform,
                ).copyWith(platform: platform),
                home: Builder(
                  builder: (context) => Localizations.override(
                    context: context,
                    locale: locale,
                    child: Scaffold(
                      body: Align(
                        alignment: Alignment.topLeft,
                        child: RepaintBoundary(
                          key: capture,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              RaftTabButton(
                                label: locale.languageCode == 'en'
                                    ? 'Files'
                                    : '文件',
                                glyph: RaftGlyph.paperclip,
                                onPressed: () {},
                              ),
                              const RaftBadge(label: 'OpenAI'),
                              const RaftCssText(
                                'Body',
                                style: TextStyle(
                                  height: 1.2,
                                  leadingDistribution:
                                      TextLeadingDistribution.proportional,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            return InkSnapshot.capture(tester, capture);
          }

          final before = await mount(true);
          final after = await mount(false);
          expect(
            after.png,
            orderedEquals(before.png),
            reason: '$platform $locale $theme',
          );
        }
      }
    },
    skip: !_yahei.existsSync(),
  );
}

void _select(RaftConversationTabId _) {}
