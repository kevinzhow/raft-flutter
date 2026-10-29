import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:raft_lints/src/rules.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NoticeStateTest);
  });
}

@reflectiveTest
class NoticeStateTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = AvoidImperativeNoticeState();
    super.setUp();
  }

  Future<void> test_mutable_notice_fields() async {
    const code = r'''
class S {
  String? error;
  String billingNotice = '';
  bool selectionNotice = false;
  Map<String, String> composerErrors = {};
  late String lastFailure;
  var warning;
  int errorCount = 0;
  void use() { void local() { String? uploadError; } }
}
''';
    await assertDiagnostics(code, [
      lint(code.indexOf('error;'), 'error'.length),
      lint(code.indexOf('billingNotice'), 'billingNotice = \'\''.length),
      lint(code.indexOf('selectionNotice'), 'selectionNotice = false'.length),
      lint(code.indexOf('composerErrors'), 'composerErrors = {}'.length),
      lint(code.indexOf('lastFailure'), 'lastFailure'.length),
      lint(code.indexOf('warning'), 'warning'.length),
      lint(code.indexOf('uploadError'), 'uploadError'.length),
    ]);
  }

  Future<void> test_every_name_of_a_multi_declaration_is_checked() async {
    const code = r'''
class S {
  bool disconnectConfirmed = false,
      partialFailure = false,
      working = false;
}
''';
    await assertDiagnostics(code, [
      lint(code.indexOf('partialFailure'), 'partialFailure = false'.length),
    ]);
  }

  Future<void> test_final_static_and_other_types_are_fine() async {
    await assertNoDiagnostics(r'''
class S {
  final String error = '';
  static String? notice;
  static const String warning = '';
  Object? failure;
  int errorCode = 0;
  String name = '';
  String get errorText => '';
}
''');
  }

  Future<void> test_set_error_calls() async {
    const code = r'''
class C {
  void setError(String? e) {}
  void setComposerError(String? e) {}
  void f() {
    setError('x');
    setComposerError(null);
  }
}
''';
    await assertDiagnostics(code, [
      lint(code.indexOf("setError('x')"), 'setError'.length),
      lint(code.indexOf('setComposerError(null)'), 'setComposerError'.length),
    ]);
  }
}
