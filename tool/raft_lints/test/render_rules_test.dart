import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
// ignore: implementation_imports
import 'package:analyzer_testing/src/analysis_rule/pub_package_resolution.dart'
    show ExpectedDiagnostic;
import 'package:raft_lints/src/checks.dart';
import 'package:raft_lints/src/rules.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(IndexAssertionTest);
    defineReflectiveTests(SingleTest);
    defineReflectiveTests(WhereTest);
  });
}

/// A stand-in for package:flutter, enough for the rules to recognise widgets.
const _flutterStub = r'''
class BuildContext {}
abstract class Widget { const Widget(); }
abstract class PreferredSizeWidget implements Widget {}
class Text extends Widget { const Text(String data); }
class Builder extends Widget {
  const Builder({required Widget Function(BuildContext) builder});
}
class ListView extends Widget {
  const ListView.builder({required Widget Function(BuildContext, int) itemBuilder});
}
class Wrapper extends Widget {
  const Wrapper({Object? onTap, Object? child});
}
''';

mixin _FlutterStub on AnalysisRuleTest {
  void stubFlutter() {
    newPackage('flutter').addFile('lib/widgets.dart', _flutterStub);
  }

  /// The analyzer's mock SDK is minimal; add the members the rules look for.
  void patchMockSdk() {
    final core = getFile('${sdkRoot.path}/lib/core/core.dart');
    core.writeAsStringSync(
      core
          .readAsStringSync()
          .replaceFirst('E get first;', 'E get first;\n  E get single;')
          .replaceFirst(
            'abstract interface class Match {',
            'abstract interface class Match {\n  String? operator [](int group);',
          ),
    );
  }

  /// A lint on the first occurrence of [snippet] in [code].
  ExpectedDiagnostic at(String code, String snippet, {int? length}) =>
      lint(code.indexOf(snippet), length ?? snippet.length);
}

@reflectiveTest
class IndexAssertionTest extends AnalysisRuleTest with _FlutterStub {
  @override
  String get analysisRule => indexAssertionRule;

  @override
  void setUp() {
    rule = AvoidRenderIndexAssertion();
    stubFlutter();
    super.setUp();
    patchMockSdk();
  }

  // The 2026-10 crash: a form controller published its definition before its
  // text editors existed, and a rebuild in between ran `c.editors[f.key]!`.
  Future<void> test_editors_by_field_key_in_widget_method() async {
    const code = r'''
import 'package:flutter/widgets.dart';
class Field { final String key = 'k'; }
class Controller { final Map<String, Object> editors = {}; }
class State1 {
  final c = Controller();
  Widget field(Field f) {
    return Wrapper(child: c.editors[f.key]!);
  }
}
''';
    await assertDiagnostics(code, [at(code, 'c.editors[f.key]!')]);
  }

  Future<void> test_builder_closure() async {
    const code = r'''
import 'package:flutter/widgets.dart';
Widget build(Map<int, String> names) => ListView.builder(
  itemBuilder: (context, i) => Text(names[i]!),
);
''';
    await assertDiagnostics(code, [at(code, 'names[i]!')]);
  }

  Future<void> test_builder_closure_that_does_not_return_a_widget() async {
    const code = r'''
class Pager {
  const Pager({required Object Function(int) itemBuilder});
}
void f(Map<int, String> names) {
  Pager(itemBuilder: (i) => names[i]!);
}
''';
    await assertDiagnostics(code, [at(code, 'names[i]!')]);
  }

  Future<void> test_event_handler_nested_in_widget_function() async {
    const code = r'''
import 'package:flutter/widgets.dart';
Widget row(Map<String, int> ids) {
  return Wrapper(onTap: () => ids['a']!);
}
''';
    await assertDiagnostics(code, [at(code, "ids['a']!")]);
  }

  Future<void> test_getter_and_list_of_widgets_and_nullable_widget() async {
    const code = r'''
import 'package:flutter/widgets.dart';
Map<String, Text> m = {};
Widget get a => m['a']!;
List<Widget> b() => [m['b']!];
Widget? c() => m['c']!;
PreferredSizeWidget? d(Map<String, PreferredSizeWidget> p) => p['d']!;
''';
    await assertDiagnostics(code, [
      at(code, "m['a']!"),
      at(code, "m['b']!"),
      at(code, "m['c']!"),
      at(code, "p['d']!"),
    ]);
  }

  Future<void> test_parenthesised() async {
    const code = r'''
import 'package:flutter/widgets.dart';
Widget a(Map<String, Text> m) => (m['a'])!;
''';
    await assertDiagnostics(code, [at(code, "(m['a'])!")]);
  }

