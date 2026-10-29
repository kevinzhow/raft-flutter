import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:raft_client/system_proxy.dart';
import 'package:raft_ui/raft_ui.dart';

import '../platform/proxy_settings_store.dart';

/// Settings > Resources > Network (native only; Web uses the browser's proxy).
///
/// Three choices: follow the system proxy (default), a manual HTTP proxy with
/// optional Basic credentials and a bypass list, or no proxy. The effective
/// state is shown live, and "Test connection" sends one request to the API
/// origin through the proxy the form describes.
class NetworkSettingsPage extends StatefulWidget {
  const NetworkSettingsPage({
    super.key,
    required this.origin,
    this.proxy,
    this.store,
    this.probe,
  });

  /// The API origin the test request goes to.
  final String origin;
  final SystemProxy? proxy;
  final ProxySettingsStore? store;

  /// Test hook for the connection test.
  final Future<NetworkProbeResult> Function(SystemProxy proxy, Uri url)? probe;

  @override
  State<NetworkSettingsPage> createState() => _NetworkSettingsPageState();
}

const _portFieldWidth = 112.0;

/// Outcome of one "Test connection".
class NetworkProbeResult {
  const NetworkProbeResult.ok(this.statusCode) : error = null;
  const NetworkProbeResult.failed(this.error) : statusCode = null;
  final int? statusCode;

  /// `proxy-auth`, `timeout`, or `connect`.
  final String? error;
  bool get ok => error == null;
}

Future<NetworkProbeResult> probeThroughProxy(SystemProxy proxy, Uri url) async {
  final dio = createProxiedDio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      validateStatus: (_) => true,
      followRedirects: false,
    ),
    proxy: proxy,
  );
  try {
    final response = await dio.head<void>(url.toString());
    final code = response.statusCode ?? 0;
    if (code == 407) return const NetworkProbeResult.failed('proxy-auth');
    return NetworkProbeResult.ok(code);
  } on DioException catch (error) {
    // ignore: raft_lints/avoid_caught_exception_text -- Matched against "407" / "proxy authentication" to classify the probe failure; the result shown is one of three fixed sentences.
    final text = '${error.error}'.toLowerCase();
    if (text.contains('407') || text.contains('proxy authentication')) {
      return const NetworkProbeResult.failed('proxy-auth');
    }
    return NetworkProbeResult.failed(
      error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout
          ? 'timeout'
          : 'connect',
    );
  } catch (_) {
    return const NetworkProbeResult.failed('connect');
  } finally {
    dio.close(force: true);
  }
}

class _NetworkSettingsPageState extends State<NetworkSettingsPage> {
  late final SystemProxy proxy = widget.proxy ?? SystemProxy.instance;
  late final ProxySettingsStore store = widget.store ?? ProxySettingsStore();
  late ProxyMode mode = proxy.settings.mode;
  late final host = TextEditingController(text: proxy.settings.host);
  late final port = TextEditingController(
    text: proxy.settings.port > 0 ? '${proxy.settings.port}' : '',
  );
  late final user = TextEditingController(text: proxy.settings.username);
  final password = TextEditingController();
  late final bypass = TextEditingController(
    text: proxy.settings.bypass.join(', '),
  );
  StreamSubscription<void>? changes;
  bool hasStoredPassword = false;
  bool saving = false, saved = false, testing = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Clears when any proxy field is edited (touch), when a save/test starts, and on dispose.
  String? formError;
  NetworkProbeResult? probeResult;
  Uri? probedUrl;

  @override
  void initState() {
    super.initState();
    changes = proxy.changes.listen((_) {
      if (mounted) setState(() {});
    });
    unawaited(proxy.refresh());
    unawaited(
      store.hasPassword().then((value) {
        if (mounted) setState(() => hasStoredPassword = value);
      }),
    );
  }

  @override
  void dispose() {
    changes?.cancel();
    for (final c in [host, port, user, password, bypass]) {
      c.dispose();
    }
    super.dispose();
  }

  Uri get apiUrl =>
      Uri.tryParse(widget.origin) ?? Uri.parse('https://example.com');

  ProxySettings draft() {
    final typed = password.text;
    return ProxySettings(
      mode: mode,
      host: host.text.trim(),
      port: int.tryParse(port.text.trim()) ?? 0,
      username: user.text.trim(),
      // A blank field keeps the stored password (it is never shown again).
      password: typed.isNotEmpty ? typed : proxy.settings.password,
      bypass: parseBypassList(bypass.text),
    );
  }

