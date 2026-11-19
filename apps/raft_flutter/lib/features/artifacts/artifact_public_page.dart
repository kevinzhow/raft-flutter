import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../../data/device_preferences.dart';
import '../../platform/content_links.dart';
import '../../platform/macos_voice_over.dart';
import 'artifact_api.dart';
import 'artifact_content.dart';
import 'artifact_find_bar.dart';
import 'artifact_frame_bridge.dart';
import 'artifact_frame_confirm.dart';
import 'artifact_frame_view.dart';
import 'artifact_models.dart';
import 'artifact_open_in_browser.dart';

String? publicArtifactRoute(Uri location, String apiOrigin) {
  final web = ContentLinks.originFor(apiOrigin);
  if (location.hasAuthority &&
      ((location.scheme != 'https' && location.scheme != 'http') ||
          location.userInfo.isNotEmpty ||
          location.origin != web.origin)) {
    return null;
  }
  if (location.hasScheme && !location.hasAuthority) return null;
  final segments = location.pathSegments;
  if (segments.isEmpty || segments.first != 'artifacts') return null;
  if (segments.length == 2) return parseArtifactId(segments[1]);
  if (segments.length == 4 &&
      segments[2] == 'v' &&
      (int.tryParse(segments[3]) ?? 0) > 0) {
    return parseArtifactId(segments[1]);
  }
  return null;
}

class ArtifactPublicPage extends StatefulWidget {
  const ArtifactPublicPage({
    super.key,
    required this.client,
    required this.id,
    required this.onBack,
    required this.onSignIn,
  });

  final RaftClient client;
  final String id;
  final VoidCallback onBack, onSignIn;

  @override
  State<ArtifactPublicPage> createState() => _ArtifactPublicPageState();
}

class _ArtifactPublicPageState extends State<ArtifactPublicPage> {
  static const promptKey = 'raft.artifacts.publicBannerDismissed';
  late final path = '/public/artifacts/${Uri.encodeComponent(widget.id)}';
  final controller = ArtifactFrameController();
  final panelFocus = FocusNode();
  final voiceOver = MacosVoiceOver.instance;
  ({String title, ArtifactKind kind, int version})? view;
  ArtifactDeployment? deployment;
  String? entry;
  bool showPhonePrompt = DevicePreferences.current?.get(promptKey) != '1';
  bool loading = true;
  bool finding = false;
  int findRequests = 0;

  bool get canFrame => WebViewPlatform.instance != null && !voiceOver.value;
  bool get canFind => canFrame && controller.ready;

  @override
  void initState() {
    super.initState();
    controller.addListener(frameChanged);
    voiceOver.addListener(frameChanged);
    unawaited(load());
  }

  @override
  void dispose() {
    voiceOver.removeListener(frameChanged);
    panelFocus.dispose();
    controller.dispose();
    super.dispose();
  }

  void frameChanged() {
    if (!mounted) return;
    setState(() {
      if (findRequests != controller.findRequests) {
        findRequests = controller.findRequests;
        finding = canFind;
      }
    });
  }

  void openFind() {
    if (canFind) setState(() => finding = true);
  }

