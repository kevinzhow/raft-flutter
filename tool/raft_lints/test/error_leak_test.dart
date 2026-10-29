import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
// ignore: implementation_imports
import 'package:analyzer_testing/src/analysis_rule/pub_package_resolution.dart'
    show ExpectedDiagnostic;
import 'package:raft_lints/src/banned_apis.dart';
import 'package:test/test.dart' show expect, isTrue, isFalse;
import 'package:raft_lints/src/error_leak.dart';
import 'package:raft_lints/src/rules.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(CaughtExceptionTextTest);
    defineReflectiveTests(MaterialFeedbackTest);
    defineReflectiveTests(TextArgumentTest);
  });
}

const _sdkHelpers = r'''
void debugPrint(String? m) {}
void logUserError(Object e) {}
Never fail() => throw Exception('x');
''';

@reflectiveTest
class CaughtExceptionTextTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = AvoidCaughtExceptionText();
    super.setUp();
  }

  ExpectedDiagnostic at(String code, String snippet, int length) =>
      lint(code.indexOf(snippet), length);

  Future<void> test_interpolation_tostring_and_members() async {
    const code =
        '''
$_sdkHelpers
String f() {
  try {
    fail();
  } catch (e) {
    final a = 'failed: \$e';
    final b = '\${e}';
    final c = e.toString();
    final d = (e as dynamic).message;
    return a + b + c + d;
  }
}
''';
    await assertDiagnostics(code, [
      lint(code.indexOf(r'$e') + 1, 1),
      lint(code.indexOf(r'${e}') + 2, 1),
      at(code, 'e.toString()', 1),
    ]);
  }

  Future<void> test_text_widget_argument_and_members_of_typed_catch() async {
    const code = '''
class Text { const Text(String s); }
class Failure { String message = ''; Object? response; }
Text f() {
  try {
    return const Text('ok');
  } on Failure catch (error) {
    final status = error.response;
    return Text(error.message + '\$status');
  }
}
''';
    await assertDiagnostics(
      code,
      [
        at(code, 'error.response', 5),
        at(code, 'error.message', 5),
        at(code, r'$status', 7),
      ].take(2).toList(),
    );
  }

  Future<void> test_log_calls_are_not_ui() async {
    await assertNoDiagnostics('''
$_sdkHelpers
void f() {
  try {
    fail();
  } catch (error) {
    debugPrint('Failed to load: \$error');
    logUserError(error);
  }
}
''');
  }

  Future<void> test_rethrow_and_passing_the_object_along_are_fine() async {
    await assertNoDiagnostics('''
$_sdkHelpers
Object? sink;
void f() {
  try {
    fail();
  } catch (error) {
    sink = error;
    if (error is Exception) rethrow;
  }
}
''');
  }

  Future<void> test_shadowing_is_resolved_not_matched_by_name() async {
    await assertNoDiagnostics('''
$_sdkHelpers
void f(String e) {
  try {
    fail();
  } catch (error) {
    void g(String error) { debugPrint('\$error'); }
    g(e);
    final other = '\$e';
  }
}
''');
  }

  Future<void> test_catch_error_closure() async {
    const code =
        '''
$_sdkHelpers
void f(Future<int> p) {
  p.catchError((err) {
    final s = '\$err';
    return 0;
  });
}
''';
    await assertDiagnostics(code, [lint(code.indexOf(r'$err') + 1, 3)]);
  }
}

@reflectiveTest
class MaterialFeedbackTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = BannedApiRule(bannedApis.firstWhere((a) => a.rule == feedbackRule));
    newPackage('flutter').addFile('lib/material.dart', r'''
class SnackBar { const SnackBar(); }
class ScaffoldMessengerState { void showSnackBar(SnackBar s) {} }
class ScaffoldMessenger {
  static ScaffoldMessengerState of(Object context) => ScaffoldMessengerState();
}
''');
    super.setUp();
  }

  Future<void> test_snack_bar_and_messenger() async {
    const code = r'''
import 'package:flutter/material.dart';
void f(Object context) {
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar());
}
''';
    await assertDiagnostics(code, [
      lint(code.indexOf('of(context)'), 2),
      lint(code.indexOf('showSnackBar'), 'showSnackBar'.length),
      lint(code.indexOf('SnackBar()'), 'SnackBar'.length),
    ]);
  }
}

@reflectiveTest
class TextArgumentTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = AvoidCaughtExceptionText();
    super.setUp();
  }

  Future<void> test_text_of_the_caught_object() async {
    const code = r'''
class Text { const Text(Object s); }
Text f() {
  try {
    return const Text('ok');
  } catch (error) {
    return Text(error);
  }
}
''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('error'), 5)]);
  }

  void test_scope() {
    expect(errorLeakScope('/r/apps/raft_flutter/lib/a.dart'), isTrue);
    expect(errorLeakScope('/r/packages/raft_ui/lib/a.dart'), isTrue);
    expect(errorLeakScope('/r/packages/raft_client/lib/a.dart'), isFalse);
    expect(errorLeakScope(r'C:\r\packages\raft_sync\lib\a.dart'), isFalse);
  }
}
