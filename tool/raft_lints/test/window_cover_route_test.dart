import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
// ignore: implementation_imports
import 'package:analyzer_testing/src/analysis_rule/pub_package_resolution.dart'
    show ExpectedDiagnostic;
import 'package:raft_lints/src/banned_apis.dart';
import 'package:raft_lints/src/checks.dart';
import 'package:raft_lints/src/ignores.dart';
import 'package:raft_lints/src/rules.dart';
import 'package:test/test.dart' show expect, equals, isEmpty;
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(WindowCoverRouteTest);
    defineReflectiveTests(WindowCoverRouteRunnerTest);
  });
}

mixin _Routes on AnalysisRuleTest {
  void stubs() {
    newPackage('flutter').addFile('lib/widgets.dart', r'''
abstract class Widget { const Widget(); }
class BuildContext {}
typedef WidgetBuilder = Widget Function(BuildContext context);
abstract class Route<T> {}
abstract class PageRoute<T> extends Route<T> {}
class MaterialPageRoute<T> extends PageRoute<T> {
  MaterialPageRoute({required WidgetBuilder builder});
}
class PageRouteBuilder<T> extends PageRoute<T> {
  PageRouteBuilder({required Object pageBuilder});
}
class DialogRoute<T> extends Route<T> {
  DialogRoute({required BuildContext context, required WidgetBuilder builder});
}
Future<T?> showDialog<T>({required BuildContext context, required WidgetBuilder builder}) async => null;
''');
    newPackage('raft_ui').addFile('lib/raft_ui.dart', r'''
import 'package:flutter/widgets.dart';
class RaftFullBleedDialogRoute<T> extends DialogRoute<T> {
  RaftFullBleedDialogRoute({required super.context, required super.builder});
}
''');
  }

  ExpectedDiagnostic at(String code, String snippet) =>
      lint(code.indexOf(snippet), snippet.length);
}

/// The plugin rule: which constructions it flags.
@reflectiveTest
class WindowCoverRouteTest extends AnalysisRuleTest with _Routes {
  @override
  void setUp() {
    rule = BannedApiRule(_api());
    stubs();
    super.setUp();
  }

  Future<void> test_the_three_window_cover_routes_are_flagged() async {
    const code = r'''
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';
void f(BuildContext c, Widget w) {
  MaterialPageRoute<void>(builder: (_) => w);
  PageRouteBuilder<void>(pageBuilder: 0);
  RaftFullBleedDialogRoute<void>(context: c, builder: (_) => w);
}
''';
    await assertDiagnostics(code, [
      at(code, 'MaterialPageRoute<void>(builder: (_) => w)'),
      at(code, 'PageRouteBuilder<void>(pageBuilder: 0)'),
      at(code, 'RaftFullBleedDialogRoute<void>(context: c, builder: (_) => w)'),
    ]);
  }

  Future<void> test_dialogs_and_type_names_are_not_flagged() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';
void f(BuildContext c, Widget w, Route<void> r) {
  DialogRoute<void>(context: c, builder: (_) => w);
  showDialog<void>(context: c, builder: (_) => w);
  if (r is MaterialPageRoute<void> || r is RaftFullBleedDialogRoute<void>) {}
}
''');
  }
}

/// The gate path (`tool/raft-lints`): an ignore silences this rule only when
/// its reason names the Web modal (`web-modal: <web path>:<line>`).
@reflectiveTest
class WindowCoverRouteRunnerTest extends AnalysisRuleTest with _Routes {
  @override
  void setUp() {
    rule = BannedApiRule(_api());
    stubs();
    super.setUp();
  }

  Future<List<String>> run(String code) async {
    newFile(testFilePath, code);
    final ResolvedUnitResult result = await resolveFile(testFilePath);
    final ignores = Ignores.of(result.unit, result.content);
    final found = <String>[];
    result.unit.accept(
      AllChecksVisitor(path: testFilePath, (rule, node) {
        final line = result.lineInfo.getLocation(node.offset).lineNumber;
        if (!isSuppressed(ignores, rule, line)) found.add('$rule:$line');
      }),
    );
    return found;
  }

  Future<void> test_a_web_modal_citation_allows_the_site() async {
    expect(
      await run(r'''
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';
void f(BuildContext c, Widget w) {
  // ignore: raft_lints/avoid_window_cover_route -- web-modal: components/files/FilePreviewLightbox.tsx:42
  RaftFullBleedDialogRoute<void>(context: c, builder: (_) => w);
  MaterialPageRoute<void>(builder: (_) => w); // ignore: raft_lints/avoid_window_cover_route -- web-modal: pages/Login.tsx:7
}
'''),
      isEmpty,
    );
  }

  Future<void> test_a_web_page_citation_or_a_widget_preview_allows_it() async {
    expect(
      await run(r'''
import 'package:flutter/widgets.dart';
void f(Widget w) {
  // ignore: raft_lints/avoid_window_cover_route -- web-page: App.tsx:1564 (Web also leaves the app for this page)
  MaterialPageRoute<void>(builder: (_) => w);
  // ignore: raft_lints/avoid_window_cover_route -- widget-preview: the preview harness's own navigator
  PageRouteBuilder<void>(pageBuilder: (_, _, _) => w);
}
'''),
      isEmpty,
    );
  }

  Future<void> test_a_bare_ignore_or_another_reason_still_reports() async {
    expect(
      await run(r'''
import 'package:flutter/widgets.dart';
void f(Widget w) {
  // ignore: raft_lints/avoid_window_cover_route
  MaterialPageRoute<void>(builder: (_) => w);
  // ignore: raft_lints/avoid_window_cover_route -- covers the window on purpose
  MaterialPageRoute<void>(builder: (_) => w);
  // ignore: raft_lints/avoid_window_cover_route -- web-modal: the Web lightbox
  MaterialPageRoute<void>(builder: (_) => w);
  // ignore: raft_lints/avoid_window_cover_route -- web-modal: Lightbox.tsx
  MaterialPageRoute<void>(builder: (_) => w);
  // ignore: raft_lints/avoid_window_cover_route -- see web-modal: Lightbox.tsx:3
  MaterialPageRoute<void>(builder: (_) => w);
}
'''),
      equals([
        'avoid_window_cover_route:4',
        'avoid_window_cover_route:6',
        'avoid_window_cover_route:8',
        'avoid_window_cover_route:10',
        'avoid_window_cover_route:12',
      ]),
    );
  }

  Future<void> test_a_file_wide_ignore_does_not_allow_a_site() async {
    expect(
      await run(r'''
// ignore_for_file: raft_lints/avoid_window_cover_route -- web-modal: Lightbox.tsx:3
import 'package:flutter/widgets.dart';
void f(Widget w) {
  MaterialPageRoute<void>(builder: (_) => w);
}
'''),
      equals(['avoid_window_cover_route:4']),
    );
  }

  Future<void> test_other_rules_still_accept_any_reason() async {
    expect(
      await run(r'''
import 'dart:async';
void f() {
  // ignore: raft_lints/avoid_unreviewed_idle_work
  Timer.run(() {});
  // ignore: raft_lints/avoid_unreviewed_idle_work -- runs once per tap
  Timer.run(() {});
}
'''),
      isEmpty,
    );
  }
}

BannedApi _api() => bannedApis.firstWhere((a) => a.rule == windowCoverRule);
