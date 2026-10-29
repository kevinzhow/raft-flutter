import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ContainerLayer root;
  setUp(() {
    // Registered before testWidgets registers binding.postTest, so this
    // assertion runs after the binding's cleanup. An ignore-list entry cannot
    // make an undisposed root pass this assertion.
    addTearDown(() => expect(root.debugDisposed, isTrue));
  });

  testWidgets('a pixel ratio round trip releases the test-owned root layer', (
    tester,
  ) async {
    final platformRatio = tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = platformRatio + 1;
    await tester.pumpWidget(const SizedBox());
    tester.view.devicePixelRatio = platformRatio;
    await tester.pump();
    root = tester.binding.renderViews.single.debugLayer!;
    expect(root.debugDisposed, isFalse);
    // This root was created by this test, even though it uses the platform's
    // default ratio. The binding outlives the test: its cleanup must replace
    // the root so leak tracking can verify disposal rather than ignore it.
  });
}
