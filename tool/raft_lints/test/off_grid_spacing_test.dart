import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:raft_lints/src/checks.dart';
import 'package:raft_lints/src/ignores.dart';
import 'package:raft_lints/src/off_grid_spacing.dart';
import 'package:raft_lints/src/rules.dart';
import 'package:test/test.dart' show expect, isEmpty, equals;
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(OffGridSpacingTest);
    defineReflectiveTests(OffGridSpacingRunnerTest);
  });
}

const _widgets = r'''
abstract class Widget { const Widget(); }
class EdgeInsets {
  const EdgeInsets.all(double value);
  const EdgeInsets.symmetric({double horizontal = 0, double vertical = 0});
  const EdgeInsets.only({double left = 0, double top = 0, double right = 0, double bottom = 0});
  const EdgeInsets.fromLTRB(double l, double t, double r, double b);
  static const EdgeInsets zero = EdgeInsets.all(0);
}
class EdgeInsetsDirectional {
  const EdgeInsetsDirectional.only({double start = 0, double top = 0, double end = 0, double bottom = 0});
  const EdgeInsetsDirectional.fromSTEB(double s, double t, double e, double b);
}
class SizedBox extends Widget {
  const SizedBox({double? width, double? height, Widget? child});
  const SizedBox.square({double? dimension, Widget? child});
}
class Padding extends Widget {
  const Padding({required EdgeInsets padding, Widget? child});
}
class Row extends Widget {
  const Row({double spacing = 0, List<Widget> children = const []});
}
class Wrap extends Widget {
  const Wrap({double spacing = 0, double runSpacing = 0, List<Widget> children = const []});
}
class Gap extends Widget {
  const Gap({double? gap, double? width});
}
const double unit = 5;
''';

mixin _Flutter on AnalysisRuleTest {
  void stubs() {
    newPackage('flutter').addFile('lib/widgets.dart', _widgets);
  }
}

@reflectiveTest
class OffGridSpacingTest extends AnalysisRuleTest with _Flutter {
  @override
  void setUp() {
    rule = OffGridSpacing();
    stubs();
    super.setUp();
  }

  Future<void> test_edge_insets_constructors() async {
    const code = r'''
import 'package:flutter/widgets.dart';
void f() {
  EdgeInsets.all(7);
  EdgeInsets.symmetric(horizontal: 3, vertical: 4);
  EdgeInsets.only(left: 1, top: 9.5, right: 4);
  EdgeInsets.fromLTRB(10, 15, 10, 8);
  EdgeInsetsDirectional.only(start: 5, end: 2);
  EdgeInsetsDirectional.fromSTEB(2, 3, 2, 4);
}
''';
    await assertDiagnostics(code, [
      lint(code.indexOf('7)'), 1),
      lint(code.indexOf('3,'), 1),
      lint(code.indexOf('1,'), 1),
      lint(code.indexOf('9.5'), 3),
      lint(code.indexOf('15'), 2),
      lint(code.indexOf('5, end'), 1),
      lint(code.indexOf('3, 2'), 1),
    ]);
  }

  Future<void> test_spacer_size_boxes_and_gap_arguments() async {
    const code = r'''
import 'package:flutter/widgets.dart';
void f() {
  SizedBox(width: 3);
  SizedBox(height: 5.5);
  Row(spacing: 7);
  Wrap(spacing: 5, runSpacing: 3);
  Gap(gap: 9);
}
''';
    await assertDiagnostics(code, [
      lint(code.indexOf('3);'), 1),
      lint(code.indexOf('5.5'), 3),
      lint(code.indexOf('7)'), 1),
      lint(code.indexOf('5, runSpacing'), 1),
      lint(code.indexOf('runSpacing: 3') + 12, 1),
      lint(code.indexOf('9)'), 1),
    ]);
  }

  Future<void> test_both_branches_of_a_conditional_are_checked() async {
    const code = r'''
import 'package:flutter/widgets.dart';
void f(bool b) {
  EdgeInsets.all(b ? 2 : 1);
  SizedBox(height: b ? 7 : 10);
}
''';
    await assertDiagnostics(code, [
      lint(code.indexOf('1)'), 1),
      lint(code.indexOf('7 :'), 1),
    ]);
  }

