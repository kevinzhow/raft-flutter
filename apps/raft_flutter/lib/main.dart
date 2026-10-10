import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raft_client/raft_client.dart';
import 'package:path_provider/path_provider.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/attachment_image_store.dart';
import 'data/device_preferences.dart';
import 'data/workspace_controller.dart';
import 'data/source_time_formatter.dart';
import 'data/workspace_cache.dart';
import 'data/raft_location.dart';
import 'data/raft_navigation_history.dart';
import 'features/app_root_router.dart';
import 'features/global_server_selector.dart';
import 'features/workspace_view.dart';
import 'features/auth_view.dart';
import 'features/account_onboarding.dart';
import 'features/private_route_guard.dart';
import 'platform/session_store.dart';
import 'platform/local_network_access.dart';
import 'platform/session_persistence.dart';
import 'platform/native_sharing.dart';
import 'platform/content_coordinator.dart';
import 'platform/workspace_cache.dart';
import 'platform/system_bars.dart';
import 'platform/background_notifications.dart';

final raftScreenshotKey = GlobalKey();

Future<void> main([List<String> args = const []]) async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeSourceTimeFormatting();
  // First frames read saved layout choices synchronously from this.
  await DevicePreferences.load();
  // Inline image previews survive restarts; reads stay authority-gated.
  AttachmentImageDiskCache.installed ??= AttachmentImageDiskCache(
    getApplicationCacheDirectory,
  );
  runApp(ProviderScope(child: RaftApp(initialArguments: args)));
}

/// The server stores only locales shipped by the UI. Translation language is separate.
Locale displayLocale(String? preference, {Locale? device}) {
  final language = preference?.toLowerCase().replaceAll('_', '-');
  if (language == 'zh-cn' || language == 'zh-hans') {
    return const Locale('zh', 'CN');
  }
  if (language == 'en' || language?.startsWith('en-') == true) {
    return const Locale('en');
  }
  final resolved = device ?? WidgetsBinding.instance.platformDispatcher.locale;
  return resolved.languageCode == 'zh' &&
          (resolved.countryCode == 'CN' ||
              resolved.scriptCode == 'Hans' ||
              resolved.countryCode == null)
      ? const Locale('zh', 'CN')
      : const Locale('en');
}

class RaftApp extends StatefulWidget {
  const RaftApp({
    super.key,
    this.sessionStore,
    this.initialArguments = const [],
    this.initialLocation,
    this.createClient,
    this.openWorkspaceCache,
    this.nativeContent,
    this.nativeSharing,
  });
  final List<String> initialArguments;
  final SessionStore? sessionStore;
  final Uri? initialLocation;
  final RaftClient Function(String origin, SessionStore store, String kind)?
  createClient;
  final Future<WorkspaceCache?> Function()? openWorkspaceCache;
  final NativeContentCoordinator? nativeContent;
  final NativeSharing? nativeSharing;
  @override
  State<RaftApp> createState() => _RaftAppState();
}

class _RaftAppState extends State<RaftApp> with WidgetsBindingObserver {
  late final content = widget.nativeContent ?? NativeContentCoordinator();
  late final sharing = widget.nativeSharing ?? NativeSharing();
  late final RaftAppRouter appRouter;
  late final PlatformRouteInformationProvider routeInformation;
  Uri requestedLocation = Uri(path: '/');
  Uri? chooserReturn;
  Uri? serverSwitchLocation, serverSwitchReturn;
  bool showServerSelector = true,
      directoryLoading = true,
      selectingServer = false;
  String? selectorError;
  int rootRequest = 0;
  final Map<String, Uri> serverSurfaces = {};
  String? publishedServerId;
  int? publishedWorkspaceIndex;
  late final SessionPersistence sessionPersistence;
  late final sessionOwner = NativeSessionOwner(poll: content.pollBackground);
  int authAttempt = 0;
  final privateRoutes = PrivateRouteGuard();
  RaftClient? client;
  WorkspaceController? workspace;
  WorkspaceCache? cache;
  StreamSubscription<RaftEvent>? sessionEvents;
  RaftAppearance appearance = const RaftAppearance();
  bool restoring = true;
  String? bootError;
  String origin = const String.fromEnvironment(
    'RAFT_ORIGIN',
    defaultValue: 'http://localhost:13041',
  );
  @override
  void initState() {
    super.initState();
    requestedLocation =
        widget.initialLocation ??
        Uri.tryParse(
          WidgetsBinding.instance.platformDispatcher.defaultRouteName,
        ) ??
        Uri(path: '/');
    appRouter = RaftAppRouter(
      home: (_) => restoring
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : sessionHome(),
      onLocation: receiveAppLocation,
      onRootBack: returnFromSelector,
      observers: [privateRoutes],
    );
    routeInformation = RaftAppRouteInformationProvider(
      initialRouteInformation: RouteInformation(uri: requestedLocation),
      consumeReplacement: appRouter.consumeReplacement,
    );
    sessionPersistence = SessionPersistence(
      widget.sessionStore ?? SecureSessionStore(),
    );
    WidgetsBinding.instance.addObserver(this);
    unawaited(sharing.init());
    unawaited(content.init(initialArguments: widget.initialArguments));
    restore();
  }

