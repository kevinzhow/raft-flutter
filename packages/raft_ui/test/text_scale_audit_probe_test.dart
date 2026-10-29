// Unit tests for the detector in tool/testing/text_scale_audit.dart, using
// synthetic widgets with a known outcome (bad ones must be flagged, good ones
// must stay clean), so a clean report from the surface sweeps means something.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart' show RaftCssText;

import '../../../tool/testing/text_scale_audit.dart';

Future<AuditReport> run(
  WidgetTester t,
  Widget Function() build, {
  AuditMode mode = AuditMode.x2,
  Size size = const Size(300, 200),
}) async {
  await loadAuditFonts(t, AuditFonts.real);
  final base = <String, bool>{};
  await auditSurface(
    t,
    surface: 'probe',
    build: build,
    theme: ThemeData(fontFamily: 'packages/raft_ui/HankenGrotesk'),
    mode: AuditMode.base,
    size: size,
    truncationBaseline: base,
  );
  return auditSurface(
    t,
    surface: 'probe',
    build: build,
    theme: ThemeData(fontFamily: 'packages/raft_ui/HankenGrotesk'),
    mode: mode,
    size: size,
    truncationBaseline: base,
    screenshotDir: '${Directory.systemTemp.path}/text-scale-audit/probe-unit',
  );
}

void main() {
  const style = TextStyle(fontSize: 14, height: 20 / 14);

  testWidgets('clean: text with a min-height box does not fail at 2x', (
    t,
  ) async {
    final r = await run(
      t,
      () => Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 20),
          child: const Text('Settings', style: style),
        ),
      ),
    );
    expect(r.ok, isTrue, reason: r.failures.join('\n'));
    expect(r.paragraphs, greaterThan(0));
  });

  testWidgets(
    'fixed-height box whose child ignores the height: escapes at 2x',
    (t) async {
      final r = await run(
        t,
        () => const Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            height: 20,
            child: OverflowBox(
              maxHeight: double.infinity,
              child: Text('Settings', style: style),
            ),
          ),
        ),
      );
      expect(r.escapes, isNotEmpty);
      // The same box at 1.0x is fine.
      final base = await run(
        t,
        () => const Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            height: 20,
            child: OverflowBox(
              maxHeight: double.infinity,
              child: Text('Settings', style: style),
            ),
          ),
        ),
        mode: AuditMode.base,
      );
      expect(base.ok, isTrue, reason: base.failures.join('\n'));
    },
  );

  testWidgets('CSS line blank leading does not paint outside its control', (
    t,
  ) async {
    const cssStyle = TextStyle(
      fontFamily: 'packages/raft_ui/SpaceGrotesk',
      fontSize: 17,
      height: 22 / 17,
      leadingDistribution: TextLeadingDistribution.even,
    );
    final r = await run(
      t,
      () => const Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          height: 44,
          child: RaftCssText(
            'design',
            style: cssStyle,
            maxLines: 1,
            softWrap: false,
            strutStyle: StrutStyle(
              fontFamily: 'packages/raft_ui/SpaceGrotesk',
              fontSize: 17,
              height: 22 / 17,
              forceStrutHeight: true,
              leadingDistribution: TextLeadingDistribution.even,
            ),
          ),
        ),
      ),
    );
    expect(r.escapes, isEmpty, reason: r.failures.join('\n'));
    expect(r.inkClipped, isEmpty, reason: r.failures.join('\n'));
  });

  testWidgets('CSS text that really overpaints its control is still reported', (
    t,
  ) async {
    final r = await run(
      t,
      () => const Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          height: 16,
          child: OverflowBox(
            maxHeight: double.infinity,
            child: RaftCssText(
              'Gypsy',
              style: TextStyle(fontSize: 17, height: 22 / 17),
            ),
          ),
        ),
      ),
    );
    expect(r.escapes, isNotEmpty);
  });

  testWidgets(
    'CSS guard retains ink overpaint and clips across fonts and locales',
    (t) async {
      for (final font in ['SpaceGrotesk', 'SpaceMono']) {
        for (final (mode, text) in [
          (
            const AuditMode(
              'zh-2.0x',
              textScale: 2,
              locale: Locale('zh', 'CN'),
            ),
            'Gypsy 骨直令',
          ),
          (AuditMode.x31, 'Gypsy lower descenders'),
          (
            const AuditMode(
              'zh-3.1x',
              textScale: 3.1,
              locale: Locale('zh', 'CN'),
            ),
            '骨直令 Gypsy',
          ),
        ]) {
          for (final clipped in [false, true]) {
            Widget build() {
              final control = SizedBox(
                height: 16,
                child: OverflowBox(
                  maxHeight: double.infinity,
                  child: RaftCssText(
                    text,
                    style: TextStyle(
                      fontFamily: 'packages/raft_ui/$font',
                      fontSize: 17,
                      height: 22 / 17,
                    ),
                  ),
                ),
              );
              return Align(
                alignment: Alignment.topLeft,
                child: clipped ? ClipRect(child: control) : control,
              );
            }

            final report = await run(t, build, mode: mode);
            final reason = '$font/${mode.name}/clipped=$clipped';
            expect(report.escapes, isNotEmpty, reason: reason);
            if (clipped) expect(report.inkClipped, isNotEmpty, reason: reason);
          }
        }
      }
    },
  );

  testWidgets('tight fixed-height box: the paragraph clips its own text', (
    t,
  ) async {
    final r = await run(
      t,
      () => const Align(
        alignment: Alignment.topLeft,
        child: SizedBox(height: 20, child: Text('Settings', style: style)),
      ),
    );
    expect(r.inkClipped, isNotEmpty);
  });

  testWidgets('ClipRect around a fixed-height row cuts ink at 2x', (t) async {
    final r = await run(
      t,
      () => const Align(
        alignment: Alignment.topLeft,
        child: ClipRect(
          child: SizedBox(
            height: 20,
            child: OverflowBox(
              maxHeight: 200,
              child: Text('Gypsy 骨直令', style: style),
            ),
          ),
        ),
      ),
    );
    expect(r.inkClipped, isNotEmpty);
  });

  testWidgets('RenderFlex overflow is reported', (t) async {
    final r = await run(
      t,
      () => const Row(
        children: [
          Text('A very long label that does not fit in a row', style: style),
        ],
      ),
      size: const Size(120, 100),
    );
    expect(r.overflow, isNotEmpty);
  });

  testWidgets('ellipsis truncation is informational, clip is a hard cut', (
    t,
  ) async {
    final ellipsis = await run(
      t,
      () => const Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 160,
          child: Text(
            'Quarterly notes',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ),
    );
    expect(ellipsis.truncated, isNotEmpty);
    expect(ellipsis.hardCut, isEmpty);
    final clip = await run(
      t,
      () => const Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 160,
          child: Text(
            'Quarterly notes',
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: style,
          ),
        ),
      ),
    );
    expect(clip.hardCut, isNotEmpty);
  });
}
