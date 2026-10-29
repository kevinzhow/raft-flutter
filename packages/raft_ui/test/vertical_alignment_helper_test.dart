import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/testing/vertical_alignment.dart';

void main() {
  Widget row(CrossAxisAlignment alignment) => Directionality(
    textDirection: TextDirection.ltr,
    child: Row(
      crossAxisAlignment: alignment,
      children: const [
        SizedBox(key: ValueKey('a'), width: 20, height: 40),
        SizedBox(key: ValueKey('b'), width: 20, height: 16),
      ],
    ),
  );

  testWidgets('centred children pass', (tester) async {
    await tester.pumpWidget(row(CrossAxisAlignment.center));
    expectVerticallyCentered(tester, [
      find.byKey(const ValueKey('a')),
      find.byKey(const ValueKey('b')),
    ]);
  });

  testWidgets('top-aligned children of different heights fail', (tester) async {
    await tester.pumpWidget(row(CrossAxisAlignment.start));
    expect(
      () => expectVerticallyCentered(tester, [
        find.byKey(const ValueKey('a')),
        find.byKey(const ValueKey('b')),
      ]),
      throwsA(isA<TestFailure>()),
    );
  });

  testWidgets('a half pixel is tolerated, a pixel is not', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: const [
            Positioned(
              top: 0,
              child: SizedBox(key: ValueKey('a'), width: 10, height: 20),
            ),
            Positioned(
              top: 0.5,
              child: SizedBox(key: ValueKey('b'), width: 10, height: 20),
            ),
            Positioned(
              top: 1.5,
              child: SizedBox(key: ValueKey('c'), width: 10, height: 20),
            ),
          ],
        ),
      ),
    );
    expectVerticallyCentered(tester, [
      find.byKey(const ValueKey('a')),
      find.byKey(const ValueKey('b')),
    ]);
    expect(
      () => expectVerticallyCentered(tester, [
        find.byKey(const ValueKey('a')),
        find.byKey(const ValueKey('c')),
      ]),
      throwsA(isA<TestFailure>()),
    );
  });
}