  Future<void> restore() async {
    try {
      await sessionOwner.acquire();
      if (!mounted) {
        sessionOwner.release();
        return;
      }
      final p = await SharedPreferences.getInstance();
      DevicePreferences.adopt(p);
      origin = p.getString('raft.origin') ?? origin;
      appearance = RaftAppearance(
        mode: ThemeMode.values.byName(p.getString('raft.mode') ?? 'system'),
        light: RaftFamily.values.byName(p.getString('raft.light') ?? 'brutal'),
      );
      cache =
          await (widget.openWorkspaceCache?.call() ??
              DriftWorkspaceCache.open());
      if (!mounted) {
        await cache?.close();
        return;
      }
      late final RaftClient c;
      c = makeClient(
        origin,
        sessionPersistence.guarded(() => mounted && identical(client, c)),
      );
      client = c;
      // Cache-first: a stored account record paints the on-device workspace
      // at once; the session is revalidated in the background and a
      // rejected or replaced account ends through the session events below.
      if (await c.restore(cachedFirst: cache != null)) {
        if (!mounted) {
          await c.dispose();
          return;
        }
        watchSession(c);
        setState(() => restoring = false);
        await finishOnboarding(c);
      }
    } catch (e) {
      bootError = 'Could not restore the session. Sign in to reconnect.';
    }
    if (mounted) setState(() => restoring = false);
  }

  RaftClient authClient(String base, int attempt) {
    final problem = authOriginError(base);
    if (problem != null) throw RaftApiException(problem);
    late final RaftClient candidate;
    candidate = makeClient(
      base.trim(),
      sessionPersistence.guarded(
        () =>
            mounted && (attempt == authAttempt || identical(client, candidate)),
      ),
    );
    return candidate;
  }

  RaftClient makeClient(String base, SessionStore store) {
    final kind =
        defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS
        ? 'mobile'
        : 'desktop';
    return widget.createClient?.call(base, store, kind) ??
        RaftClient(origin: base, sessionStore: store, clientKind: kind);
  }

  Future<void> authenticate(
    String base,
    Future<void> Function(RaftClient) action,
  ) async {
    await sessionOwner.acquire();
    if (!mounted) return;
    final attempt = ++authAttempt;
    final c = authClient(base, attempt);
    bool current() => mounted && attempt == authAttempt;
    try {
      await const LocalNetworkAccess().ensure(base, request: true);
      if (!current()) {
        await c.dispose();
        return;
      }
      await action(c);
      if (!current()) {
        await c.dispose();
        return;
      }
      final oldWorkspace = workspace, oldClient = client;
      await oldWorkspace?.flushCache();
      if (!current()) {
        await c.dispose();
        return;
      }
      sessionEvents?.cancel();
      content.bindWorkspace(null);
      oldWorkspace?.removeListener(workspaceChanged);
      oldWorkspace?.dispose();
      if (oldWorkspace == null) await oldClient?.dispose();
      if (!current()) {
        await c.dispose();
        return;
      }
      workspace = null;
      rootRequest++;
      serverSurfaces.clear();
      chooserReturn = null;
      serverSwitchLocation = serverSwitchReturn = null;
      showServerSelector = true;
      client = c;
      origin = base.trim();
      bootError = null;
      watchSession(c);
      if (mounted) setState(() {});
      final prefs = await SharedPreferences.getInstance();
      if (!current() || !identical(client, c)) return;
      await prefs.setString('raft.origin', origin);
      if (!current() || !identical(client, c)) return;
      await finishOnboarding(c);
    } catch (_) {
      if (!identical(c, client)) await c.dispose();
      rethrow;
    }
  }

