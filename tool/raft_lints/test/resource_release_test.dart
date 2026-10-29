import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:raft_lints/src/rules.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ResourceReleaseTest);
  });
}

@reflectiveTest
class ResourceReleaseTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = AvoidUnreleasedResource();
    newPackage('flutter').addFile('lib/widgets.dart', r'''
class ValueNotifier<T> { ValueNotifier(this.value); T value; void dispose() {} }
class FocusNode { void dispose() {} }
class ScrollController { void dispose() {} }
class AnimationController { AnimationController({Object? vsync}); void dispose() {} }
''');
    super.setUp();
    // The mock dart:async Timer has no cancel().
    final async = getFile('${sdkRoot.path}/lib/async/async.dart');
    async.writeAsStringSync(
      async.readAsStringSync().replaceFirst(
        'abstract interface class Timer {',
        'abstract interface class Timer {\n  void cancel();',
      ),
    );
  }

  Future<void> test_unreleased_field_controller_timer_and_subscription() async {
    const code = r'''
import 'dart:async';
import 'package:flutter/widgets.dart';
class S {
  final focus = FocusNode();
  Timer? timer;
  StreamSubscription<int>? sub;
  void start(Stream<int> stream) {
    timer = Timer(const Duration(seconds: 1), () {});
    sub = stream.listen((_) {});
  }
}
''';
    await assertDiagnostics(code, [
      lint(code.indexOf('focus = '), 'focus = FocusNode()'.length),
      lint(
        code.indexOf('timer = Timer'),
        "timer = Timer(const Duration(seconds: 1), () {})".length,
      ),
      lint(code.indexOf('sub = stream'), 'sub = stream.listen((_) {})'.length),
    ]);
  }

  Future<void> test_released_in_dispose_by_call_and_loop() async {
    await assertNoDiagnostics(r'''
import 'dart:async';
import 'package:flutter/widgets.dart';
class S<T> {
  final focus = FocusNode();
  final scroll = ScrollController();
  late final selection = ValueNotifier<T?>(null);
  Timer? timer;
  StreamSubscription<int>? sub;
  void start(Stream<int> stream) {
    timer = Timer(const Duration(seconds: 1), () {});
    sub = stream.listen((_) {});
  }
  void dispose() {
    focus.dispose();
    for (final c in [scroll]) {
      c.dispose();
    }
    selection.dispose();
    timer?.cancel();
    sub?.cancel();
  }
}
''');
  }

  Future<void>
  test_local_controllers_and_collection_slots_are_not_owned() async {
    await assertNoDiagnostics(r'''
import 'dart:async';
import 'package:flutter/widgets.dart';
class S {
  final timers = <int, Timer>{};
  void arm(int id) {
    timers[id] = Timer(const Duration(seconds: 1), () {});
  }
  void local() {
    final notifier = ValueNotifier<int>(0);
    notifier.value = 1;
  }
}
''');
  }
}
