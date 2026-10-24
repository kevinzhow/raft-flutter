import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/parity_harness.dart' show loadParityFonts;

/// Default Raft typography after the v1.21.23 design migration; original
/// v1.21.12 profile structure remains covered (AgentDetailPanel InfoRow / header
/// name / handle, KeyValueRow, AvatarListRow, `ProfilePanelBody font-sans`).
void main() {
  setUpAll(loadParityFonts);

  Future<RaftTokens> host(
    WidgetTester tester,
    Widget child, {
    bool dark = false,
  }) async {
    // A normal phone viewport; 600px-tall windows use the compact header.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    late RaftTokens tokens;
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(dark: dark),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              tokens = RaftTokens.of(context);
              return Align(
                alignment: Alignment.topLeft,
                child: SizedBox(width: 390, child: child),
              );
            },
          ),
        ),
      ),
    );
    // MaterialApp animates theme changes between two hosts of one test.
    await tester.pumpAndSettle();
    return tokens;
  }

  TextStyle styleOf(WidgetTester tester, String text) {
    final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
    return paragraph.text.style!;
  }

  testWidgets('info row: 124px term in 13px hint ink, muted 14px value', (
    tester,
  ) async {
    final t = await host(
      tester,
      const RaftInfoRow(label: 'Computer', child: Text('Mac')),
    );
    final label = styleOf(tester, 'Computer');
    expect(label.fontSize, 13);
    expect(label.color, t.colors['foreground-hint']);
    // Term column 7.75rem + gap-x-4: the value starts at 124 + 16.
    expect(tester.getTopLeft(find.text('Mac')).dx, 140);
    final value = styleOf(tester, 'Mac');
    expect(value.fontSize, 14);
    expect(value.color, t.colors['foreground-muted']);
  });

  testWidgets('dark info row keeps its 13px term and muted value', (
    tester,
  ) async {
    final t = await host(
      tester,
      const RaftInfoRow(label: 'Computer', child: Text('Mac')),
      dark: true,
    );
    expect(styleOf(tester, 'Computer').fontSize, 13);
    expect(styleOf(tester, 'Mac').color, t.colors['foreground-muted']);
  });

  testWidgets('elegant detail-block name is PanelTitle: 17 semibold muted', (
    tester,
  ) async {
    final t = await host(
      tester,
      const RaftProfileIdentity(name: 'Product UX Designer', handle: 'pux'),
    );
    final name = styleOf(tester, 'Product UX Designer');
    expect(name.fontSize, 17);
    expect(name.fontWeight, FontWeight.w600);
    expect(name.color, t.colors['foreground-muted']);
    final handle = styleOf(tester, '@pux');
    expect(handle.fontSize, 15);
    expect(handle.fontFamily, t.monoFont);
    expect(handle.color, t.colors['foreground-placeholder']);
  });

  testWidgets('dark detail-block name keeps its 17px semibold muted role', (
    tester,
  ) async {
    final t = await host(
      tester,
      const RaftProfileIdentity(name: 'Product UX Designer', handle: 'pux'),
      dark: true,
    );
    final name = styleOf(tester, 'Product UX Designer');
    expect(name.fontSize, 17);
    expect(name.fontWeight, FontWeight.w600);
    expect(name.color, t.colors['foreground-muted']);
    expect(styleOf(tester, '@pux').fontSize, 15);
  });

  testWidgets('profile text scope switches to Geist only with `sans`', (
    tester,
  ) async {
    final t = await host(
      tester,
      const RaftPanelTextScope(sans: true, child: Text('Body')),
    );
    final style = DefaultTextStyle.of(tester.element(find.text('Body'))).style;
    expect(style.fontFamily, t.bodyFont);
    await host(tester, const RaftPanelTextScope(child: Text('Body')));
    expect(
      DefaultTextStyle.of(tester.element(find.text('Body'))).style.fontFamily,
      t.headingFont,
    );
  });

  testWidgets('key-value row and created-agent row follow the new inks', (
    tester,
  ) async {
    final t = await host(
      tester,
      Column(
        children: const [
          RaftKeyValueRow(label: 'Email', value: 'a@b.c'),
          RaftAvatarListRow(
            avatar: SizedBox.square(dimension: 24),
            name: 'Helper',
            subtitle: 'Claude',
          ),
        ],
      ),
    );
    expect(styleOf(tester, 'Email').fontSize, 13);
    expect(styleOf(tester, 'Email').color, t.colors['foreground-hint']);
    expect(styleOf(tester, 'a@b.c').color, t.colors['foreground-muted']);
    final name = styleOf(tester, 'Helper');
    expect(name.fontWeight, FontWeight.w600);
    expect(name.color, t.colors['foreground-muted']);
    expect(styleOf(tester, 'Claude').color, t.colors['foreground-hint']);
  });

  testWidgets('Raft profile header uses the source 12px mono-meta role', (
    tester,
  ) async {
    final t = await host(
      tester,
      const RaftPanelHeaderBar(
        title: 'Agent',
        subtitle: '@agent',
        profileHandle: true,
      ),
    );
    final handle = styleOf(tester, '@agent');
    expect(handle.fontSize, 12);
    expect(handle.fontFamily, t.monoFont);
    await host(
      tester,
      const RaftPanelHeaderBar(
        title: 'Agent',
        subtitle: '@agent',
        profileHandle: true,
      ),
    );
    expect(styleOf(tester, '@agent').fontSize, 12);
  });

  testWidgets('Raft profile header carries the 1px line-seam divider', (
    tester,
  ) async {
    final t = await host(
      tester,
      const RaftPanelHeaderBar(title: 'Agent', profileBody: true),
    );
    BoxDecoration headerDecoration() => tester
        .widgetList<Container>(
          find.ancestor(
            of: find.text('Agent'),
            matching: find.byType(Container),
          ),
        )
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.border != null);
    final border = headerDecoration().border! as Border;
    expect(border.bottom.width, 1);
    expect(border.bottom.color, t.ui.lineSeam);
    // The divider sits inside the header's own height.
    expect(tester.getSize(find.byType(RaftPanelHeaderBar)).height, 56);
  });

  testWidgets('Raft tab strip is the sticker row under a seam rule', (
    tester,
  ) async {
    await host(
      tester,
      RaftPanelTabBar<String>(
        tabs: const [
          RaftPanelTab('a', 'Profile', RaftGlyph.bot),
          RaftPanelTab('b', 'Chat', RaftGlyph.bot),
        ],
        value: 'a',
        onChanged: (_) {},
      ),
    );
    // ConversationPanelTabs: `py-2` list of 32px sticker tabs (48) plus the
    // root `border-b border-line-seam` (1). The pre-theme looks keep the
    // underline strip (panelTabs.style).
    expect(tester.getSize(find.byType(RaftPanelTabBar<String>)).height, 49);
    // Label starts at the 20px `px-5` list inset + 12px tab padding.
    expect(tester.getTopLeft(find.text('Profile')).dx, greaterThan(32));
  });

  testWidgets('identity name row is 22.5px in elegant too', (tester) async {
    await host(
      tester,
      const RaftProfileIdentity(name: 'Product UX Designer', handle: 'pux'),
    );
    final name = find.ancestor(
      of: find.text('Product UX Designer'),
      matching: find.byType(RaftCssText),
    );
    final handle = find.ancestor(
      of: find.text('@pux'),
      matching: find.byType(RaftCssText),
    );
    expect(tester.getRect(name).top, 20);
    expect(tester.getRect(handle).top, 42.5);
  });

  testWidgets('Raft avatar slot clips to the padding-box sticker radius', (
    tester,
  ) async {
    await host(
      tester,
      const RaftAvatarSlot(
        name: 'A',
        slot: RaftAvatarSlotContext.panelHeader,
        avatarUrl: 'pixel:robot',
      ),
    );
    final clip = tester.widget<ClipRRect>(
      find.descendant(
        of: find.byType(RaftAvatarSlot),
        matching: find.byType(ClipRRect),
      ),
    );
    // Raft avatar: 4px outer sticker radius less its 2px used border.
    expect(clip.borderRadius, BorderRadius.circular(2));
  });

  testWidgets('key-value row accepts a node that inherits the value style', (
    tester,
  ) async {
    final t = await host(
      tester,
      const RaftKeyValueRow.child(label: 'Created', child: Text('Jun 18')),
    );
    expect(styleOf(tester, 'Created').fontSize, 13);
    final style = DefaultTextStyle.of(tester.element(find.text('Jun 18')))
        .style;
    expect(style.color, t.colors['foreground-muted']);
    expect(style.fontSize, 14);
  });
}
