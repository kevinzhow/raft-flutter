import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
// ignore: implementation_imports
import 'package:analyzer_testing/src/analysis_rule/pub_package_resolution.dart'
    show ExpectedDiagnostic;
import 'package:raft_lints/src/banned_apis.dart';
import 'package:raft_lints/src/rules.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ProxyTest);
    defineReflectiveTests(ImageTest);
    defineReflectiveTests(UnderlineTest);
    defineReflectiveTests(SliderTest);
    defineReflectiveTests(SelectionAreaTest);
    defineReflectiveTests(BottomSheetTest);
    defineReflectiveTests(IdleWorkTest);
  });
}

BannedApi _api(String rule) => bannedApis.firstWhere((a) => a.rule == rule);

mixin _Stubs on AnalysisRuleTest {
  void stubs() {
    newPackage('flutter').addFile('lib/widgets.dart', r'''
abstract class Widget { const Widget(); }
abstract class ImageProvider { const ImageProvider(); }
class NetworkImage extends ImageProvider { const NetworkImage(String url); }
class MemoryImage extends ImageProvider { const MemoryImage(List<int> b); }
class Image extends Widget {
  const Image({required ImageProvider image});
  const Image.network(String url);
}
class RawImage extends Widget { const RawImage(); }
class CircleAvatar extends Widget { const CircleAvatar({ImageProvider? backgroundImage}); }
class TextDecoration { static const underline = TextDecoration(); static const none = TextDecoration(); const TextDecoration(); }
class Slider extends Widget { const Slider(); }
class SelectionArea extends Widget { const SelectionArea({required Widget child}); }
class SliderTheme extends Widget { const SliderTheme(); }
class BottomSheet extends Widget { const BottomSheet(); }
class DraggableScrollableSheet extends Widget { const DraggableScrollableSheet(); }
class ModalBottomSheetRoute<T> { ModalBottomSheetRoute(); }
Future<T?> showModalBottomSheet<T>() async => null;
''');
    newPackage('dio').addFile('lib/dio.dart', r'''
class Dio { Dio(); }
class IOHttpClientAdapter { IOHttpClientAdapter(); }
''');
    newPackage('socket_io_client').addFile('lib/socket_io_client.dart', r'''
Object io(String uri) => uri;
''');
  }

  ExpectedDiagnostic at(String code, String snippet) =>
      lint(code.indexOf(snippet), snippet.length);
}

@reflectiveTest
class ProxyTest extends AnalysisRuleTest with _Stubs {
  @override
  void setUp() {
    rule = BannedApiRule(_api(proxyRule));
    stubs();
    super.setUp();
  }

  Future<void> test_dio_adapter_and_socket_io() async {
    const code = r'''
import 'package:dio/dio.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
void f() {
  Dio();
  IOHttpClientAdapter();
  io.io('x');
}
''';
    await assertDiagnostics(code, [
      lint(code.indexOf('Dio();'), 5),
      at(code, 'IOHttpClientAdapter()'),
      lint(code.indexOf("io('x')"), 2),
    ]);
  }

  Future<void> test_unrelated_calls_are_fine() async {
    await assertNoDiagnostics(r'''
class Dio2 { Dio2(); }
void f() { Dio2(); }
''');
  }
}

@reflectiveTest
class ImageTest extends AnalysisRuleTest with _Stubs {
  @override
  void setUp() {
    rule = BannedApiRule(_api(imageRule));
    stubs();
    super.setUp();
  }

  Future<void> test_providers_image_widgets_and_background_image() async {
    const code = r'''
import 'package:flutter/widgets.dart';
Widget f() => Image.network('u');
Object g() => const NetworkImage('u');
Widget h() => const CircleAvatar(backgroundImage: null);
''';
    await assertDiagnostics(code, [
      at(code, "Image.network('u')"),
      at(code, "const NetworkImage('u')"),
      at(code, 'backgroundImage: null'),
    ]);
  }

  Future<void> test_own_class_named_image_is_fine() async {
    await assertNoDiagnostics(r'''
class Image { const Image(); }
Object f() => const Image();
''');
  }
}

@reflectiveTest
class UnderlineTest extends AnalysisRuleTest with _Stubs {
  @override
  void setUp() {
    rule = BannedApiRule(_api(underlineRule));
    stubs();
    super.setUp();
  }

  Future<void> test_underline() async {
    const code = r'''
import 'package:flutter/widgets.dart';
Object f() => TextDecoration.underline;
Object g() => TextDecoration.none;
''';
    await assertDiagnostics(code, [at(code, 'TextDecoration.underline')]);
  }
}

@reflectiveTest
class SliderTest extends AnalysisRuleTest with _Stubs {
  @override
  void setUp() {
    rule = BannedApiRule(_api(sliderRule));
    stubs();
    super.setUp();
  }

