@Tags(['look-brutal', 'look-elegant'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// Settled pre-change a57 header slots, kept separately from the new Raft contract.
void main() {
  for (final pack in [elegantThemePackId, brutalThemePackId]) {
    for (final dark in [false, true]) {
      for (final width in [390.0, 1280.0]) {
        testWidgets('$pack/$dark/$width preserves header and tab slots', (
          t,
        ) async {
          final brutal = pack == brutalThemePackId && !dark;
          final phone = width < 768;
          t.view.physicalSize = Size(width, 800);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(pack: packForThemeId(pack), dark: dark),
              home: Scaffold(
                body: Column(
                  children: [
                    RaftChannelHeader(
                      name: 'design',
                      description: 'Product and UI',
                      onSearch: () {},
                    ),
                    RaftConversationTabs(
                      tabs: const [
                        RaftConversationTab(
                          id: RaftConversationTabId.chat,
                          label: 'Chat',
                        ),
                        RaftConversationTab(
                          id: RaftConversationTabId.files,
                          label: 'Files',
                        ),
                      ],
                      value: RaftConversationTabId.chat,
                      onChanged: (_) {},
                    ),
                  ],
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          final title = t.widget<Text>(find.text('design')).style!;
          final meta = t.widget<Text>(find.text('Product and UI')).style!;
          expect([
            title.fontSize,
            title.fontSize! * title.height!,
            title.fontWeight!.value,
          ], brutal ? [16, 20, 700] : [17, 21.25, 600]);
          expect(
            [
              meta.fontSize,
              meta.fontSize! * meta.height!,
              meta.fontWeight!.value,
            ],
            [12, brutal ? 16 : (phone ? 15 : 12), 400],
          );
          expect(
            title.fontFamily,
            brutal
                ? 'packages/raft_ui/HankenGrotesk'
                : 'packages/raft_ui/Inter',
          );
          expect(
            meta.fontFamily,
            brutal ? 'packages/raft_ui/GeistMono' : 'packages/raft_ui/Geist',
          );
          expect(
            t.getSize(find.byKey(const ValueKey('conversation-header-icon'))),
            const Size(36, 36),
          );
          final context = t.element(find.byType(RaftConversationHeader));
          final recipe = RaftConversationHeader.recipeOf(
            context,
            hasMeta: true,
          );
          expect(
            recipe.headerContent['flex-direction'].toString(),
            !phone && !brutal ? 'row' : 'column',
          );
          expect(recipe.headerContent.columnGap, brutal ? 0 : (phone ? 4 : 8));
          expect(recipe.actions.columnGap, brutal ? 6 : (phone ? 2 : 6));
          final decoration = recipe.headerIcon.decoration(
            RaftTokens.of(context).recipeTokens,
          );
          expect(
            decoration.borderRadius ?? BorderRadius.zero,
            BorderRadius.circular(brutal ? 0 : 6),
          );
          expect(
            decoration.color,
            brutal
                ? const Color(0xffffd441)
                : RaftTokens.of(context).colors['fill-strong'],
          );
          expect(
            t.getSize(find.bySemanticsLabel('Search This Channel')),
            const Size(28, 28),
          );
          final strip = t.getRect(find.byType(RaftConversationTabs));
          final chat = find.byKey(const ValueKey('panel-tab-chat'));
          expect(
            [
              strip.height,
              t.getRect(chat).left,
              t.getRect(chat).top - strip.top,
              t.getSize(chat).height,
            ],
            [phone ? 41 : 48, 16, 0, phone ? 40 : 48],
          );
          expect(
            t.widget<RaftTabButton>(chat).variant,
            RaftTabsVariant.underline,
          );
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox.shrink());
        }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
      }
    }
  }
}
