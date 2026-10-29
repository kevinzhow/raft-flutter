import 'dart:async';

import '../../test/flutter_test_config.dart' as app;

/// The capture scripts in this directory run on the same test binding, fonts
/// and leak settings as the suite in `test/`.
Future<void> testExecutable(FutureOr<void> Function() testMain) =>
    app.testExecutable(testMain);
