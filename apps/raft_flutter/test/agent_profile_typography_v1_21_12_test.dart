import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/parity_harness.dart' show loadParityFonts;

/// Web v1.21.12 agent-profile typography (AgentDetailPanel InfoRow / header
/// name / handle, KeyValueRow, AvatarListRow, `ProfilePanelBody font-sans`).
void main() {
  setUpAll(loadParityFonts);

  Future<RaftTokens> host(
    WidgetTester tester,
    Widget child, {
    required RaftFamily family,
    bool dark = false,
  }) async {
    late RaftTokens tokens;
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(family, dark: dark),
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
      family: RaftFamily.elegant,
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

  testWidgets('brutal info row keeps black ink at the new 13px term', (
    tester,
  ) async {
    await host(
      tester,
      const RaftInfoRow(label: 'Computer', child: Text('Mac')),
      family: RaftFamily.brutal,
    );
    expect(styleOf(tester, 'Computer').fontSize, 13);
    expect(styleOf(tester, 'Mac').color, Colors.black);
  });

  testWidgets('elegant detail-block name is PanelTitle: 17 semibold muted', (
    tester,
  ) async {
    final t = await host(
      tester,
      const RaftProfileIdentity(name: 'Product UX Designer', handle: 'pux'),
      family: RaftFamily.elegant,
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

  testWidgets('brutal detail-block name stays 18 bold, now pure black', (
    tester,
  ) async {
    await host(
      tester,
      const RaftProfileIdentity(name: 'Product UX Designer', handle: 'pux'),
      family: RaftFamily.brutal,
    );
    final name = styleOf(tester, 'Product UX Designer');
    expect(name.fontSize, 18);
    expect(name.fontWeight, FontWeight.w700);
    expect(name.color, Colors.black);
    expect(styleOf(tester, '@pux').fontSize, 14);
  });

  testWidgets('profile text scope switches to Geist only with `sans`', (
    tester,
  ) async {
    final t = await host(
      tester,
      const RaftPanelTextScope(sans: true, child: Text('Body')),
      family: RaftFamily.elegant,
    );
    final style = DefaultTextStyle.of(tester.element(find.text('Body'))).style;
    expect(style.fontFamily, t.bodyFont);
    await host(
      tester,
      const RaftPanelTextScope(child: Text('Body')),
      family: RaftFamily.elegant,
    );
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
      family: RaftFamily.elegant,
    );
    expect(styleOf(tester, 'Email').fontSize, 13);
    expect(styleOf(tester, 'Email').color, t.colors['foreground-hint']);
    expect(styleOf(tester, 'a@b.c').color, t.colors['foreground-muted']);
    final name = styleOf(tester, 'Helper');
    expect(name.fontWeight, FontWeight.w600);
    expect(name.color, t.colors['foreground-muted']);
    expect(styleOf(tester, 'Claude').color, t.colors['foreground-hint']);
  });

  testWidgets('profile header handle is 15px mono in elegant only', (
    tester,
  ) async {
    final t = await host(
      tester,
      const RaftPanelHeaderBar(
        title: 'Agent',
        subtitle: '@agent',
        profileHandle: true,
      ),
      family: RaftFamily.elegant,
    );
    final handle = styleOf(tester, '@agent');
    expect(handle.fontSize, 15);
    expect(handle.fontFamily, t.monoFont);
    await host(
      tester,
      const RaftPanelHeaderBar(
        title: 'Agent',
        subtitle: '@agent',
        profileHandle: true,
      ),
      family: RaftFamily.brutal,
    );
    expect(styleOf(tester, '@agent').fontSize, 12);
  });
}