  /// Why [draft] cannot be saved, as an English catalog key, or null.
  String? problem(ProxySettings s) {
    if (s.mode != ProxyMode.manual) return null;
    if (s.host.isEmpty) return 'Enter the proxy host.';
    if (s.host.contains(RegExp(r'[\s/;@]'))) {
      return 'The proxy host is not valid.';
    }
    if (!s.hasManualTarget) return 'Enter a port between 1 and 65535.';
    return switch (s.credentialsProblem) {
      'username-colon' => 'The username cannot contain a colon.',
      'semicolon' => 'The username and password cannot contain a semicolon.',
      'whitespace' =>
        'The username and password cannot start or end with a space.',
      'password-empty' =>
        'Enter a password, or clear the username to use no credentials.',
      _ => null,
    };
  }

  void touch(VoidCallback change) => setState(() {
    change();
    saved = false;
    formError = null;
    probeResult = null;
  });

  Future<void> save() async {
    final s = draft();
    final bad = problem(s);
    if (bad != null) {
      setState(() => formError = bad);
      return;
    }
    setState(() {
      saving = true;
      formError = null;
    });
    final typed = password.text.isNotEmpty;
    try {
      await store.save(s, keepPassword: !typed && s.username.isNotEmpty);
      proxy.configure(s);
      password.clear();
      final stored = s.username.isNotEmpty && (typed || hasStoredPassword);
      if (mounted) {
        setState(() {
          saved = true;
          hasStoredPassword = stored;
        });
      }
    } catch (_) {
      if (mounted) setState(() => formError = 'The proxy could not be saved.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> test() async {
    final s = draft();
    final bad = problem(s);
    if (bad != null) {
      setState(() => formError = bad);
      return;
    }
    // The request follows the form, saved or not: a scratch service for a
    // manual draft, the live one for the system / direct choices.
    final SystemProxy target;
    if (s.mode == ProxyMode.manual) {
      target = SystemProxy(resolver: const NoSystemProxyResolver())
        ..configure(s);
    } else if (s.mode == proxy.settings.mode) {
      target = proxy;
    } else {
      target = SystemProxy(resolver: const NoSystemProxyResolver())
        ..configure(s);
    }
    setState(() {
      testing = true;
      probeResult = null;
      formError = null;
    });
    final url = apiUrl.replace(path: '/');
    final result = await (widget.probe ?? probeThroughProxy)(target, url);
    if (!mounted) return;
    setState(() {
      testing = false;
      probeResult = result;
      probedUrl = url;
    });
  }

  String statusText(BuildContext context) {
    String f(String key, Map<String, Object?> values) =>
        raftFormat(context, key, values);
    final live = proxy.settings;
    final status = proxy.status(apiUrl);
    if (live.mode == ProxyMode.direct) {
      return raftText(context, 'No proxy: connecting directly.');
    }
    if (live.mode == ProxyMode.manual) {
      if (!live.hasManualTarget) {
        return raftText(
          context,
          'The manual proxy is incomplete: connecting directly.',
        );
      }
      return f(
        status.hasCredentials
            ? 'Manual HTTP proxy {proxy} (with sign-in).'
            : 'Manual HTTP proxy {proxy}.',
        {'proxy': '${live.host.trim()}:${live.port}'},
      );
    }
    if (status.socksOnly) {
      return raftText(
        context,
        'The system uses a SOCKS proxy, which is not supported: connecting directly. Only HTTP proxies are supported.',
      );
    }
    if (status.pacUnsupported) {
      return raftText(
        context,
        'The system uses an automatic proxy script that this device cannot run: connecting directly.',
      );
    }
    final via = status.proxy;
    return switch (status.source) {
      ProxySource.environment when via != null => f(
        'Proxy from the environment: {proxy}.',
        {'proxy': via},
      ),
      ProxySource.pac when via != null => f('System proxy script: {proxy}.', {
        'proxy': via,
      }),
      ProxySource.pac => raftText(
        context,
        'System proxy script: this address is reached directly.',
      ),
      _ when via != null => f('System HTTP proxy {proxy}.', {'proxy': via}),
      _ => raftText(context, 'The system has no proxy: connecting directly.'),
    };
  }

  String probeText(BuildContext context) {
    final r = probeResult!;
    if (r.ok) {
      return raftFormat(context, 'Connected to {host} (HTTP {code}).', {
        'host': probedUrl?.host ?? '',
        'code': r.statusCode,
      });
    }
    return raftText(context, probeError(r.error));
  }

  static String probeError(String? error) => switch (error) {
    'proxy-auth' => 'The proxy rejected the username or password.',
    'timeout' => 'The connection timed out.',
    _ => 'Could not connect through this proxy.',
  };

  @override
  Widget build(BuildContext context) {
    final manual = mode == ProxyMode.manual;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RaftSettingsSectionHeader(
          label: 'Network',
          glyph: RaftGlyph.network,
        ),
        RaftSettingsCard(
          child: RaftSettingsPreference(
            title: 'Proxy',
            description: 'Choose how Raft reaches the network. Only HTTP proxies are supported.',
            child: RaftSegmentedControl<ProxyMode>(
              legacyStyle: RaftSegmentedStyle.tabs,
              value: mode,
              label: 'Proxy',
              items: [
                RaftSegmentedOption(
                  value: ProxyMode.system,
                  label: raftText(context, 'Use System Proxy'),
                  itemKey: const Key('network-mode-system'),
                ),
                RaftSegmentedOption(
                  value: ProxyMode.manual,
                  label: raftText(context, 'Manual Setup'),
                  itemKey: const Key('network-mode-manual'),
                ),
                RaftSegmentedOption(
                  value: ProxyMode.direct,
                  label: raftText(context, 'No Proxy'),
                  itemKey: const Key('network-mode-direct'),
                ),
              ],
              onChanged: (value) => touch(() => mode = value),
            ),
          ),
        ),
        if (manual) ...[
          const SizedBox(height: RaftSpace.x4),
          RaftSettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: RaftSettingsField(
                        label: 'HTTP proxy host',
                        child: RaftRecipeInput(
                          fieldKey: const Key('network-host'),
                          controller: host,
                          placeholder: 'proxy.example.com',
                          onChanged: (_) => touch(() {}),
                        ),
                      ),
                    ),
                    const SizedBox(width: RaftSpace.x3),
                    SizedBox(
                      width: _portFieldWidth,
                      child: RaftSettingsField(
                        label: 'Port',
                        child: RaftRecipeInput(
                          fieldKey: const Key('network-port'),
                          controller: port,
                          placeholder: '8080',
                          numeric: true,
                          maxLength: 5,
                          onChanged: (_) => touch(() {}),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: RaftSpace.x3),
                RaftSettingsField(
                  label: 'Username (optional)',
                  child: RaftRecipeInput(
                    fieldKey: const Key('network-user'),
                    controller: user,
                    onChanged: (_) => touch(() {}),
                  ),
                ),
                const SizedBox(height: RaftSpace.x3),
                RaftSettingsField(
                  label: 'Password (optional)',
                  child: RaftRecipeInput(
                    fieldKey: const Key('network-password'),
                    controller: password,
                    obscure: true,
                    placeholder: hasStoredPassword
                        ? raftText(context, 'Saved. Leave blank to keep it.')
                        : null,
                    onChanged: (_) => touch(() {}),
                  ),
                ),
                const SizedBox(height: RaftSpace.x3),
                RaftSettingsField(
                  label: 'No-proxy list',
                  child: RaftRecipeInput(
                    fieldKey: const Key('network-bypass'),
                    controller: bypass,
                    placeholder: '*.internal.example, 10.0.0.0/8',
                    onChanged: (_) => touch(() {}),
                  ),
                ),
                const SizedBox(height: RaftSpace.x2),
                Text(
                  raftText(
                    context,
                    'Addresses on this device are never sent through the proxy. The password is stored in the secure storage of this device and sent only to the proxy.',
                  ),
                  style: RaftSettingsText(RaftTokens.of(context)).description,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: RaftSpace.x4),
        RaftSettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RaftSettingsPreference(
                title: 'Current status',
                error: formError == null ? null : raftText(context, formError!),
                child: Semantics(
                  key: const Key('network-status'),
                  container: true,
                  child: Text(
                    statusText(context),
                    style: RaftSettingsText(RaftTokens.of(context)).description,
                  ),
                ),
              ),
              const SizedBox(height: RaftSpace.x3),
              Wrap(
                spacing: RaftSpace.x2,
                runSpacing: RaftSpace.x2,
                children: [
                  RaftSettingsRecipeButton(
                    key: const Key('network-save'),
                    label: saving ? 'Saving…' : 'Save',
                    variant: RaftButtonRecipeVariant.primary,
                    onPressed: saving ? null : save,
                  ),
                  RaftSettingsRecipeButton(
                    key: const Key('network-test'),
                    label: testing ? 'Testing…' : 'Test Connection',
                    onPressed: testing ? null : test,
                  ),
                ],
              ),
              if (saved) ...[
                const SizedBox(height: RaftSpace.x3),
                RaftSettingsSavedNote(raftText(context, 'Saved.')),
              ],
              if (probeResult != null) ...[
                const SizedBox(height: RaftSpace.x3),
                if (probeResult!.ok)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      probeText(context),
                      key: const Key('network-test-result'),
                      style: RaftSettingsText(RaftTokens.of(context))
                          .description,
                    ),
                  )
                else
                  // A failed probe is an error row like every other settings
                  // failure: the warning Banner, density sm.
                  KeyedSubtree(
                    key: const Key('network-test-result'),
                    child: RaftErrorBanner(
                      probeError(probeResult!.error),
                      small: true,
                      bold: true,
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: RaftSpace.x6),
      ],
    );
  }
}
