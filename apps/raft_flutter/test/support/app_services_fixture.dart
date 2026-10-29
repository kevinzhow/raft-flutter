import 'package:flutter/widgets.dart';
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_flutter/platform/app_update.dart';

/// Explicit borrowed services for a standalone workspace fixture.
/// Production installs its scope above Navigator in RaftApp.
Widget withAppServices(Widget child, {AppUpdateService? update}) =>
    AppServicesScope(
      services: update == null
          ? const AppServices.updatesDisabledForTestOrPreview()
          : AppServices.withUpdates(update),
      child: child,
    );
