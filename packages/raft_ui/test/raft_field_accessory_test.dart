import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final dark in [false, true]) {
    for (final scale in [1.0, 3.1]) {
      for (final direction in TextDirection.values) {
        testWidgets(
          'reserved field keeps its accessory at the trailing edge, dark=$dark scale=$scale direction=$direction',
          (tester) async {
            var taps = 0;
            final label = scale == 1
                ? 'Name'
                : 'A long field label that can wrap at large text sizes';
            await tester.pumpWidget(
              MaterialApp(
                theme: raftTheme(dark: dark),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: Directionality(
                    textDirection: direction,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: 408,
                        child: RaftStableField(
                          label: label,
                          labelAccessory: RaftRecipeButton(
                            key: const Key('accessory'),
                            glyph: RaftGlyph.dices,
                            glyphSize: 12,
                            size: RaftButtonRecipeSize.iconSm,
                            variant: RaftButtonRecipeVariant.ghost,
                            onPressed: () => taps++,
                          ),
                          child: const SizedBox(
                            key: Key('control'),
                            height: 44,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            final field = find.byType(RaftStableField);
            final accessory = find.byKey(const Key('accessory'));
            final control = find.byKey(const Key('control'));
            final labelFinder = find.byWidgetPredicate(
              (widget) =>
                  widget is Text && widget.textSpan?.toPlainText() == label,
            );
            expect(tester.getSize(accessory), const Size(32, 32));
            if (direction == TextDirection.ltr) {
              expect(
                tester.getTopRight(accessory).dx,
                tester.getTopRight(field).dx,
              );
              expect(
                tester.getRect(labelFinder).right,
                lessThanOrEqualTo(tester.getRect(accessory).left),
              );
            } else {
              expect(
                tester.getTopLeft(accessory).dx,
                tester.getTopLeft(field).dx,
              );
              expect(
                tester.getRect(labelFinder).left,
                greaterThanOrEqualTo(tester.getRect(accessory).right),
              );
            }
            if (scale == 1) {
              expect(
                tester.getTopLeft(control).dy - tester.getTopLeft(field).dy,
                24,
              );
            } else {
              expect(
                tester.getTopLeft(control).dy,
                greaterThanOrEqualTo(tester.getBottomLeft(labelFinder).dy),
              );
            }
            final accessoryRect = tester.getRect(accessory);
            await tester.tapAt(
              Offset(
                direction == TextDirection.ltr
                    ? accessoryRect.right - 1
                    : accessoryRect.left + 1,
                accessoryRect.center.dy,
              ),
            );
            await tester.pump();
            expect(taps, 1);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
