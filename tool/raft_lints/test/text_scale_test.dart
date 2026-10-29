import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:raft_lints/src/checks.dart';
import 'package:raft_lints/src/ignores.dart';
import 'package:raft_lints/src/text_scale.dart';
import 'package:raft_lints/src/rules.dart';
import 'package:test/test.dart' show expect, isEmpty, isFalse;
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(TextScaleFactorTest);
    defineReflectiveTests(FixedHeightTextTest);
    defineReflectiveTests(PixelTextHeightTest);
    defineReflectiveTests(RunnerSuppressionTest);
  });
}

const _widgets = r'''
abstract class Widget { const Widget(); }
class BuildContext {}
class Size { const Size(this.width, this.height); final double width; final double height; }
abstract class TextScaler {
  const TextScaler();
  double scale(double fontSize);
  double get textScaleFactor;
}
class MediaQueryData {
  const MediaQueryData();
  TextScaler get textScaler => throw 0;
  double get textScaleFactor => 1;
}
class MediaQuery extends Widget {
  const MediaQuery();
  static MediaQueryData of(BuildContext c) => throw 0;
  static TextScaler textScalerOf(BuildContext c) => throw 0;
  static double textScaleFactorOf(BuildContext c) => 1;
  static double? maybeTextScaleFactorOf(BuildContext c) => 1;
}
class TextStyle {
  const TextStyle({double? fontSize, double? height});
  TextStyle copyWith({double? fontSize, double? height}) => this;
}
class Text extends Widget {
  const Text(String data, {TextStyle? style, double? textScaleFactor, TextScaler? textScaler, int? maxLines});
  const Text.rich(Object span, {double? textScaleFactor});
}
class SelectableText extends Widget { const SelectableText(String data); }
class TextField extends Widget { const TextField(); }
class Icon extends Widget { const Icon(int icon); }
class Center extends Widget { const Center({Widget? child}); }
class SizedBox extends Widget {
  const SizedBox({double? width, double? height, Widget? child});
  const SizedBox.square({double? dimension, Widget? child});
}
class BoxConstraints {
  const BoxConstraints({double minHeight = 0, double maxHeight = double.infinity});
  const BoxConstraints.tightFor({double? width, double? height});
  const BoxConstraints.expand({double? width, double? height});
  const BoxConstraints.loose(Size size);
}
class ConstrainedBox extends Widget {
  const ConstrainedBox({required BoxConstraints constraints, Widget? child});
}
class Container extends Widget {
  const Container({double? width, double? height, BoxConstraints? constraints, Widget? child});
}
class AnimatedContainer extends Widget {
  const AnimatedContainer({double? height, BoxConstraints? constraints, Widget? child});
}
''';

mixin _Flutter on AnalysisRuleTest {
  void stubs() {
    newPackage('flutter').addFile('lib/widgets.dart', _widgets);
  }
}

@reflectiveTest
class TextScaleFactorTest extends AnalysisRuleTest with _Flutter {
  @override
  void setUp() {
    rule = AvoidTextScaleFactor();
    stubs();
    super.setUp();
  }

  Future<void> test_the_getter_and_media_query_forms() async {
    const code = r'''
import 'package:flutter/widgets.dart';
void f(BuildContext c, MediaQueryData data, TextScaler scaler) {
  MediaQuery.textScaleFactorOf(c);
  MediaQuery.maybeTextScaleFactorOf(c);
  data.textScaleFactor;
  MediaQuery.of(c).textScaleFactor;
  scaler.textScaleFactor;
}
''';
    await assertDiagnostics(code, [
      lint(code.indexOf('textScaleFactorOf'), 'textScaleFactorOf'.length),
      lint(
        code.indexOf('maybeTextScaleFactorOf'),
        'maybeTextScaleFactorOf'.length,
      ),
      lint(code.indexOf('data.textScaleFactor') + 5, 'textScaleFactor'.length),
      lint(code.indexOf('of(c).textScaleFactor') + 6, 'textScaleFactor'.length),
      lint(
        code.indexOf('scaler.textScaleFactor') + 7,
        'textScaleFactor'.length,
      ),
    ]);
  }

  Future<void> test_named_argument() async {
    const code = r'''
import 'package:flutter/widgets.dart';
Widget f() => const Text('x', textScaleFactor: 1.2);
''';
    await assertDiagnostics(code, [
      lint(code.indexOf('textScaleFactor:'), "textScaleFactor: 1.2".length),
    ]);
  }

