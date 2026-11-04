import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/appearance_section.dart';
import 'package:raft_flutter/features/public_appearance_previews.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final theme in raftThemeMatrix(
    ['raft-light', 'raft-dark', 'elegantLight', 'elegantDark', 'brutal'],
    look: (s) => s.startsWith('raft')
        ? 'raft'
        : s.startsWith('elegant')
        ? 'elegant'
        : 'brutal',
  )) {
    for (final size in [
      const Size(390, 844),
      const Size(856, 944),
      const Size(944, 856),
    ]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'public Appearance $theme $size ${scale}x uses only the shared mode cards',
          (t) async {
            t.view.physicalSize = size;
            t.view.devicePixelRatio = 1;
            addTearDown(t.view.reset);
            final semantics = t.ensureSemantics();
            try {
              final pack = theme.startsWith('raft')
                  ? raftThemePackId
                  : theme.startsWith('elegant')
                  ? elegantThemePackId
                  : brutalThemePackId;
              var value = RaftAppearance(
                mode: theme.toLowerCase().endsWith('dark')
                    ? ThemeMode.dark
                    : ThemeMode.light,
                themeId: pack,
              );
              await t.pumpWidget(
                MaterialApp(
                  theme: raftTheme(pack: packForThemeId(pack)),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: StatefulBuilder(
                      builder: (context, update) => SingleChildScrollView(
                        child: RaftAppearanceSection(
                          appearance: value,
                          onAppearance: (next) => update(() => value = next),
                          presentation: null,
                          publicSurface: true,
                        ),
                      ),
                    ),
                  ),
                ),
              );
              expect(find.byType(RaftAppearanceModeCards), findsOneWidget);
              for (final hidden in [
                'Message font size',
                'Live agent activity',
                'Show agent model',
                'Hide empty sidebar sections',
                'Look',
                'App icon',
              ]) {
                expect(find.text(hidden), findsNothing, reason: hidden);
              }
              final dark = find.byKey(const ValueKey('appearance-theme-dark'));
              await t.ensureVisible(dark);
              await t.tap(dark);
              await t.pumpAndSettle();
              expect(value.mode, ThemeMode.dark);
              expect(
                t.getSemantics(dark),
                matchesSemantics(
                  label: 'Dark\nDark\nSaved on this device.',
                  isButton: true,
                  isSelected: true,
                  hasSelectedState: true,
                  hasTapAction: true,
                ),
              );
              expect(t.takeException(), isNull);
            } finally {
              semantics.dispose();
            }
          },
        );
      }
    }
  }
  testWidgets('public Appearance is available in the SDK page preview', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(body: publicAppearanceReferencePreview()),
      ),
    );
    expect(find.byType(RaftAppearanceModeCards), findsOneWidget);
    expect(find.text('Message font size'), findsNothing);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  });
}
