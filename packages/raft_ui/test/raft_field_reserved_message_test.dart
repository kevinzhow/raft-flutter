import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('reserved field message has one Web line $dark', (t) async {
      Future<double> height({
        String? hint,
        String? error,
        String? counter,
      }) async {
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 408,
                  child: RaftStableField(
                    label: 'Name',
                    hint: hint,
                    error: error,
                    counter: counter,
                    child: const SizedBox(
                      key: Key('field-control'),
                      height: 44,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        return t.getSize(find.byType(RaftStableField)).height;
      }

      // Web StableField: label 18 + gap 6 + control 44 + gap 6 + reserved line 16.
      final empty = await height();
      expect(empty, 90);
      expect(await height(hint: 'A helpful hint'), empty);
      expect(await height(error: 'A validation error'), empty);
      expect(await height(counter: '72/3000'), empty);
    });

    testWidgets('reserved message stays stable for one scaled line $dark', (
      t,
    ) async {
      Future<double> height({String? hint}) async {
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(3.1)),
              child: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 600,
                    child: RaftStableField(
                      label: 'Name',
                      hint: hint,
                      child: const SizedBox(height: 44),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        return t.getSize(find.byType(RaftStableField)).height;
      }

      final empty = await height();
      expect(await height(hint: 'Hint'), empty);
    });

    testWidgets('reserved message can grow when text scales and wraps $dark', (
      t,
    ) async {
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: dark),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(3.1)),
            child: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 300,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const RaftStableField(
                        label: 'Name',
                        hint: 'A long helpful hint must wrap without clipping its text.',
                        child: SizedBox(key: Key('field-control'), height: 44),
                      ),
                      const SizedBox(key: Key('next'), height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final message = find.text(
        'A long helpful hint must wrap without clipping its text.',
      );
      final paragraph = t.renderObject<RenderParagraph>(message);
      expect(paragraph.size.height, greaterThan(16));
      expect(
        t.getTopLeft(find.byKey(const Key('next'))).dy,
        greaterThanOrEqualTo(t.getBottomLeft(message).dy),
      );
      expect(t.takeException(), isNull);
    });
  }
}
