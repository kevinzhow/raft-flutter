import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget _host(Widget child) => MaterialApp(
  theme: raftTheme(),
  home: Scaffold(
    body: SingleChildScrollView(
      child: Align(alignment: Alignment.topLeft, child: child),
    ),
  ),
);

void main() {
  testWidgets('unchanged parent updates do not relayout collapsed content', (
    tester,
  ) async {
    late StateSetter update;
    var layouts = 0;
    final collapseKey = GlobalKey();
    await tester.pumpWidget(
      _host(
        _LayoutProbe(
          onLayout: () => layouts++,
          child: StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return RaftCollapsible(
                key: collapseKey,
                child: const SizedBox(
                  height: 700,
                  width: 300,
                  child: Text('Content'),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final before = layouts;
    for (var i = 0; i < 20; i++) {
      update(() {});
      await tester.pump();
    }
    expect(layouts, before);
    expect(find.text('Show More'), findsOneWidget);
    await tester.tap(find.text('Show More'));
    await tester.pumpAndSettle();
    expect(layouts, greaterThan(before));
    expect(find.text('Collapse'), findsOneWidget);
  });

  testWidgets('a retained toggle accepts locale and theme updates', (
    tester,
  ) async {
    Widget frame(Locale locale, bool dark) => MaterialApp(
      theme: raftTheme(dark: dark),
      home: Scaffold(
        body: Builder(
          builder: (context) => Localizations.override(
            context: context,
            locale: locale,
            child: const SingleChildScrollView(
              child: RaftCollapsible(
                child: SizedBox(
                  height: 700,
                  width: 300,
                  child: Text('Content'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(frame(const Locale('en'), false));
    await tester.pumpAndSettle();
    expect(find.text('Show More'), findsOneWidget);
    await tester.pumpWidget(frame(const Locale('zh'), true));
    await tester.pumpAndSettle();
    expect(find.text('Show More'), findsNothing);
    expect(find.text('展开全文'), findsOneWidget);
    await tester.tap(find.text('展开全文'));
    await tester.pumpAndSettle();
    expect(find.text('Collapse'), findsNothing);
    expect(tester.getSize(find.byType(ClipRect).last).height, 700);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'first layout caps the viewport but measures true natural height',
    (tester) async {
      await tester.pumpWidget(
        _host(
          const RaftCollapsible(
            child: SizedBox(
              height: 2400,
              width: 300,
              child: Text('Natural long content'),
            ),
          ),
        ),
      );
      // No second pump: legacy Align allocated2400 before the height receipt.
      expect(tester.getSize(find.byType(ClipRect).last).height, 320);
      final measure = tester.renderObject<RenderProxyBox>(
        find.byType(RaftContentMeasure),
      );
      expect(measure.child!.size.height, 2400);
      await tester.pumpAndSettle();
      expect(find.text('Show More'), findsOneWidget);
      await tester.tap(find.text('Show More'));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(ClipRect).last).height, 2400);
      await tester.ensureVisible(find.text('Collapse'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Collapse'));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(ClipRect).last).height, 320);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('short and disabled content retain natural first-layout size', (
    tester,
  ) async {
    for (final (height, enabled, expected) in [
      (70.0, true, 70.0),
      (321.0, true, 320.0),
      (700.0, false, 700.0),
    ]) {
      await tester.pumpWidget(
        _host(
          RaftCollapsible(
            key: ValueKey('$height-$enabled'),
            enabled: enabled,
            child: SizedBox(height: height, width: 300),
          ),
        ),
      );
      expect(tester.getSize(find.byType(ClipRect).last).height, expected);
      await tester.pumpAndSettle();
      expect(
        find.text('Show More'),
        enabled && height > 320 ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'natural measurement supports width reflow and runtime preference changes',
    (tester) async {
      Widget frame(double width, bool enabled) => _host(
        SizedBox(
          width: width,
          child: RaftCollapsible(
            key: const Key('reflow'),
            enabled: enabled,
            child: LayoutBuilder(
              builder: (_, bounds) => SizedBox(
                height: bounds.maxWidth < 300 ? 900 : 700,
                width: bounds.maxWidth,
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(frame(340, true));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(ClipRect).last).height, 320);
      await tester.pumpWidget(frame(280, false));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(ClipRect).last).height, 900);
      await tester.pumpWidget(frame(280, true));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(ClipRect).last).height, 320);
      expect(find.text('Show More'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('queued natural size cannot leak into a replacement callback', (
    tester,
  ) async {
    final key = GlobalKey();
    final oldReceipts = <Size>[], newReceipts = <Size>[];
    // Register before layout so this callback precedes the measured receipt.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final element = key.currentContext! as RenderObjectElement;
      element.update(
        RaftContentMeasure(
          key: key,
          onSize: newReceipts.add,
          maxHeight: 320,
          child: const SizedBox(height: 70, width: 300),
        ),
      );
    });
    await tester.pumpWidget(
      _host(
        RaftContentMeasure(
          key: key,
          onSize: oldReceipts.add,
          maxHeight: 320,
          child: const SizedBox(height: 700, width: 300),
        ),
      ),
    );
    expect(oldReceipts, isEmpty);
    await tester.pumpAndSettle();
    expect(newReceipts, [const Size(300, 70)]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'clipped pointer stays inaccessible while hidden keyboard focus reveals content',
    (tester) async {
      final visible = FocusNode(), hidden = FocusNode();
      var hiddenCalls = 0;
      await tester.pumpWidget(
        _host(
          RaftCollapsible(
            child: Column(
              children: [
                TextButton(
                  focusNode: visible,
                  onPressed: () {},
                  child: const Text('Visible control'),
                ),
                const SizedBox(height: 400),
                TextButton(
                  focusNode: hidden,
                  onPressed: () => hiddenCalls++,
                  child: const Text('Hidden control'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hidden control').hitTestable(), findsNothing);
      visible.requestFocus();
      await tester.pumpAndSettle();
      expect(find.text('Show More'), findsOneWidget);
      hidden.requestFocus();
      await tester.pumpAndSettle();
      expect(find.text('Collapse'), findsOneWidget);
      expect(find.text('Hidden control').hitTestable(), findsOneWidget);
      expect(hiddenCalls, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      visible.dispose();
      hidden.dispose();
    },
  );
  testWidgets('A-B-A before a receipt cannot starve a later B layout', (
    tester,
  ) async {
    final receipts = <Size>[];
    await tester.pumpWidget(
      _host(
        RaftContentMeasure(
          onSize: receipts.add,
          maxHeight: 320,
          child: const SizedBox(width: 300, height: 70),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(receipts, [const Size(300, 70)]);
    final measure = tester.renderObject<RenderProxyBox>(
      find.byType(RaftContentMeasure),
    );
    final child = measure.child! as RenderConstrainedBox;
    void layout(double height) {
      child.additionalConstraints = BoxConstraints.tightFor(
        width: 300,
        height: height,
      );
      measure.layout(measure.constraints, parentUsesSize: true);
    }

    layout(700); // B is pending, not delivered.
    layout(70); // A was delivered; B must still be invalidated.
    await tester.pump();
    expect(receipts, [const Size(300, 70)]);
    layout(700); // New B must enqueue rather than match stale pending state.
    await tester.pump();
    expect(receipts, [const Size(300, 70), const Size(300, 700)]);
    expect(tester.getSize(find.byType(RaftContentMeasure)).height, 320);
    expect(tester.takeException(), isNull);
  });
}

class _LayoutProbe extends SingleChildRenderObjectWidget {
  const _LayoutProbe({required this.onLayout, required super.child});
  final VoidCallback onLayout;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLayoutProbe(onLayout);
}

class _RenderLayoutProbe extends RenderProxyBox {
  _RenderLayoutProbe(this.onLayout);
  final VoidCallback onLayout;
  @override
  void performLayout() {
    onLayout();
    super.performLayout();
  }
}