  Future<void> test_slider_creation_and_type_name() async {
    const code = r'''
import 'package:flutter/widgets.dart';
Widget f() => const Slider();
Slider? g;
''';
    await assertDiagnostics(code, [
      lint(code.indexOf('Slider()'), 6),
      lint(code.indexOf('Slider?'), 7),
    ]);
  }

  Future<void> test_other_widgets_are_fine() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
Widget f() => const RawImage();
''');
  }
}

@reflectiveTest
class SelectionAreaTest extends AnalysisRuleTest with _Stubs {
  @override
  void setUp() {
    rule = BannedApiRule(_api(selectionRule));
    stubs();
    super.setUp();
  }

  Future<void> test_bare_selection_area() async {
    const code = r'''
import 'package:flutter/widgets.dart';
Widget f(Widget child) => SelectionArea(child: child);
''';
    await assertDiagnostics(code, [at(code, 'SelectionArea')]);
  }

  Future<void> test_other_widgets_are_fine() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
Widget f() => const RawImage();
''');
  }
}

@reflectiveTest
class BottomSheetTest extends AnalysisRuleTest with _Stubs {
  @override
  void setUp() {
    rule = BannedApiRule(_api(sheetRule));
    stubs();
    super.setUp();
  }

  Future<void> test_framework_sheets_are_banned() async {
    const code = r'''
import 'package:flutter/widgets.dart';
Future<void> f() => showModalBottomSheet<void>();
Widget g() => const BottomSheet();
Widget h() => const DraggableScrollableSheet();
class R extends ModalBottomSheetRoute<void> {}
''';
    await assertDiagnostics(code, [
      at(code, 'showModalBottomSheet'),
      lint(code.indexOf('BottomSheet()'), 11),
      at(code, 'DraggableScrollableSheet'),
      lint(code.indexOf('ModalBottomSheetRoute'), 27),
    ]);
  }

  Future<void> test_other_widgets_are_fine() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
Widget f() => const RawImage();
''');
  }
}

@reflectiveTest
class IdleWorkTest extends AnalysisRuleTest with _Stubs {
  @override
  void setUp() {
    rule = BannedApiRule(_api(idleRule));
    newPackage('flutter').addFile('lib/scheduler.dart', r'''
class AnimationController { void repeat() {} void forward() {} }
class SchedulerBinding {
  void scheduleFrame() {}
  void addPostFrameCallback(void Function(Object) cb) {}
}
''');
    super.setUp();
    // The mock dart:async lacks a few members the rule looks for.
    final async = getFile('${sdkRoot.path}/lib/async/async.dart');
    async.writeAsStringSync(
      async.readAsStringSync().replaceFirst(
            'abstract interface class Timer {',
            'abstract interface class Timer {\n'
                '  static void run(void Function() cb) {}\n'
                '  factory Timer.periodic(Duration d, void Function(Timer t) cb) => throw 0;',
          ) +
          '\nvoid scheduleMicrotask(void Function() cb) {}\n',
    );
  }

  Future<void> test_the_spinning_shapes() async {
    const code = r'''
import 'dart:async';
import 'package:flutter/scheduler.dart';
void tick(Object _) {}
void f(AnimationController c, SchedulerBinding b) {
  Timer.run(() {});
  Timer(Duration.zero, () {});
  Timer(const Duration(), () {});
  Timer.periodic(const Duration(seconds: 1), (t) {});
  Future.delayed(Duration.zero);
  scheduleMicrotask(() {});
  c.repeat();
  b.scheduleFrame();
  b.addPostFrameCallback(tick);
}
''';
    await assertDiagnostics(code, [
      lint(code.indexOf('Timer.run') + 6, 3),
      lint(
        code.indexOf('Timer(Duration.zero'),
        'Timer(Duration.zero, () {})'.length,
      ),
      lint(
        code.indexOf('Timer(const Duration()'),
        'Timer(const Duration(), () {})'.length,
      ),
      lint(
        code.indexOf('Timer.periodic'),
        'Timer.periodic(const Duration(seconds: 1), (t) {})'.length,
      ),
      lint(
        code.indexOf('Future.delayed'),
        'Future.delayed(Duration.zero)'.length,
      ),
      lint(code.indexOf('scheduleMicrotask'), 'scheduleMicrotask'.length),
      lint(code.indexOf('repeat'), 6),
      lint(code.indexOf('scheduleFrame'), 'scheduleFrame'.length),
      lint(code.indexOf('addPostFrameCallback'), 'addPostFrameCallback'.length),
    ]);
  }

  Future<void> test_bounded_shapes_are_fine() async {
    await assertNoDiagnostics(r'''
import 'dart:async';
import 'package:flutter/scheduler.dart';
void f(AnimationController c, SchedulerBinding b) {
  Timer(const Duration(seconds: 5), () {});
  Future.delayed(const Duration(seconds: 5));
  c.forward();
  b.addPostFrameCallback((_) {});
}
''');
  }
}
