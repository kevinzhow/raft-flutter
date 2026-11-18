import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart' show WebViewPlatform;

import '../data/raft_permalink.dart';
import '../data/workspace_controller.dart';
import '../platform/content_links.dart';
import '../platform/macos_voice_over.dart';
import 'artifacts/artifact_frame_bridge.dart';
import 'channel_side_flags.dart';

// Web preview (`web_preview_v0`): one web page open beside a conversation, in
// the channel's side area. Web `features/webPreview/webPreviewStore.ts`: one
// page at a time, opening another replaces it, the side area shows whichever
// of it and an open Artifact was opened last. This file is the store and the
// rules of what may open; the panel is channel_side_web_preview_panel.dart and
// the side area (channel_side_area.dart) reads [WebPreviewStore.pageFor] to
// place it.

/// As an Artifact's card: a page needs a document's width beside the messages
/// (Web `WEB_PREVIEW_MIN_WIDTH`).
const webPreviewMinWidth = 480;

/// The phone frame's width: an iPhone 12-16's CSS width (Web
/// `WEB_PREVIEW_PHONE_WIDTH`).
const webPreviewPhoneWidth = 390.0;

enum WebPreviewWidth { desktop, phone }

class WebPreviewPage {
  const WebPreviewPage({required this.url, required this.conversationId});

  /// The address as the URL parser writes it (http or https only).
  final String url;

  /// The channel (or DM) it opens beside.
  final String conversationId;

  @override
  bool operator ==(Object other) =>
      other is WebPreviewPage &&
      other.url == url &&
      other.conversationId == conversationId;

  @override
  int get hashCode => Object.hash(url, conversationId);
}

/// An http(s) address as a [Uri], else null: never `javascript:`, `data:`,
/// `blob:`, `file:` or a custom protocol (Web `webPreviewUrl`).
Uri? webPreviewUrl(String? href) {
  if (href == null || href.isEmpty) return null;
  final uri = Uri.tryParse(href);
  if (uri == null || uri.host.isEmpty) return null;
  return uri.scheme == 'http' || uri.scheme == 'https' ? uri : null;
}

/// Raft's own app hosts (Web `useRaftPermalinkHostnames`: the page's and the
/// deployment's, plus the fixed defaults): a link there is Raft's and routes
/// in the app, never in a preview.
Set<String> raftAppHostnames(WorkspaceController w) => {
  ContentLinks.originFor(w.client.origin).host,
  ...defaultRaftPermalinkHostnames,
};

/// The page a card button or message link can open beside the conversation, or
/// null: http(s) only, not one of Raft's own hosts, no credentials in the
/// address (`https://user:pass@...`) (Web `webPreviewTarget`).
Uri? webPreviewTarget(String? href, Iterable<String> raftHostnames) {
  final url = webPreviewUrl(href);
  if (url == null || url.userInfo.isNotEmpty) return null;
  if (raftHostnames.contains(url.host)) return null;
  return url;
}

/// Whether the page may be shown in the app's WebView at all. A plain-http
/// page is never shown (Web: mixed content inside an https page): the panel
/// says so and offers the browser (Web `canFrameWebPreview`).
bool canFrameWebPreview(String url) => webPreviewUrl(url)?.scheme == 'https';

/// The address in the panel's head: the host (with its port) as the title and
/// the rest (path, query, hash) muted after it (Web `useAddressParts`).
({String host, String rest}) webPreviewAddressParts(String url) {
  final uri = webPreviewUrl(url);
  if (uri == null) return (host: url, rest: '');
  final name = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
  final path = uri.path == '/' ? '' : uri.path;
  return (
    host: uri.hasPort ? '$name:${uri.port}' : name,
    rest:
        '$path${uri.hasQuery ? '?${uri.query}' : ''}'
        '${uri.hasFragment ? '#${uri.fragment}' : ''}',
  );
}

/// Where this device can show a page in the app: Android, iOS and macOS have a
/// platform WebView (macOS unless VoiceOver is on, as the Artifact frame does:
/// [artifactFrameSupportFor]); Linux and Windows open the browser.
class WebPreviewPlatform {
  const WebPreviewPlatform({
    this.operatingSystem,
    this.voiceOver,
    this.webViewAvailable,
  });

  final String? operatingSystem;
  final ValueListenable<bool>? voiceOver;

  /// Null: whether a WebView platform is registered.
  final bool? webViewAvailable;