  Future<void> test_grid_values_zero_and_tokens_pass() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
void f(double d) {
  EdgeInsets.all(0);
  EdgeInsets.all(8.0);
  EdgeInsets.all(2);
  EdgeInsets.symmetric(horizontal: 6, vertical: 10);
  EdgeInsets.only(left: 14, top: 28, right: 32, bottom: 0.0);
  EdgeInsets.fromLTRB(2, 4, 6, 8);
  EdgeInsets.zero;
  EdgeInsets.all(d);
  EdgeInsets.all(unit);
  EdgeInsets.all(8.0 + (d > 1 ? 2 : 1));
  EdgeInsets.only(top: 1.5 * 8);
  SizedBox(width: 12, height: 0);
  Row(spacing: 4);
  Wrap(spacing: 8, runSpacing: 12);
}
''');
  }

  Future<void> test_a_sized_box_with_a_child_is_a_size_not_a_gap() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
void f() {
  SizedBox(width: 15, height: 21, child: SizedBox());
  SizedBox.square(dimension: 15);
}
''');
  }

  Future<void> test_other_named_arguments_are_not_spacing() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
void f() {
  Gap(width: 5);
}
''');
  }
}

@reflectiveTest
class OffGridSpacingRunnerTest extends AnalysisRuleTest with _Flutter {
  @override
  String get analysisRule => offGridSpacingRule;

  @override
  void setUp() {
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
        if (!ignores.isIgnored(rule, line)) found.add('$rule:$line');
      }),
    );
    return found;
  }

  Future<void> test_a_web_citation_on_the_line_above_or_same_line() async {
    expect(
      await run(r'''
import 'package:flutter/widgets.dart';
void f() {
  // ds-allow: Web panel-header.tsx py-[9.5px]
  EdgeInsets.symmetric(vertical: 9.5);
  EdgeInsets.all(1); // ds-allow: Web inline-code.tsx border 1px compensation
  SizedBox(height: 5.5); // ds-allow: Web logo.tsx w-[5.5px]
}
'''),
      isEmpty,
    );
  }

  Future<void> test_a_citation_above_the_call_covers_a_multiline_call() async {
    expect(
      await run(r'''
import 'package:flutter/widgets.dart';
Widget f() {
  return Padding(
    // ds-allow: Web composer.tsx px-[7px] py-[3px]
    padding: EdgeInsets.symmetric(
      horizontal: 7,
      vertical: 3,
    ),
  );
}
'''),
      isEmpty,
    );
  }

  Future<void> test_a_citation_has_to_name_a_web_file_and_class() async {
    expect(
      await run(r'''
import 'package:flutter/widgets.dart';
void f() {
  // ds-allow: because I said so
  EdgeInsets.all(7);
  // ds-allow: Web
  EdgeInsets.all(7);
  // ds-allow: Web foo.tsx
  EdgeInsets.all(7);
  // some ordinary comment: Web foo.tsx p-[7px]
  EdgeInsets.all(7);
}
'''),
      equals([
        '$offGridSpacingRule:4',
        '$offGridSpacingRule:6',
        '$offGridSpacingRule:8',
        '$offGridSpacingRule:10',
      ]),
    );
  }

  Future<void> test_a_citation_covers_only_its_own_call() async {
    expect(
      await run(r'''
import 'package:flutter/widgets.dart';
void f() {
  // ds-allow: Web foo.tsx p-[7px]
  EdgeInsets.all(7);
  EdgeInsets.all(7);
}
'''),
      equals(['$offGridSpacingRule:5']),
    );
  }

  Future<void> test_an_ignore_comment_still_works() async {
    expect(
      await run(r'''
import 'package:flutter/widgets.dart';
void f() {
  // ignore: raft_lints/off_grid_spacing -- reviewed
  EdgeInsets.all(7);
}
'''),
      isEmpty,
    );
  }
}
