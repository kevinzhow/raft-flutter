import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/message_content_tokens.dart';
import 'package:raft_ui/src/rich_card_tokens.dart';

Map<String, dynamic> publicSnapshot() => {
  'kind': 'forwarded-bundle', 'version': 1,
  'forwardedItems': [
    for (var i = 0; i < 3; i++) {
      'index': i, 'contentSnapshot': i == 0 ? List.generate(12, (line) => 'Public line $line').join('\n') : 'Public message $i',
      'sourceAuthorSnapshot': {'type': 'user', 'uniqueName': 'Author$i'},
      'sourceTargetSnapshot': {'type': 'channel', 'label': '#design', 'labelVisibility': 'public'},
      'provenanceState': 'available', 'attachmentPolicy': 'excluded',
    },
  ],
};

void main() {
  for (final (family, dark) in [(RaftFamily.brutal, false), (RaftFamily.elegant, false), (RaftFamily.elegant, true)]) {
    testWidgets('action fills review surface; success badge and committed identity keep source roles $family/$dark', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: raftTheme(family, dark: dark), home: const Scaffold(body: SizedBox(width: 640, child: RaftActionCard(title: 'Create public channel #design', state: 'executed', completedBy: 'Alice', details: [(label: 'Description', value: 'Review first')])))));
      expect(tester.getSize(find.byType(RaftActionCard)).width, 640);
      final badge = find.byKey(const ValueKey('action-success-badge'));
      expect(tester.getTopRight(badge).dx, closeTo(626, .1));
      final container = tester.widget<Container>(badge);
      final context = tester.element(find.byType(RaftActionCard));
      final recipe = ActionSnapshotRecipe(RaftTokens.of(context));
      expect((container.decoration! as BoxDecoration).color, recipe.semantic.success);
      expect(tester.getSize(badge).height, family == RaftFamily.brutal ? 20 : 18);
      expect(find.text('Committed by Alice'), findsOneWidget);
      final committed = tester.widget<Text>(find.text('Committed by Alice'));
      final spans = (committed.textSpan! as TextSpan).children!.cast<TextSpan>();
      expect(spans.singleWhere((s) => s.text == 'Alice').style!.fontWeight, FontWeight.w700);
      expect(find.text('Description: Review first'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('forwarded source is right aligned; real expansion retains projected content $family/$dark', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: raftTheme(family, dark: dark), home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 640, child: RaftForwardedBundle(metadata: publicSnapshot()))))));
      await tester.pumpAndSettle();
      expect(tester.getTopRight(find.text('from #design')).dx, greaterThan(500));
      expect(tester.getTopLeft(find.text('Forwarded')).dx, lessThan(40));
      final context = tester.element(find.byType(RaftForwardedBundle));
      final recipe = ForwardedSnapshotRecipe(RaftTokens.of(context));
      expect(recipe.radius, family == RaftFamily.brutal ? BorderRadius.zero : BorderRadius.circular(8));
      expect(recipe.headerDecoration.border != null, family == RaftFamily.brutal);
      expect(find.text('Public message 2', findRichText: true).hitTestable(), findsNothing);
      await tester.tap(find.text('View all 3 messages'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Public message 2', findRichText: true));
      expect(find.text('Public message 2', findRichText: true).hitTestable(), findsOneWidget);
      expect(find.text('Collapse'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('footer hover and keyboard activation use source roles $family/$dark', (tester) async {
      var presses = 0;
      await tester.pumpWidget(MaterialApp(theme: raftTheme(family, dark: dark), home: Scaffold(body: RaftDensityScope(density: RaftDensity.desktop, child: RaftShowMoreToggle(label: 'Show more', onPressed: () => presses++)))));
      final context = tester.element(find.byType(RaftShowMoreToggle));
      final semantic = MessageContentSemantic(RaftTokens.of(context));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(700, 500));
      await mouse.moveTo(tester.getCenter(find.text('Show more')));
      await tester.pump();
      expect(tester.widget<Text>(find.text('Show more')).style!.color, semantic.toggleHover);
      await mouse.removePointer();
      await tester.pump();
      expect(tester.widget<Text>(find.text('Show more')).style!.color, semantic.toggle);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(presses, 1);
      expect(tester.takeException(), isNull);
    });
    testWidgets('prose inherits strong role and heading margin does not double adjacent gap $family/$dark', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: raftTheme(family, dark: dark), home: const Scaffold(body: RaftMessageBody(content: '# Heading\n\nParagraph\n\n## Subheading\n\nMore'))));
      final context = tester.element(find.byType(RaftMessageBody));
      final recipe = MessageContentRecipe(RaftTokens.of(context));
      expect(recipe.body.color, RaftTokens.of(context).strong);
      expect(recipe.heading(1).color, RaftTokens.of(context).strong);
      final heading = tester.getRect(find.text('Heading', findRichText: true));
      final paragraph = tester.getRect(find.text('Paragraph', findRichText: true));
      final subheading = tester.getRect(find.text('Subheading', findRichText: true));
      expect(heading.top, closeTo(12, .1));
      expect(paragraph.top - heading.bottom, closeTo(4, .1));
      expect(subheading.top - paragraph.bottom, closeTo(8, .1));
      expect(tester.takeException(), isNull);
    });
  }
  for (final (width, density, expectedHeight) in [(320.0, RaftDensity.desktop, 16.0), (1200.0, RaftDensity.touch, 48.0)]) {
    testWidgets('toggle density follows input contract at width $width/$density', (tester) async {
      var pressed = false;
      await tester.pumpWidget(MaterialApp(theme: raftTheme(RaftFamily.elegant), home: Scaffold(body: SizedBox(width: width, child: RaftDensityScope(density: density, child: RaftShowMoreToggle(label: 'Show more', onPressed: () => pressed = true))))));
      expect(tester.getSize(find.byType(RaftShowMoreToggle)).height, expectedHeight);
      await tester.tap(find.text('Show more'));
      expect(pressed, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