  void closeFind() {
    setState(() => finding = false);
    panelFocus.requestFocus();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final body = await widget.client.request('GET', path, authorized: false);
      if (!mounted) return;
      if (body is! Map || body['title'] is! String || body['version'] is! Map) {
        throw const FormatException('Invalid public Artifact response.');
      }
      final version = body['version']['number'];
      if (version is! int) {
        throw const FormatException('Invalid public Artifact version.');
      }
      final kind = ArtifactKind.parse(body['kind']);
      final host = kind.framed && WebViewPlatform.instance != null
          ? await ArtifactDeployment.of(widget.client)
          : null;
      final file = artifactDrawnKind(kind) ? await readEntry(kind) : null;
      if (!mounted) return;
      setState(() {
        view = (title: body['title'] as String, kind: kind, version: version);
        deployment = host;
        entry = file;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      if (error is RaftApiException && error.status == 404) {
        widget.onSignIn();
        return;
      }
      setState(() => loading = false);
    }
  }

  Future<bool> browser(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  Future<String?> readEntry(ArtifactKind kind) async {
    try {
      final metadata = await widget.client.request(
        'GET',
        '$path/meta',
        authorized: false,
      );
      if (metadata is! Map ||
          metadata['entry'] is! String ||
          metadata['files'] is! List) {
        return null;
      }
      final entry = metadata['entry'] as String;
      final segments = entry.split('/');
      if (segments.any(
        (segment) => segment.isEmpty || segment == '.' || segment == '..',
      )) {
        return null;
      }
      final limit = kind == ArtifactKind.image ? 8 * 1024 * 1024 : 1024 * 1024;
      return (metadata['files'] as List).whereType<Map>().any(
            (file) =>
                file['path'] == entry &&
                file['size'] is int &&
                (file['size'] as int) <= limit,
          )
          ? entry
          : null;
    } catch (_) {
      return null;
    }
  }

  Uri get address =>
      artifactUrl(ContentLinks.originFor(widget.client.origin), widget.id);

  Future<void> copy(String value, String confirmation) async {
    try {
      await Clipboard.setData(ClipboardData(text: value));
      if (mounted) showRaftToast(context, raftText(context, confirmation));
    } catch (_) {
      if (mounted) showRaftToast(context, raftText(context, "Couldn't copy"));
    }
  }

  Future<void> openExternal(Uri uri) async {
    try {
      if (await browser(uri)) return;
    } catch (_) {}
    if (mounted) {
      showRaftToast(context, raftText(context, "Couldn't open link"));
    }
  }

  Widget publicActions(BuildContext context, {required bool compact}) {
    final prompt = raftFormat(
      context,
      'Read {url} and summarize it in a few sentences, then answer my questions about it.',
      {'url': address.toString()},
    );
    String text(String value) => raftText(context, value);
    return RaftDropdownMenu(
      surfaceKey: const Key('public-artifact-menu'),
      label: text('More'),
      kind: RaftMenuKind.dropdownMenu,
      align: RaftDropdownAlign.end,
      triggerBuilder: (context, focus, open) => RaftButton(
        key: const Key('public-artifact-more'),
        glyph: RaftGlyph.ellipsisVertical,
        tooltip: text('More'),
        semanticLabel: text('More'),
        focusNode: focus,
        tone: RaftButtonRecipeVariant.ghost,
        size: RaftButtonRecipeSize.iconLg,
        onPressed: open,
      ),
      entries: [
        RaftMenuEntry(
          label: text('Copy link'),
          onPressed: () => unawaited(copy(address.toString(), 'Link copied.')),
        ),
        if (compact && canFind)
          RaftMenuEntry(label: text('Find in page'), onPressed: openFind),
        if (compact && !showPhonePrompt)
          RaftMenuEntry(label: text('Sign in'), onPressed: widget.onSignIn),
        RaftMenuEntry(
          label: text('Copy for AI'),
          onPressed: () => unawaited(copy(prompt, 'Copied')),
        ),
        for (final (label, destination) in [
          ('Open in ChatGPT', Uri.https('chatgpt.com', '/', {'q': prompt})),
          ('Open in Claude', Uri.https('claude.ai', '/new', {'q': prompt})),
        ])
          RaftMenuEntry(
            label: text(label),
            trailing: const RaftIcon(RaftGlyph.arrowUpRight),
            onPressed: () => unawaited(openExternal(destination)),
          ),
        RaftMenuEntry(
          label: text('Report abuse'),
          onPressed: () => unawaited(
            openExternal(
              Uri(
                scheme: 'mailto',
                path: 'contact@raft.build',
                query:
                    'subject=${Uri.encodeComponent(text('Report an Artifact'))}'
                    '&body=${Uri.encodeComponent(address.toString())}',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget body(BuildContext context) {
    String text(String value) => raftText(context, value);
    final shown = view;
    if (loading) return const Center(child: RaftSpinner());
    if (shown == null) {
      return RaftEmptyState(
        glyph: RaftGlyph.fileText,
        title: text("Couldn't load this Artifact"),
        detail: '',
        action: RaftButton(label: text('Try again'), onPressed: load),
      );
    }
    final host = deployment;
    final tokens = RaftTokens.of(context);
    if (entry case final file?) {
      return ArtifactDrawnContent(
        kind: shown.kind,
        path: file,
        read: () => widget.client.getPublicBytes(
          '$path/files/${file.split('/').map(Uri.encodeComponent).join('/')}',
        ),
      );
    }
    if (!canFrame ||
        host == null ||
        host.contentDomain == null ||
        !shown.kind.framed) {
      return ArtifactOpenInBrowser(
        title: shown.title,
        pageUrl: address,
        open: browser,
      );
    }
    final failed =
        controller.status == ArtifactFrameStatus.error ||
        controller.status == ArtifactFrameStatus.fallback;
    return Stack(
      fit: StackFit.expand,
      children: [
        ArtifactFrameView(
          key: ValueKey(shown.version),
          artifactId: widget.id,
          version: shown.version,
          title: shown.title,
          appOrigin: host.webOrigin,
          contentDomain: host.contentDomain!,
          locate: () =>
              widget.client.request('POST', '$path/frame', authorized: false),
          host: ArtifactFrameHost(
            openLink: browser,
            copyText: (value) async {
              await Clipboard.setData(ClipboardData(text: value));
              if (context.mounted) showRaftToast(context, text('Link copied.'));
              return true;
            },
            comments: (_) async => false,
            confirm: (capability, args, title) => confirmArtifactFrameRequest(
              context,
              capability: capability,
              args: args,
              pageTitle: title,
            ),
          ),
          hostScript: artifactHostScript,
          controller: controller,
          dark: tokens.dark,
          theme: shown.kind == ArtifactKind.markdown
              ? artifactPageTheme(tokens.colors)
              : const {},
        ),
        if (failed)
          ArtifactOpenInBrowser(
            title: shown.title,
            pageUrl: address,
            open: browser,
          ),
        if (!failed && !controller.ready)
          const IgnorePointer(child: Center(child: RaftSpinner())),
      ],
    );
  }

  Future<void> dismissPrompt() async {
    setState(() => showPhonePrompt = false);
    try {
      await DevicePreferences.current?.setString(promptKey, '1');
    } catch (_) {}
  }

  Widget prompt(BuildContext context, {required bool compact}) {
    String text(String value) => raftText(context, value);
    final tokens = RaftTokens.of(context);
    final description = Text(
      text(
        'Get started in minutes. Sign up and build with your AI agents on Raft.',
      ),
      style: tokens.scale(
        tokens.typeSlot('body'),
        color: tokens.ui[compact ? 'info-strong' : 'foreground'],
      ),
    );
    final signIn = RaftButton(
      label: text('Sign up or sign in'),
      onPressed: widget.onSignIn,
    );
    if (!compact) {
      return ColoredBox(
        color: tokens.ui['fill-subtle'],
        child: Padding(
          padding: const EdgeInsets.all(RaftSpace.x2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: RaftSpace.x6,
            children: [
              Flexible(child: description),
              signIn,
            ],
          ),
        ),
      );
    }
    final dismiss = text('Dismiss');
    return ColoredBox(
      color: tokens.ui['info-soft'],
      child: Padding(
        padding: const EdgeInsets.all(RaftSpace.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: RaftSpace.x2,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: description),
                RaftButton(
                  key: const Key('public-artifact-dismiss-prompt'),
                  glyph: RaftGlyph.x,
                  tooltip: dismiss,
                  semanticLabel: dismiss,
                  tone: RaftButtonRecipeVariant.ghost,
                  size: RaftButtonRecipeSize.iconLg,
                  onPressed: dismissPrompt,
                ),
              ],
            ),
            signIn,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = view?.title ?? raftText(context, 'Artifact');
    final compact = raftBreakpointWidth(context) < 640;
    final findLabel = raftText(context, 'Find in page');
    return CallbackShortcuts(
      bindings: {
        if (canFind) ...{
          const SingleActivator(LogicalKeyboardKey.keyF, control: true):
              openFind,
          const SingleActivator(LogicalKeyboardKey.keyF, meta: true): openFind,
        },
      },
      child: Focus(
        focusNode: panelFocus,
        autofocus: true,
        child: RaftPublicSurface(
          child: SafeArea(
            child: Column(
              children: [
                if (view != null && !compact) prompt(context, compact: false),
                RaftPanelHeaderBar(
                  title: title,
                  subtitle: view == null
                      ? null
                      : raftText(context, 'Made with Raft'),
                  onBack: widget.onBack,
                  actions: [
                    if (view != null) ...[
                      if (!compact && canFind)
                        RaftButton(
                          key: const Key('public-artifact-find'),
                          glyph: RaftGlyph.search,
                          tooltip: findLabel,
                          semanticLabel: findLabel,
                          tone: RaftButtonRecipeVariant.ghost,
                          size: RaftButtonRecipeSize.iconLg,
                          onPressed: openFind,
                        ),
                      publicActions(context, compact: compact),
                    ],
                  ],
                ),
                if (finding && canFind)
                  ArtifactFindBar(frame: controller, onClose: closeFind),
                if (view != null && compact && showPhonePrompt)
                  prompt(context, compact: true),
                Expanded(child: body(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