  String get os => operatingSystem ?? Platform.operatingSystem;
  ValueListenable<bool> get voiceOverState =>
      voiceOver ?? MacosVoiceOver.instance;

  /// The system has a WebView for this app, whatever VoiceOver says now.
  bool get hasWebView =>
      artifactFrameSupportFor(os) == ArtifactFrameSupport.webView &&
      (webViewAvailable ?? WebViewPlatform.instance != null);

  /// A page can be shown in the app right now.
  bool get frames =>
      artifactFrameSupportFor(os, voiceOver: voiceOverState.value) ==
          ArtifactFrameSupport.webView &&
      (webViewAvailable ?? WebViewPlatform.instance != null);
}

/// The one open web page of a session (Web `useWebPreviewStore`), one per
/// [WorkspaceController].
class WebPreviewStore extends ChangeNotifier {
  WebPreviewStore._();

  static final _owners = Expando<WebPreviewStore>();

  static WebPreviewStore of(WorkspaceController w) {
    final existing = _owners[w];
    if (existing != null) return existing;
    final created = _owners[w] = WebPreviewStore._();
    w.services.disposeWithSession(created.dispose);
    return created;
  }

  WebPreviewPlatform platform = const WebPreviewPlatform();

  WebPreviewPage? _page;
  int _openedAt = 0;
  WebPreviewWidth _width = WebPreviewWidth.desktop;
  int _reloads = 0;

  /// The page open beside a conversation, or null.
  WebPreviewPage? get page => _page;

  /// The page open beside [conversationId], or null: what that channel's side
  /// area shows.
  WebPreviewPage? pageFor(String? conversationId) =>
      conversationId != null && _page?.conversationId == conversationId
      ? _page
      : null;

  /// When the page came to the front (ms since epoch): of it and an open
  /// Artifact the side area shows the one opened last (`>=` wins for the page,
  /// as Web).
  int get openedAt => _openedAt;
  WebPreviewWidth get width => _width;

  /// Bumped by Refresh: the frame mounts again.
  int get reloads => _reloads;

  /// Opens [page], replacing the open one. An address that is not http(s) is
  /// ignored.
  void open(WebPreviewPage page) {
    final parsed = webPreviewUrl(page.url);
    if (parsed == null) return;
    _page = WebPreviewPage(
      url: parsed.toString(),
      conversationId: page.conversationId,
    );
    _openedAt = DateTime.now().millisecondsSinceEpoch;
    _reloads = 0;
    notifyListeners();
  }

  void close() {
    if (_page == null) return;
    _page = null;
    notifyListeners();
  }

  void setWidth(WebPreviewWidth width) {
    if (_width == width) return;
    _width = width;
    notifyListeners();
  }

  void reload() {
    _reloads++;
    notifyListeners();
  }
}

/// Links in the visible side thread use its parent conversation's preview.
String? webPreviewConversationHost(
  WorkspaceController w,
  String conversationId,
) {
  final channelId = w.channel?.id;
  if (channelId == conversationId) return channelId;
  final thread = w.threadIdentity;
  final presentation = w.messageDomain.presentation;
  if (channelId == null ||
      thread == null ||
      thread.taskId != null ||
      w.section != 'chat' ||
      thread.parentChannelId != channelId ||
      w.threadChannelId != conversationId ||
      !presentation.mainPresented ||
      !presentation.threadPresented) {
    return null;
  }
  return channelId;
}

/// Opens [url] beside the conversation [conversationId] (Web
/// `openWebPreviewBeside`). False when it can't open there: the flag is off,
/// the page is one Raft doesn't show (its own hosts, credentials, plain http),
/// this device has no WebView (Linux, Windows, macOS with VoiceOver), or the
/// conversation is not the channel on screen. The caller then opens the
/// browser, as Web opens a new tab.
bool openWebPreviewBeside(
  WorkspaceController w,
  String url, {
  required String conversationId,
}) {
  final store = WebPreviewStore.of(w);
  final target = webPreviewTarget(url, raftAppHostnames(w));
  if (target == null || !canFrameWebPreview(target.toString())) return false;
  if (!ChannelSideFlags.of(w).webPreview || !store.platform.frames) {
    return false;
  }
  final host = webPreviewConversationHost(w, conversationId);
  if (host == null) return false;
  store.open(WebPreviewPage(url: target.toString(), conversationId: host));
  return true;
}
