import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import '../data/workspace_cache.dart';
import '../platform/app_services.dart';
import '../platform/app_window.dart';
import '../platform/system_fonts.dart';
import 'app_root_router.dart';
import 'workspace_host_scope.dart';
import '../platform/desktop_title_bar.dart';
import '../platform/keyboard_inset_guard.dart';
import '../platform/system_bars.dart';
import 'private_app_invite.dart';

/// Shared application viewport scopes. Navigation, account and update-service
/// ownership stay above this presentation-only composition in the app root.
Widget buildAppViewport({
  required GlobalKey screenshotKey,
  required WorkspaceController? workspace,
  required bool integrated,
  required String coordinator,
  required Future<void> Function(Uri) openLocation,
  required Widget child,
}) => RaftTextScaling(
  child: RepaintBoundary(
    key: screenshotKey,
    child: DesktopTitleBar(
      integrated: integrated,
      workspace: workspace,
      child: RaftTooltipProvider(
        delay: const Duration(milliseconds: 600),
        child: RaftViewportBreakpointScope(
          // Resolves the theme's font combinations once the app is idle.
          child: RaftFontWarmUpScope(
            child: RaftSystemBars(
              child: RaftErrorScope(
                format: raftAppErrorFormatter,
                child: RaftToastHost(
                  child: KeyboardInsetGuard(
                    imeVisible: platformImeVisibility,
                    child: PrivateAppInviteScope(
                      coordinator: coordinator,
                      onOpen: openLocation,
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

/// Application presentation composition. Root retains account, routing and
/// service authority; the existing service host owns its window lifecycle.
/// This function adds no Element or state layer around the prior widget tree.
Widget buildRaftApplication({
  required RaftAppRouter router,
  required RouteInformationProvider routeInformation,
  required RaftAppearance appearance,
  required Locale locale,
  required AppServices services,
  required bool ownsAppUpdate,
  required (RaftClient?, WorkspaceController?) session,
  required Future<void> Function() onLogout,
  required WorkspaceCache? cache,
  required GlobalKey screenshotKey,
  required bool showServerSelector,
  required String coordinator,
  required Future<void> Function(Uri) openLocation,
}) {
  final workspace = session.$2;
  final textLocale = WidgetsBinding.instance.platformDispatcher.locale;
  ThemeData themed({bool dark = false}) => raftTheme(
    dark: dark,
    pack: appearance.pack,
    systemFonts: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
    systemFontFamilies: NativeSystemFonts.instance.value,
    locale: locale,
    textLocale: textLocale,
  );
  return MaterialApp.router(
    title: 'Raft',
    routerDelegate: router,
    routeInformationParser: const RaftAppRouteParser(),
    routeInformationProvider: routeInformation,
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, child) => router.withHoverDismiss(
      RaftHoverScope.forPlatform(
        child: AppWindowCommands(
          navigatorKey: router.navigatorKey,
          openSection: workspace?.setSection,
          child: AppServicesHost(
            services: services,
            ownsAppUpdate: ownsAppUpdate,
            session: session,
            onLogout: onLogout,
            cache: cache,
            navigatorKey: router.navigatorKey,
            child: buildAppViewport(
              screenshotKey: screenshotKey,
              workspace: workspace,
              integrated:
                  workspace?.server != null &&
                  !showServerSelector &&
                  WorkspaceHostScope.showsTopBar(context),
              coordinator: coordinator,
              openLocation: openLocation,
              child: child!,
            ),
          ),
        ),
      ),
    ),
    debugShowCheckedModeBanner: false,
    theme: themed(),
    darkTheme: themed(dark: true),
    themeMode: appearance.mode,
  );
}