  Future<void> login(String base, String email, String password) =>
      authenticate(base, (c) => c.login(email.trim(), password));

  Future<void> register(
    String base,
    String email,
    String password,
    bool accepted,
  ) => authenticate(
    base,
    (c) => c.register(email.trim(), password, acceptTerms: accepted),
  );

  Future<void> completeOAuth(
    String base,
    String code,
    String verifier,
    bool accepted,
  ) => authenticate(
    base,
    (c) => c.completeMobileOAuth(code, verifier, acceptTerms: accepted),
  );

  Future<void> finishOnboarding(RaftClient c) async {
    if (!mounted || !identical(c, client) || accountNeedsOnboarding(c.user)) {
      return;
    }
    if (workspace != null) {
      if (!showServerSelector && serverSwitchLocation == null) {
        content.bindWorkspace(workspace);
      }
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            identical(c, client) &&
            !showServerSelector &&
            serverSwitchLocation == null) {
          workspace?.setForeground(true);
        }
      });
      return;
    }
    final view = View.of(context);
    final logicalWidth = view.physicalSize.width / view.devicePixelRatio;
    final next =
        workspace ??
        WorkspaceController(
          c,
          cache: cache,
          mobileNavigation: logicalWidth < RaftLayoutMetrics.desktopBreakpoint,
        );
    workspace = next;
    next.setForeground(false);
    next.addListener(workspaceChanged);
    setState(() {});
    await discoverServers();
  }

  String get serverMemoryKey =>
      'raft.server-surface.${Uri.encodeComponent(origin)}.${client?.user?.id}';

  Future<void> discoverServers() async {
    final w = workspace, c = client;
    if (w == null || c?.user == null) return;
    final request = ++rootRequest,
        principal = c!.user!.id,
        generation = c.generation;
    bool current() =>
        mounted &&
        request == rootRequest &&
        identical(client, c) &&
        identical(workspace, w) &&
        c.user?.id == principal &&
        c.generation == generation;
    setState(() {
      directoryLoading = true;
      selectorError = null;
    });
    try {
      if (!await w.loadServerDirectory(cachedFirst: true) || !current()) {
        return;
      }
      final servers = w.servers;
      w.loading = false;
      directoryLoading = false;
      w.notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      if (!current()) return;
      final explicit =
          requestedLocation.pathSegments.length >= 2 &&
          requestedLocation.pathSegments.first == 's';
      final slug = explicit
          ? requestedLocation.pathSegments[1]
          : requestedLocation.path == '/servers'
          ? null
          : prefs.getString('$serverMemoryKey.last');
      final target = servers.where((s) => s.string('slug') == slug).firstOrNull;
      if (target != null) {
        final remembered = prefs.getString('$serverMemoryKey.${target.id}');
        await chooseServer(
          target,
          location: explicit
              ? requestedLocation
              : remembered == null
              ? null
              : Uri.tryParse(remembered),
        );
      } else {
        showServerSelector = true;
        appRouter.publish(
          Uri(path: requestedLocation.path == '/servers' ? '/servers' : '/'),
        );
        setState(() {});
      }
    } catch (e) {
      if (current()) {
        setState(() {
          directoryLoading = false;
          selectorError = '$e';
        });
      }
    }
  }

  void workspaceChanged() {
    final w = workspace;
    if (!mounted || w == null) return;
    if (serverSwitchLocation != null && w.server != null) {
      // The app-root URI already owns the accepted switch. Controller
      // hydration notifications cannot publish its temporary default channel.
      setState(() {});
      appRouter.refresh();
      return;
    }
    if (w.server == null && !directoryLoading) {
      serverSwitchLocation = serverSwitchReturn = null;
      showServerSelector = true;
      if (chooserReturn != null &&
          !w.servers.any(
            (s) =>
                s.string('slug') ==
                chooserReturn!.pathSegments.elementAtOrNull(1),
          )) {
        chooserReturn = null;
      }
      content.bindWorkspace(null);
      appRouter.publish(Uri(path: '/'));
    } else if (!showServerSelector && w.server != null) {
      serverSurfaces[w.server!.id] = w.location.uri;
      final path = appRouter.currentConfiguration.path;
      final replace =
          path == '/' ||
          path != '/servers' &&
              publishedServerId == w.server!.id &&
              publishedWorkspaceIndex != null &&
              w.navigation.index <= publishedWorkspaceIndex!;
      appRouter.publish(w.location.uri, replace: replace);
      publishedServerId = w.server!.id;
      publishedWorkspaceIndex = w.navigation.index;
      final c = client,
          principal = client?.user?.id,
          serverId = w.server!.id,
          uri = w.location.uri,
          memoryKey = serverMemoryKey;
      unawaited(
        SharedPreferences.getInstance().then((prefs) async {
          if (!mounted ||
              !identical(client, c) ||
              client?.user?.id != principal ||
              serverSurfaces[serverId] != uri) {
            return;
          }
          await prefs.setString('$memoryKey.$serverId', uri.toString());
        }),
      );
    }
    setState(() {});
    appRouter.refresh();
  }

  void openServerSelector() {
    final w = workspace;
    if (w == null || client?.user == null) return;
    final request = ++rootRequest;
    serverSwitchLocation = serverSwitchReturn = null;
    chooserReturn = w.server == null ? null : w.location.uri;
    requestedLocation = Uri(path: '/');
    showServerSelector = true;
    selectingServer = false;
    selectorError = null;
    w.setForeground(false);
    content.bindWorkspace(null);
    sharing.onIncoming = null;
    final c = client, principal = client?.user?.id, memoryKey = serverMemoryKey;
    unawaited(
      SharedPreferences.getInstance().then((prefs) async {
        if (mounted &&
            request == rootRequest &&
            identical(c, client) &&
            client?.user?.id == principal) {
          await prefs.remove('$memoryKey.last');
        }
      }),
    );
    appRouter.publish(requestedLocation);
    setState(() {});
  }

  Future<void> receiveAppLocation(Uri location) async {
    requestedLocation = location;
    serverSwitchLocation = serverSwitchReturn = null;
    final w = workspace;
    if (w == null || directoryLoading) return;
    if (location.path == '/' || location.path == '/servers') {
      openServerSelector();
      appRouter.publish(location);
      return;
    }
    final segments = location.pathSegments;
    final target = segments.length >= 2 && segments.first == 's'
        ? w.servers.where((s) => s.string('slug') == segments[1]).firstOrNull
        : null;
    if (target == null) {
      openServerSelector();
      return;
    }
    await chooseServer(target, location: location);
  }

  Future<bool> returnFromSelector() async {
    final w = workspace, uri = serverSwitchReturn ?? chooserReturn;
    if ((!showServerSelector && serverSwitchLocation == null) ||
        w == null ||
        uri == null) {
      return false;
    }
    final target = w.servers
        .where((s) => s.string('slug') == uri.pathSegments.elementAtOrNull(1))
        .firstOrNull;
    if (target == null) return false;
    if (serverSwitchLocation != null) {
      serverSwitchLocation = uri;
      serverSwitchReturn = null;
      appRouter.publish(uri, replace: true);
      setState(() {});
    }
    await chooseServer(target, location: uri);
    return true;
  }

  /// ServerSwitcherMenu.tsx310–324 publishes one accepted route before the
  /// server resolver changes context; mobile explicitly discards old memory.
  Future<void> switchServerFromMenu(
    RaftRecord selected,
    bool replaceWithHome,
  ) async {
    final w = workspace, c = client;
    if (w == null ||
        c?.user == null ||
        w.server?.id == selected.id ||
        !w.servers.any((s) => s.id == selected.id)) {
      return;
    }
    final request = ++rootRequest, principal = c!.user!.id;
    bool current() =>
        mounted &&
        request == rootRequest &&
        identical(client, c) &&
        identical(workspace, w) &&
        c.user?.id == principal &&
        w.servers.any((s) => s.id == selected.id);
    final before = w.location.uri;
    final prefs = await SharedPreferences.getInstance();
    if (!current()) return;
    final remembered =
        serverSurfaces[selected.id]?.toString() ??
        prefs.getString('$serverMemoryKey.${selected.id}');
    var uri = Uri(path: '/s/${selected.string('slug')}');
    if (!replaceWithHome && remembered != null) {
      final candidate = Uri.tryParse(remembered);
      if (candidate != null &&
          !candidate.hasScheme &&
          !candidate.hasAuthority &&
          candidate.pathSegments.length >= 2 &&
          candidate.pathSegments[0] == 's' &&
          candidate.pathSegments[1] == selected.string('slug')) {
        try {
          uri = RaftLocation.fromUri(candidate).uri;
        } on ArgumentError {
          /* Invalid persisted surfaces fall back to the server root. */
        }
      }
    }
    serverSwitchReturn = replaceWithHome ? null : before;
    serverSwitchLocation = uri;
    requestedLocation = uri;
    w.setForeground(false);
    content.bindWorkspace(null);
    sharing.onIncoming = null;
    appRouter.publish(uri, replace: replaceWithHome);
    setState(() {});
    // Browser history changes synchronously before resolver effects. Flutter
    // reports through the engine after a frame; retain this first PUSH even
    // when cached hydration immediately redirects the server root with REPLACE.
    await WidgetsBinding.instance.endOfFrame;
    if (!current()) return;
    await chooseServer(
      selected,
      location: uri,
      resolveDesktopRoot:
          !replaceWithHome &&
          (uri.path == '/s/${selected.string('slug')}' ||
              uri.path == '/s/${selected.string('slug')}/'),
    );
  }

  Future<void> chooseServer(
    RaftRecord selected, {
    Uri? location,
    bool resolveDesktopRoot = false,
  }) async {
    final w = workspace, c = client;
    if (w == null ||
        c?.user == null ||
        !w.servers.any((s) => s.id == selected.id)) {
      return;
    }
    final request = ++rootRequest, principal = c!.user!.id;
    bool current() =>
        mounted &&
        rootRequest == request &&
        identical(client, c) &&
        identical(workspace, w) &&
        c.user?.id == principal;
    setState(() {
      selectingServer = true;
      selectorError = null;
    });
    try {
      await w.flushCache();
      if (!current() || !w.servers.any((s) => s.id == selected.id)) return;
      if (w.server?.id != selected.id) {
        // A server with an on-device workspace opens as soon as that cache
        // is painted; its fresh channels and page revalidate in place.
        final hydrated = Completer<void>();
        final selecting = w.selectServer(
          selected,
          onHydrated: () {
            if (!hydrated.isCompleted) hydrated.complete();
          },
        );
        final settled = await Future.any([
          hydrated.future.then((_) => false),
          selecting.then((_) => true),
        ]);
        if (!settled) {
          unawaited(
            selecting.then<void>(
              (_) {},
              onError: (Object e) {
                if (current()) w.setError('$e');
              },
            ),
          );
        }
      }
      if (!current() ||
          w.server?.id != selected.id ||
          !w.servers.any((s) => s.id == selected.id)) {
        return;
      }
      var uri = location ?? serverSurfaces[selected.id];
      // MainLayout DefaultRoute914–947 redirects a desktop server root to the
      // first actual channel with REPLACE. Mobile deliberately stays Home.
      if (resolveDesktopRoot && w.channels.isNotEmpty) {
        final channel = w.channels.first;
        uri = RaftLocation.at(
          serverSlug: selected.string('slug'),
          route: RaftRoute.channel,
          entityId: channel.id,
        ).uri;
        if (w.channel?.id != channel.id) {
          await w.selectChannel(channel, navigate: false);
        }
        if (!current()) return;
        appRouter.publish(uri, replace: true);
      }
      if (uri != null &&
          uri.pathSegments.length >= 2 &&
          uri.pathSegments[1] == selected.string('slug')) {
        w.bindNavigation();
        w.navigation.navigate(
          RaftLocation.fromUri(uri),
          kind: RaftNavigationKind.replace,
        );
      }
      showServerSelector = false;
      serverSwitchLocation = serverSwitchReturn = null;
      chooserReturn = null;
      directoryLoading = false;
      content.bindWorkspace(w);
      workspaceChanged();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (current() && !showServerSelector && w.server?.id == selected.id) {
          w.setForeground(
            WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused,
          );
        }
      });
      final prefs = await SharedPreferences.getInstance();
      if (current()) {
        await prefs.setString('$serverMemoryKey.last', selected.string('slug'));
      }
    } catch (e) {
      if (current()) setState(() => selectorError = '$e');
    } finally {
      if (current()) setState(() => selectingServer = false);
    }
  }

  Future<void> createServer(String name, String slug) async {
    final w = workspace, c = client;
    if (w == null || c?.user == null || selectingServer) return;
    final request = ++rootRequest, principal = c!.user!.id;
    bool current() =>
        mounted &&
        request == rootRequest &&
        identical(client, c) &&
        identical(workspace, w) &&
        c.user?.id == principal &&
        showServerSelector;
    setState(() {
      selectingServer = true;
      selectorError = null;
    });
    try {
      final data = await c.post('/servers', data: {'name': name, 'slug': slug});
      if (!current()) return;
      final returned = RaftRecord(Map<String, dynamic>.from(data));
      if (returned.id.isEmpty) {
        throw const RaftApiException('The server response is incomplete.');
      }
      if (!await w.loadServerDirectory() || !current()) return;
      final created = w.servers.where((s) => s.id == returned.id).firstOrNull;
      if (created == null) {
        throw const RaftApiException(
          'The created server is no longer available.',
        );
      }
      await chooseServer(created);
    } catch (e) {
      if (current()) setState(() => selectorError = '$e');
    } finally {
      if (current()) setState(() => selectingServer = false);
    }
  }

  Widget sessionHome() {
    final active = client;
    if (active?.user == null) {
      return AuthView(
        origin: origin,
        bootError: bootError,
        onLogin: login,
        onRegister: register,
        onOAuth: completeOAuth,
      );
    }
    if (accountNeedsOnboarding(active!.user)) {
      return AccountOnboardingView(
        client: active,
        onComplete: () => finishOnboarding(active),
        onSignOut: logout,
      );
    }
    if (workspace == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (showServerSelector) {
      return GlobalServerSelector(
        key: ValueKey('selector-${active.user!.id}'),
        servers: workspace!.servers,
        user: active.user!,
        loading: directoryLoading || selectingServer,
        error: selectorError,
        onSelect: chooseServer,
        onCreate: createServer,
        onLogout: logout,
        onRetry: discoverServers,
      );
    }
    if (serverSwitchLocation != null) {
      return RaftServerResolutionBody(
        key: const Key('server-resolution-loading'),
        label: selectorError ?? 'Loading...',
      );
    }
    return WorkspaceView(
      controller: workspace!,
      appearance: appearance,
      onAppearance: setAppearance,
      onLogout: logout,
      onChooseServer: openServerSelector,
      onSwitchServer: switchServerFromMenu,
      notifications: content.notifications,
      sharing: sharing,
    );
  }

  void watchSession(RaftClient c) {
    final principal = c.user!.id;
    sessionEvents?.cancel();
    sessionEvents = c.events.listen((e) {
      if (e.name == 'account:updated' && mounted && identical(c, client)) {
        if (c.user?.id != principal) {
          // An account record cannot transfer the old workspace's private
          // projections to another principal, even on the same client object.
          unawaited(logout(previousPrincipal: principal));
          return;
        }
        if (accountNeedsOnboarding(c.user)) {
          rootRequest++;
          workspace?.setForeground(false);
          content.bindWorkspace(null);
        }
        setState(() {});
      }
      if (mounted &&
          identical(c, client) &&
          (e.name == 'server:membership-removed' ||
              e.name == 'server:member-updated' &&
                  e.payload is Map &&
                  e.payload['userId'] == principal)) {
        // The workspace reducer owns the actual authority projection. The app
        // root only retires its pending directory/create/selection completion.
        rootRequest++;
        if (selectingServer) {
          selectingServer = false;
          selectorError =
              'Server membership changed. Choose an available server again.';
        }
        if (directoryLoading) unawaited(discoverServers());
        setState(() {});
      }
      if (e.name == 'session:ended' && mounted && identical(c, client)) {
        authAttempt++;
        rootRequest++;
        sharing.onIncoming = null;
        final flushed = workspace?.flushCache() ?? Future<void>.value();
        final servers = <String>[
          for (final s in workspace?.servers ?? const <RaftRecord>[]) s.id,
        ];
        flushed.then((_) => cache?.clearAccount(c.origin, principal));
        unawaited(
          AttachmentImageDiskCache.purgeAccount(c.origin, principal, servers),
        );
        content.bindWorkspace(null);
        workspace?.removeListener(workspaceChanged);
        workspace?.dispose();
        workspace = null;
        serverSurfaces.clear();
        chooserReturn = null;
        serverSwitchLocation = serverSwitchReturn = null;
        showServerSelector = true;
        appRouter.publish(Uri(path: '/'));
        client = null;
        setState(() {});
      }
    });
  }

  Future<void> logout({String? previousPrincipal}) async {
    authAttempt++;
    rootRequest++;
    content.bindWorkspace(null);
    sharing.onIncoming = null;
    final c = client, oldWorkspace = workspace;
    final principal = previousPrincipal ?? c?.user?.id;
    final clearSession = c == null
        ? Future<void>.value()
        : sessionPersistence.write(c.origin, null);
    workspace = null;
    oldWorkspace?.removeListener(workspaceChanged);
    serverSurfaces.clear();
    chooserReturn = null;
    serverSwitchLocation = serverSwitchReturn = null;
    showServerSelector = true;
    appRouter.publish(Uri(path: '/'));
    client = null;
    sessionEvents?.cancel();
    if (mounted) setState(() {});
    await oldWorkspace?.flushCache();
    if (c != null && principal != null) {
      await cache?.clearAccount(c.origin, principal);
      // Cached image bytes of this account go with its other cached data.
      await AttachmentImageDiskCache.purgeAccount(c.origin, principal, [
        for (final s in oldWorkspace?.servers ?? const <RaftRecord>[]) s.id,
      ]);
    }
    await c?.logout();
    await clearSession;
    oldWorkspace?.dispose();
    if (oldWorkspace == null) await c?.dispose();
  }

  Future<void> setAppearance(RaftAppearance value) async {
    setState(() => appearance = value);
    final p = await SharedPreferences.getInstance();
    await p.setString('raft.mode', value.mode.name);
    await p.setString('raft.light', value.light.name);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    workspace?.setForeground(
      state == AppLifecycleState.resumed &&
          !showServerSelector &&
          serverSwitchLocation == null,
    );
    if (state == AppLifecycleState.resumed) {
      unawaited(content.notifications.refreshPermission());
      final w = workspace;
      if (w == null) return;
      w.resumeLiveSession();
    }
  }

  @override
  void dispose() {
    authAttempt++;
    rootRequest++;
    unawaited(sharing.dispose());
    WidgetsBinding.instance.removeObserver(this);
    unawaited(content.dispose());
    sessionEvents?.cancel();
    final flushed = workspace?.flushCache() ?? Future<void>.value();
    if (workspace != null) {
      workspace!.removeListener(workspaceChanged);
      workspace!.dispose();
    } else {
      client?.dispose();
    }
    flushed.whenComplete(() async {
      await cache?.close();
      sessionOwner.release();
    });
    routeInformation.dispose();
    appRouter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    privateRoutes.scopeChanged(
      '${client?.generation}|${client?.user?.id}',
      domain: 'account',
    );
    return MaterialApp.router(
      title: 'Raft',
      routerDelegate: appRouter,
      routeInformationParser: const RaftAppRouteParser(),
      routeInformationProvider: routeInformation,
      locale: displayLocale(client?.user?.string('displayLanguage')),
      supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => RepaintBoundary(
        key: raftScreenshotKey,
        child: RaftTooltipProvider(
          delay: const Duration(milliseconds: 600),
          child: RaftViewportBreakpointScope(
            // Resolves the theme's font combinations once the app is idle.
            child: RaftFontWarmUpScope(child: RaftSystemBars(child: child!)),
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      theme: raftTheme(
        appearance.light,
        systemFonts: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
      ),
      darkTheme: raftTheme(
        RaftFamily.elegant,
        dark: true,
        systemFonts: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
      ),
      themeMode: appearance.mode,
    );
  }
}