  Future<void> test_not_render_code() async {
    await assertNoDiagnostics(r'''
void load(Map<String, int> m) { final a = m['k']!; }
int sort(Map<String, int> order, String a, String b) =>
    order[a]!.compareTo(order[b]!);
''');
  }

  Future<void> test_stops_at_the_end_of_the_widget_function() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
Widget a() => const Text('a');
final b = <String, int>{}['k']!;
Widget c() => const Text('c');
''');
  }

  Future<void> test_integer_literal_index_is_exempt() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
Widget a(Match match, List<String?> tuple) =>
    Text(match[1]! + (tuple[0])!);
''');
  }

  Future<void> test_theme_token_map_is_exempt() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
class RaftTokens { final Map<String, int> colors = {}; }
Widget a(RaftTokens t) => Wrapper(child: t.colors['accent']! + t.colors[t.hashCode > 1 ? 'a' : 'b']!);
''');
  }

  Future<void> test_other_color_maps_are_not_exempt() async {
    const code = r'''
import 'package:flutter/widgets.dart';
class Palette { final Map<String, int> colors = {}; }
Widget a(Palette p) => Wrapper(child: p.colors['accent']!);
''';
    await assertDiagnostics(code, [at(code, "p.colors['accent']!")]);
  }

  Future<void> test_non_index_assertions_are_not_this_rule() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
Widget a(Text? t) => t!;
''');
  }

  Future<void> test_strings_and_comments_are_not_code() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
Widget a() {
  // m['k']! in a comment
  return const Text("not code m['k']!");
}
''');
  }
}

@reflectiveTest
class SingleTest extends AnalysisRuleTest with _FlutterStub {
  @override
  String get analysisRule => singleRule;

  @override
  void setUp() {
    rule = AvoidRenderSingle();
    stubFlutter();
    super.setUp();
    patchMockSdk();
  }

  Future<void> test_single_in_widget_function() async {
    const code = r'''
import 'package:flutter/widgets.dart';
Widget a(List<Text> items) => items.single;
Widget b(Iterable<Text> items) => (items.where((t) => true)).single;
''';
    await assertDiagnostics(code, [
      lint(code.indexOf('single;'), 6),
      lint(code.lastIndexOf('single;'), 6),
    ]);
  }

  Future<void> test_single_in_builder() async {
    const code = r'''
import 'package:flutter/widgets.dart';
Widget a(List<String> items) =>
    Builder(builder: (c) => Text(items.single));
''';
    await assertDiagnostics(code, [lint(code.indexOf('single'), 6)]);
  }

  Future<void> test_outside_render_code() async {
    await assertNoDiagnostics(r'''
String a(List<String> items) => items.single;
''');
  }

  Future<void> test_user_defined_single_is_not_the_sdk_getter() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
class Box { Text get single => const Text('x'); }
Widget a(Box b) => b.single;
''');
  }
}

@reflectiveTest
class WhereTest extends AnalysisRuleTest with _FlutterStub {
  @override
  String get analysisRule => whereRule;

  @override
  void setUp() {
    rule = AvoidRenderWhereWithoutOrElse();
    stubFlutter();
    super.setUp();
    patchMockSdk();
  }

  Future<void> test_where_without_or_else() async {
    const code = r'''
import 'package:flutter/widgets.dart';
Widget a(List<Text> items) => items.firstWhere((i) => true);
Widget b(List<Text> items) => items.lastWhere((i) => true);
Widget c(List<Text> items) => items.singleWhere((i) => true);
''';
    await assertDiagnostics(code, [
      lint(code.indexOf('firstWhere'), 'firstWhere'.length),
      lint(code.indexOf('lastWhere'), 'lastWhere'.length),
      lint(code.indexOf('singleWhere'), 'singleWhere'.length),
    ]);
  }

  Future<void> test_with_or_else() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
Widget a(List<Text> items, Text d) =>
    items.firstWhere((i) => true, orElse: () => d);
Widget b(List<Text> items, Text d) =>
    items.singleWhere((i) => true, orElse: () => d);
''');
  }

  Future<void> test_outside_render_code() async {
    await assertNoDiagnostics(r'''
int a(List<int> items) => items.firstWhere((i) => i > 1);
''');
  }

  Future<void> test_user_defined_first_where_is_not_the_sdk_method() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
class Finder { Text firstWhere(bool Function(Text) test) => const Text('x'); }
Widget a(Finder f) => f.firstWhere((t) => true);
''');
  }
}