  Future<void> test_text_scaler_is_fine() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
double f(BuildContext c) => MediaQuery.textScalerOf(c).scale(14);
Widget g(TextScaler s) => Text('x', textScaler: s);
''');
  }

  Future<void> test_implementing_the_getter_is_not_a_use() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
class Linear extends TextScaler {
  const Linear();
  @override
  double scale(double fontSize) => fontSize;
  @override
  double get textScaleFactor => 1;
}
''');
  }
}

@reflectiveTest
class FixedHeightTextTest extends AnalysisRuleTest with _Flutter {
  @override
  void setUp() {
    rule = AvoidFixedHeightText();
    stubs();
    newPackage('raft_ui').addFile('lib/css.dart', r'''
import 'package:flutter/widgets.dart';
class RaftCssText extends Widget { const RaftCssText(String data); }
''');
    super.setUp();
  }

  Future<void> test_literal_and_const_heights_around_a_direct_text() async {
    const code = r'''
import 'package:flutter/widgets.dart';
import 'package:raft_ui/css.dart';
const double rowHeight = 32;
class M { static const double chip = 20; }
void f() {
  const SizedBox(height: 24, child: Text('a'));
  const Container(height: rowHeight, child: Text.rich(Object()));
  const AnimatedContainer(height: M.chip + 2, child: SelectableText('a'));
  const SizedBox(height: -(4.5), child: TextField());
  const SizedBox(height: 16, child: RaftCssText('a'));
}
''';
    await assertDiagnostics(code, [
      for (final snippet in [
        "const SizedBox(height: 24, child: Text('a'))",
        'const Container(height: rowHeight, child: Text.rich(Object()))',
        "const AnimatedContainer(height: M.chip + 2, child: SelectableText('a'))",
        'const SizedBox(height: -(4.5), child: TextField())',
        "const SizedBox(height: 16, child: RaftCssText('a'))",
      ])
        lint(code.indexOf(snippet), snippet.length),
    ]);
  }

  Future<void> test_constraints_capping_the_height() async {
    const code = r'''
import 'package:flutter/widgets.dart';
void f() {
  const ConstrainedBox(constraints: BoxConstraints(maxHeight: 40), child: Text('a'));
  const ConstrainedBox(constraints: BoxConstraints.tightFor(height: 40), child: Text('a'));
  const Container(constraints: BoxConstraints.expand(height: 40), child: Text('a'));
  const AnimatedContainer(constraints: BoxConstraints(minHeight: 8, maxHeight: 40), child: Text('a'));
}
''';
    await assertDiagnostics(code, [
      for (final snippet in [
        "const ConstrainedBox(constraints: BoxConstraints(maxHeight: 40), child: Text('a'))",
        "const ConstrainedBox(constraints: BoxConstraints.tightFor(height: 40), child: Text('a'))",
        "const Container(constraints: BoxConstraints.expand(height: 40), child: Text('a'))",
        "const AnimatedContainer(constraints: BoxConstraints(minHeight: 8, maxHeight: 40), child: Text('a'))",
      ])
        lint(code.indexOf(snippet), snippet.length),
    ]);
  }

  Future<void> test_boxes_that_can_grow_are_fine() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
double h(BuildContext c) => 24;
void f(BuildContext c, double runtime) {
  const ConstrainedBox(constraints: BoxConstraints(minHeight: 24), child: Text('a'));
  const Container(constraints: BoxConstraints.tightFor(), child: Text('a'));
  const ConstrainedBox(constraints: BoxConstraints(minHeight: 24, maxHeight: double.infinity), child: Text('a'));
  const SizedBox(height: double.infinity, child: Text('a'));
  SizedBox(height: runtime, child: const Text('a'));
  SizedBox(height: MediaQuery.textScalerOf(c).scale(24), child: const Text('a'));
  SizedBox(height: h(c), child: const Text('a'));
  SizedBox(height: runtime * 2, child: const Text('a'));
  const SizedBox(width: 24, child: Text('a'));
}
''');
  }

  Future<void> test_non_text_children_and_wrapped_text_are_fine() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
void f() {
  const SizedBox(height: 24, child: Icon(1));
  const SizedBox(height: 24, child: Center(child: Text('a')));
  const SizedBox(height: 24);
  const SizedBox.square(dimension: 24, child: Icon(2));
  const Container(height: 24, child: SizedBox(height: 8));
}
''');
  }

  Future<void> test_other_classes_with_the_same_names_are_fine() async {
    await assertNoDiagnostics(r'''
class Text { const Text(String s); }
class SizedBox { const SizedBox({double? height, Object? child}); }
void f() {
  const SizedBox(height: 24, child: Text('a'));
}
''');
  }
}

