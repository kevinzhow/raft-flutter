import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget _link({RaftTypeStyle? scale}) => MaterialApp(
  theme: raftTheme(),
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: RaftTextLink(
        label: 'Learn more',
        variant: RaftTextLinkVariant.strong,
        scale: scale,
        onPressed: () {},
      ),
    ),
  ),
);

double _size(WidgetTester t) {
  final text = t.widget<Text>(
    find.descendant(
      of: find.byType(RaftTextLink),
      matching: find.text('Learn more'),
    ),
  );
  return text.style?.fontSize ?? text.textSpan!.style!.fontSize!;
}

void main() {
  testWidgets('without scale the strong link stays body-sized', (t) async {
    await t.pumpWidget(_link());
    expect(_size(t), RaftTypeScale.body.fontSize);
  });

  testWidgets('a caption scale makes it caption-sized and still semibold', (
    t,
  ) async {
    await t.pumpWidget(_link(scale: RaftTypeScale.caption));
    expect(_size(t), RaftTypeScale.caption.fontSize);
    final text = t.widget<Text>(
      find.descendant(
        of: find.byType(RaftTextLink),
        matching: find.text('Learn more'),
      ),
    );
    final weight = text.style?.fontWeight ?? text.textSpan?.style?.fontWeight;
    expect(weight, FontWeight.w600);
  });
}
