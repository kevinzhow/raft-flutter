// Mounts RaftBench widgets for the widget tests: the themed MaterialApp at a
// chosen width and locale, and a settled pump.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

const raftbenchPhone = Size(390, 844);
const raftbenchDesktop = Size(1280, 900);

Future<void> mountRaftbench(
  WidgetTester t,
  Widget child, {
  Size size = raftbenchDesktop,
  Locale locale = const Locale('en'),
  RaftFamily family = RaftFamily.elegant,
  bool dark = false,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: raftTheme(family, dark: dark),
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(
        body: SizedBox(width: size.width, height: size.height, child: child),
      ),
    ),
  );
  await settle(t);
}

/// Real async work (the scripted API) and a few frames for the layout.
Future<void> settle(WidgetTester t) async {
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
}

/// Unmount so periodic polls and controllers are disposed before the test ends.
Future<void> unmount(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump();
}
