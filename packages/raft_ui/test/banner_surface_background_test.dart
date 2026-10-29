import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/surface_background_scope.dart';

// db5e399f / raft-ui 0.7.0 current dialog capture: this is the actual
// opaque surface, not a guessed global Banner background.
const _dialogSurface = Color(0xff292927);

Color _paintedBannerColor(WidgetTester tester) => tester
    .widgetList<Container>(
      find.descendant(
        of: find.byType(RaftBanner),
        matching: find.byType(Container),
      ),
    )
    .map(
      (widget) => switch (widget.decoration) {
        RaftLayeredDecoration(:final base) => base,
        final BoxDecoration decoration => decoration,
        _ => null,
      },
    )
    .whereType<BoxDecoration>()
    .first
    .color!;

Future<Color> _mount(
  WidgetTester tester, {
  String look = raftThemePackId,
  bool dark = true,
  bool declared = true,
  Color? surface = _dialogSurface,
  bool barrier = false,
  Color? override,
}) async {
  late Color source;
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(pack: packForThemeId(look), dark: dark),
      home: Builder(
        builder: (context) {
          source =
              override ??
              RaftTokens.of(context).colors['layer-banner-warning']!;
          Widget banner = RaftBanner(
            description: 'A source warning',
            backgroundColor: override,
          );
          if (barrier) {
            banner = RaftSurfaceBackgroundScope(color: null, child: banner);
          }
          if (declared) {
            banner = RaftSurfaceBackgroundScope(color: surface, child: banner);
          }
          return Center(child: SizedBox(width: 300, child: banner));
        },
      ),
    ),
  );
  return source;
}

void main() {
  testWidgets('declared opaque surface uses the current Web warning fill', (
    tester,
  ) async {
    final source = await _mount(tester);
    expect(source.a, lessThan(1));
    // Exact Web flat interior: 62,48,36. The uncomposited Flutter path
    // previously produced 62,48,37 on this same 41,41,39 background.
    expect(_paintedBannerColor(tester), const Color(0xff3e3024));
  });

  testWidgets('undeclared, transparent and unknown surfaces retain live fill', (
    tester,
  ) async {
    for (final config in [
      (declared: false, barrier: false, color: _dialogSurface),
      (declared: true, barrier: true, color: _dialogSurface),
      (declared: true, barrier: false, color: const Color(0x80292927)),
    ]) {
      final source = await _mount(
        tester,
        declared: config.declared,
        barrier: config.barrier,
        surface: config.color,
      );
      expect(_paintedBannerColor(tester), source);
    }
  });

  testWidgets('custom opaque Banner fill is never precomposited again', (
    tester,
  ) async {
    const custom = Color(0xff4a5662);
    await _mount(tester, override: custom);
    expect(_paintedBannerColor(tester), custom);
  });

  for (final look in ['elegant', 'brutal']) {
    testWidgets('frozen $look ignores the modern surface blend', (
      tester,
    ) async {
      final source = await _mount(tester, look: look, dark: false);
      expect(_paintedBannerColor(tester), source);
    });
  }
}
