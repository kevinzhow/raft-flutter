import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/workspace_controller.dart';
import 'data/source_time_formatter.dart';
import 'data/workspace_cache.dart';
import 'features/workspace_view.dart';
import 'features/auth_view.dart';
import 'features/account_onboarding.dart';
import 'features/private_route_guard.dart';
import 'platform/session_store.dart';
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
  });
  final List<String> initialArguments;
  final SessionStore? sessionStore;
  @override
  State<RaftApp> createState() => _RaftAppState();
}

class _RaftAppState extends State<RaftApp> with WidgetsBindingObserver {
  final content = NativeContentCoordinator();
  final sharing = NativeSharing();
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
      origin = p.getString('raft.origin') ?? origin;
      appearance = RaftAppearance(
        mode: ThemeMode.values.byName(p.getString('raft.mode') ?? 'system'),
        light: RaftFamily.values.byName(p.getString('raft.light') ?? 'brutal'),
      );
      cache = await DriftWorkspaceCache.open();
      if (!mounted) {
        await cache!.close();
        return;
      }
      late final RaftClient c;
      c = RaftClient(
        origin: origin,
        sessionStore: sessionPersistence.guarded(
          () => mounted && identical(client, c),
        ),
        clientKind:
            defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS
            ? 'mobile'
            : 'desktop',
      );
      client = c;
      if (await c.restore()) {
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
    candidate = RaftClient(
      origin: base.trim(),
      sessionStore: sessionPersistence.guarded(
        () =>
            mounted && (attempt == authAttempt || identical(client, candidate)),
      ),
      clientKind:
          defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS
          ? 'mobile'
          : 'desktop',
    );
    return candidate;
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
      oldWorkspace?.dispose();
      if (oldWorkspace == null) await oldClient?.dispose();
      if (!current()) {
        await c.dispose();
        return;
      }
      workspace = null;
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
    setState(() {});
    await next.bootstrap();
    if (mounted && identical(c, client) && identical(next, workspace)) {
      content.bindWorkspace(next);
      setState(() {});
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
    return WorkspaceView(
      controller: workspace!,
      appearance: appearance,
      onAppearance: setAppearance,
      onLogout: logout,
      notifications: content.notifications,
      sharing: sharing,
    );
  }

  void watchSession(RaftClient c) {
    final principal = c.user!.id;
    sessionEvents?.cancel();
    sessionEvents = c.events.listen((e) {
      if (e.name == 'account:updated' && mounted && identical(c, client)) {
        setState(() {});
      }
      if (e.name == 'session:ended' && mounted && identical(c, client)) {
        authAttempt++;
        sharing.onIncoming = null;
        final flushed = workspace?.flushCache() ?? Future<void>.value();
        flushed.then((_) => cache?.clearAccount(c.origin, principal));
        content.bindWorkspace(null);
        workspace?.dispose();
        workspace = null;
        client = null;
        setState(() {});
      }
    });
  }

  Future<void> logout() async {
    authAttempt++;
    content.bindWorkspace(null);
    sharing.onIncoming = null;
    final c = client, oldWorkspace = workspace;
    final principal = c?.user?.id;
    final clearSession = c == null
        ? Future<void>.value()
        : sessionPersistence.write(c.origin, null);
    workspace = null;
    client = null;
    sessionEvents?.cancel();
    if (mounted) setState(() {});
    await oldWorkspace?.flushCache();
    if (c != null && principal != null) {
      await cache?.clearAccount(c.origin, principal);
    }
    await c?.logout();
    await clearSession;
    oldWorkspace?.dispose();
    await c?.dispose();
  }

  Future<void> setAppearance(RaftAppearance value) async {
    setState(() => appearance = value);
    final p = await SharedPreferences.getInstance();
    await p.setString('raft.mode', value.mode.name);
    await p.setString('raft.light', value.light.name);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    workspace?.setForeground(state == AppLifecycleState.resumed);
    if (state == AppLifecycleState.resumed) {
      unawaited(content.notifications.refreshPermission());
      final w = workspace;
      if (w == null) return;
      w.client.recoverConnection(w.ledger.watermark);
      w.refreshChannels();
      w.refreshUnread();
    }
  }

  @override
  void dispose() {
    authAttempt++;
    unawaited(sharing.dispose());
    WidgetsBinding.instance.removeObserver(this);
    unawaited(content.dispose());
    sessionEvents?.cancel();
    final flushed = workspace?.flushCache() ?? Future<void>.value();
    if (workspace != null) {
      workspace!.dispose();
    } else {
      client?.dispose();
    }
    flushed.whenComplete(() async {
      await cache?.close();
      sessionOwner.release();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    privateRoutes.scopeChanged(
      '${client?.generation}|${client?.user?.id}',
      domain: 'account',
    );
    return MaterialApp(
      title: 'Raft',
      navigatorObservers: [privateRoutes],
      locale: displayLocale(client?.user?.string('displayLanguage')),
      supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => RepaintBoundary(
        key: raftScreenshotKey,
        child: RaftTooltipProvider(
          delay: const Duration(milliseconds: 600),
          child: RaftSystemBars(child: child!),
        ),
      ),
      debugShowCheckedModeBanner: false,
      theme: raftTheme(appearance.light),
      darkTheme: raftTheme(RaftFamily.elegant, dark: true),
      themeMode: appearance.mode,
      home: restoring
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : sessionHome(),
    );
  }
}
