import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final dark in [false, true]) {
    for (final width in [130.71428571428572, 99.42857142857143]) {
      testWidgets('leading-only button respects $width constraints/$dark', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 2.625;
        tester.view.physicalSize = const Size(2142, 2362.5);
        addTearDown(tester.view.reset);
        addTearDown(() => tester.pumpWidget(const SizedBox()));
        var presses = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: RaftButton(
                    key: const Key('workspace-button'),
                    label: '',
                    semanticLabel: 'Workspace with a long name',
                    leading: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RaftIcon(RaftGlyph.home, size: 19),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Workspace with a long name',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    gap: 0,
                    uiVariant: RaftButtonVariant.onFrame,
                    onPressed: () => presses++,
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byKey(const Key('workspace-button'))).width,
          lessThanOrEqualTo(width),
        );
        await tester.tap(find.byKey(const Key('workspace-button')));
        expect(presses, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