@reflectiveTest
class PixelTextHeightTest extends AnalysisRuleTest with _Flutter {
  @override
  void setUp() {
    rule = AvoidPixelTextHeight();
    stubs();
    super.setUp();
  }

  Future<void> test_pixel_literals_in_text_style() async {
    const code = r'''
import 'package:flutter/widgets.dart';
void f(TextStyle base) {
  const TextStyle(fontSize: 14, height: 20);
  const TextStyle(height: 16.5);
  base.copyWith(height: 18);
}
''';
    await assertDiagnostics(code, [
      lint(code.indexOf('height: 20'), 'height: 20'.length),
      lint(code.indexOf('height: 16.5'), 'height: 16.5'.length),
      lint(code.indexOf('height: 18'), 'height: 18'.length),
    ]);
  }

  Future<void> test_ratios_and_other_classes_are_fine() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
class Other { const Other({double? height}); }
const lineHeight = 20;
void f(TextStyle base) {
  const TextStyle(fontSize: 14, height: 1.5);
  const TextStyle(height: 3);
  const TextStyle(height: 20 / 14);
  const TextStyle(height: 1);
  base.copyWith(height: 1.25);
  const SizedBox(height: 20);
  const Other(height: 40);
}
''');
  }
}

/// The command-line runner path (`tool/raft-lints`): every check through
/// [AllChecksVisitor], then `// ignore: raft_lints/<rule>` filtering.
@reflectiveTest
class RunnerSuppressionTest extends AnalysisRuleTest with _Flutter {
  @override
  void setUp() {
    rule = AvoidTextScaleFactor();
    stubs();
    super.setUp();
  }

  Future<List<String>> run(String code, {String? path}) async {
    final file = path ?? testFilePath;
    newFile(file, code);
    final ResolvedUnitResult result = await resolveFile(file);
    final ignores = Ignores.of(result.unit, result.content);
    final found = <String>[];
    result.unit.accept(
      AllChecksVisitor(path: file, (rule, node) {
        final line = result.lineInfo.getLocation(node.offset).lineNumber;
        if (!ignores.isIgnored(rule, line)) found.add('$rule:$line');
      }),
    );
    return found;
  }

  Future<void> test_ignore_comments_silence_each_rule_on_its_line() async {
    expect(
      await run(r'''
import 'package:flutter/widgets.dart';
double f(BuildContext c, MediaQueryData d) {
  // ignore: raft_lints/avoid_text_scale_factor -- legacy plugin API
  final a = MediaQuery.textScaleFactorOf(c);
  final b = d.textScaleFactor; // ignore: raft_lints/avoid_text_scale_factor -- ok
  return a + b;
}
void g() {
  // ignore: raft_lints/avoid_fixed_height_text -- single-line chrome
  const SizedBox(height: 24, child: Text('a'));
  const SizedBox(height: 24, child: Text('b')); // ignore: raft_lints/avoid_fixed_height_text -- chrome
  // ignore: raft_lints/avoid_pixel_text_height -- mirrors a px spec
  const TextStyle(height: 20);
}
'''),
      isEmpty,
    );
  }

  Future<void> test_an_ignore_for_another_rule_does_not_apply() async {
    expect(
      await run(r'''
import 'package:flutter/widgets.dart';
void g(BuildContext c) {
  // ignore: raft_lints/avoid_fixed_height_text -- wrong rule
  MediaQuery.textScaleFactorOf(c);
  // ignore: raft_lints/avoid_text_scale_factor -- wrong rule
  const SizedBox(height: 24, child: Text('a'));
  // ignore: raft_lints/avoid_text_scale_factor -- wrong rule
  const TextStyle(height: 20);
}
'''),
      [
        'avoid_text_scale_factor:4',
        'avoid_fixed_height_text:6',
        'avoid_pixel_text_height:8',
      ],
    );
  }

  Future<void> test_no_file_is_exempt_from_the_fixed_height_rule() async {
    // Every surface that predated the rule was fixed; the list stays empty.
    expect(legacyFixedHeightTextFiles, isEmpty);
    const code = r'''
import 'package:flutter/widgets.dart';
void g(BuildContext c) {
  const SizedBox(height: 24, child: Text('a'));
  MediaQuery.textScaleFactorOf(c);
}
''';
    expect(
      await run(
        code,
        path: '$testPackageRootPath/packages/raft_ui/lib/src/action_card.dart',
      ),
      ['avoid_fixed_height_text:3', 'avoid_text_scale_factor:4'],
    );
  }

  Future<void> test_legacy_path_matching() async {
    expect(
      isLegacyFixedHeightTextFile('/r/packages/raft_ui/lib/a.dart'),
      isFalse,
    );
  }
}
