import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// db5e399f MainLayout / raft-ui0.7.0: 27px sticker icon; title17/22/700,
// meta12/16/500 below it; default32px tabs inside py8 + border-bottom1.
void main() {
  for (final dark in [false, true]) {
    for (final width in [390.0, 1280.0]) {
      Future<void> mount(WidgetTester t, Widget child) async {
        t.view.physicalSize = Size(width, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(body: Column(children: [child])),
          ),
        );
      }

      testWidgets('Raft $dark $width mounted channel header matches source', (
        t,
      ) async {
        var search = 0, settings = 0;
        await mount(
          t,
          RaftChannelHeader(
            name: 'design',
            description: 'Product and UI decisions',
            onSearch: () => search++,
            onSettings: () => settings++,
          ),
        );
        final title = t.widget<Text>(find.text('design')).style!;
        final meta = t
            .widget<Text>(find.text('Product and UI decisions'))
            .style!;
        expect(
          [
            title.fontSize,
            title.fontSize! * title.height!,
            title.fontWeight!.value,
            t
                .getSize(find.byKey(const ValueKey('conversation-header-icon')))
                .width,
            meta.fontSize,
            meta.fontSize! * meta.height!,
            meta.fontWeight!.value,
          ],
          [17, 22, 700, 27, 12, 16, 500],
        );
        expect(
          t.getTopLeft(find.text('Product and UI decisions')).dy,
          greaterThan(t.getTopLeft(find.text('design')).dy + 15),
        );
        expect(t.getSize(find.byType(RaftConversationHeader)).height, 56);
        for (final label in ['Search This Channel', 'Channel Settings']) {
          expect(t.getSize(find.bySemanticsLabel(label)), const Size(32, 32));
          await t.tap(find.bySemanticsLabel(label));
        }
        expect([search, settings], [1, 1]);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
      testWidgets('Raft $dark $width mounted conversation tabs match source', (
        t,
      ) async {
        var selected = RaftConversationTabId.chat;
        await mount(
          t,
          StatefulBuilder(
            builder: (context, update) => RaftConversationTabs(
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
              value: selected,
              onChanged: (value) => update(() => selected = value),
            ),
          ),
        );
        final strip = t.getRect(find.byType(RaftConversationTabs));
        final chat = find.byKey(const ValueKey('panel-tab-chat'));
        final box = t.getRect(chat);
        expect(
          [
            strip.height,
            box.left,
            box.top - strip.top,
            box.height,
            t.widget<RaftTabButton>(chat).variant,
          ],
          [49, width < 768 ? 16 : 20, 8, 32, RaftTabsVariant.standard],
        );
        await t.tap(find.byKey(const ValueKey('panel-tab-files')));
        expect(selected, RaftConversationTabId.files);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
    }
  }
}
