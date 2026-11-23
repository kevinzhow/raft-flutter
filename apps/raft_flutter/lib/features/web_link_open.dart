import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/device_preferences.dart';
import '../data/workspace_controller.dart';
import 'artifacts/artifact_message_links.dart' show mayLinkArtifacts;
import 'channel_side_flags.dart';
import 'channel_side_web_preview.dart';

// Where a web link in a message opens (Web `MessageWebLink`,
// `store/webLinkOpenPreference.ts`, `WebLinkChoiceDialog`,
// `HowWebLinksOpenSetting`, `MessageCardBody` card button `open: "beside"`).
// Web only has the choice in Raft Desktop's built-in browser; the app has it
// wherever the single-page preview or the tabbed desktop browser is available.

/// How a plain web link in a message opens. Unset (null): the first click asks.
enum WebLinkOpenPreference {
  /// In Raft, in the web preview beside the conversation.
  beside,

  /// In the system browser.
  browser,
}

/// The device's choice, kept on this device only (Web `localStorage`
/// `raft_web_link_open_preference`).
///
/// A plain [Listenable] (not a ChangeNotifier): one lives as long as the app.
class WebLinkOpenPreferences implements Listenable {
  WebLinkOpenPreferences._();
  static final instance = WebLinkOpenPreferences._();

  static const key = 'raft.webLinkOpen.preference';

  final _listeners = <VoidCallback>{};

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  WebLinkOpenPreference? get value {
    final raw = DevicePreferences.current?.getString(key);
    return WebLinkOpenPreference.values
        .where((preference) => preference.name == raw)
        .firstOrNull;
  }

  /// Remembers [preference] (null forgets it: the next click asks again).
  void write(WebLinkOpenPreference? preference) {
    final preferences = DevicePreferences.current;
    if (preferences != null) {
      // The cached copy answers at once; storage catches up.
      if (preference == null) {
        unawaited(preferences.remove(key));
      } else {
        unawaited(preferences.setString(key, preference.name));
      }
    }
    for (final listener in _listeners.toList()) {
      listener();
    }
  }
}

/// Whether a page can open beside the conversation here: the flag is on and the
/// device has a WebView. Decides the card button's panel icon, the choice
/// dialog and the settings row.
bool webPreviewAvailable(WorkspaceController w) =>
    desktopBrowserAvailable(w) ||
    ChannelSideFlags.of(w).webPreview && WebPreviewStore.of(w).platform.frames;

/// A plain web link in a message's text (Web `MessageWebLink`): where it opens
/// follows the device's choice. Returns true when this handled the click
/// (beside, or the choice dialog, whose answer or dismissal opens it too);
/// false leaves the link to the caller's normal opening (the browser).
///
/// Not handled: web preview off or no WebView here, a link Raft doesn't show
/// beside (its own pages, credentials), no channel on screen to open beside,
/// and a browser choice.
Future<bool> openWebLinkByPreference(
  BuildContext context,
  WorkspaceController w,
  String href, {
  required String conversationId,
  required void Function(String href) openExternal,
}) async {
  if (!webPreviewAvailable(w)) return false;
  if (webPreviewTarget(href, raftAppHostnames(w)) == null) return false;
  if (webPreviewConversationHost(w, conversationId) == null) return false;
  final preference = WebLinkOpenPreferences.instance.value;
  if (preference == WebLinkOpenPreference.browser) return false;
  final opener = FocusManager.instance.primaryFocus;
  void beside() {
    if (!openWebPreviewBeside(
      w,
      href,
      conversationId: conversationId,
      onBrowserClose: () {
        if (opener?.context != null) opener?.requestFocus();
      },
    )) {
      openExternal(href);
    }
  }

  if (preference == WebLinkOpenPreference.beside) {
    beside();
    return true;
  }
  final choice = await showWebLinkChoiceDialog(
    context,
    desktopBrowser: desktopBrowserAvailable(w),
  );
  switch (choice) {
    case WebLinkOpenPreference.beside:
      WebLinkOpenPreferences.instance.write(choice);
      beside();
    case WebLinkOpenPreference.browser:
      WebLinkOpenPreferences.instance.write(choice);
      openExternal(href);
    case null:
      // Esc, x or the scrim: nothing is remembered, the link opens in the
      // browser and the next click asks again.
      openExternal(href);
  }
  return true;
}

/// What [webPreviewAvailable] depends on, for a widget that draws by it (the
/// card button's panel icon).
Listenable? webPreviewAvailability(
  WorkspaceController w, {
  required bool evaluate,
}) {
  final flags = evaluate
      ? ChannelSideFlags.of(w)
      : ChannelSideFlags.existingOf(w);
  if (flags == null) return null;
  return WebPreviewStore.of(w).availabilityChanges;
}

/// A card button `open: "beside"` (Web `MessageCardBody` `openBeside`): true
/// when it opened the page beside the conversation, false when the caller
/// opens it as any other button (a new tab in Web). An Artifact's address
/// stays an Artifact opener whatever `open` says.
bool cardButtonOpensBeside(WorkspaceController w, RaftCardButton button) =>
    button.beside && webPreviewAvailable(w) ||
    button.openMode == RaftCardOpenMode.automatic &&
        desktopBrowserAvailable(w) &&
        webPreviewTarget(button.url, raftAppHostnames(w)) != null;

bool desktopBrowserLinkAvailable(
  WorkspaceController w,
  String href,
  String conversationId,
) =>
    desktopBrowserLinksEnabled(w) &&
    webPreviewTarget(href, raftAppHostnames(w)) != null &&
    webPreviewConversationHost(w, conversationId) != null;

bool desktopBrowserLinksEnabled(WorkspaceController w) =>
    ChannelSideFlags.existingOf(w)?.desktopBrowser == true &&
    WebPreviewStore.of(w).platform.hasDesktopBrowser;

Listenable? desktopBrowserLinkChanges(
  WorkspaceController w,
  String conversationId,
) {
  if (ChannelSideFlags.existingOf(w) == null ||
      webPreviewConversationHost(w, conversationId) == null ||
      !WebPreviewStore.of(w).platform.hasDesktopBrowser) {
    return null;
  }
  return webPreviewAvailability(w, evaluate: false);
}

Future<void> showDesktopWebLinkMenu(
  BuildContext context,
  WorkspaceController w,
  String href,
  String conversationId,
  Offset position,
  VoidCallback openExternal,
) async {
  final opener = FocusManager.instance.primaryFocus;
  final choice = await showRaftMessageContextMenu<WebLinkOpenPreference>(
    context: context,
    anchor: position,
    builder: (menu) => RaftMessageContextMenu(
      key: const ValueKey('desktop-web-link-menu'),
      onDismiss: () => Navigator.of(menu).pop(),
      sections: [
        [
          RaftMessageContextMenuItem(
            label: raftText(menu, 'Open beside'),
            icon: const RaftIcon(RaftGlyph.panelRight, size: 16),
            onPressed: () =>
                Navigator.of(menu).pop(WebLinkOpenPreference.beside),
          ),
          RaftMessageContextMenuItem(
            label: raftText(menu, 'Open in browser'),
            icon: const RaftIcon(RaftGlyph.arrowUpRight, size: 16),
            onPressed: () =>
                Navigator.of(menu).pop(WebLinkOpenPreference.browser),
          ),
        ],
      ],
    ),
  );
  if (choice == null || !context.mounted) return;
  if (choice == WebLinkOpenPreference.beside &&
      openWebPreviewBeside(
        w,
        href,
        conversationId: conversationId,
        onBrowserClose: () {
          if (opener?.context != null) opener?.requestFocus();
        },
      )) {
    return;
  }
  openExternal();
}

bool openCardButtonBeside(
  WorkspaceController w,
  RaftCardButton button, {
  required String conversationId,
}) {
  if (!cardButtonOpensBeside(w, button) || mayLinkArtifacts(button.url)) {
    return false;
  }
  final opener = FocusManager.instance.primaryFocus;
  return openWebPreviewBeside(
    w,
    button.url,
    conversationId: conversationId,
    onBrowserClose: () {
      if (opener?.context != null) opener?.requestFocus();
    },
  );
}

/// Web `WebLinkChoiceDialog`: asked once, on the first click of a web link.
/// Each button is a choice that is remembered; Esc, x and the scrim choose
/// nothing (null).
Future<WebLinkOpenPreference?> showWebLinkChoiceDialog(
  BuildContext context, {
  bool desktopBrowser = false,
}) => showRaftDialog<WebLinkOpenPreference>(
  context: context,
  builder: (context) => WebLinkChoiceDialog(desktopBrowser: desktopBrowser),
);

class WebLinkChoiceDialog extends StatelessWidget {
  const WebLinkChoiceDialog({super.key, this.desktopBrowser = false});

  final bool desktopBrowser;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    void choose(WebLinkOpenPreference? choice) =>
        Navigator.of(context).pop(choice);
    return RaftDialog.shell(
      surfaceKey: const ValueKey('web-link-choice-dialog'),
      title: raftText(context, 'Open links in Raft?'),
      maxWidth: desktopBrowser ? 400 : 384,
      onClose: () => choose(null),
      body: Text(
        raftText(
          context,
          'Raft can show web pages beside the conversation, or hand them to your browser. You can change this in Settings › Appearance.',
        ),
        style: t.scale(RaftTypeScale.callout, color: t.ui.foregroundMuted),
      ),
      footer: [
        RaftButton(
          key: const ValueKey('web-link-choice-browser'),
          label: raftText(context, 'Use my browser'),
          uiVariant: RaftButtonVariant.ghost,
          uiSize: RaftButtonSize.lg,
          onPressed: () => choose(WebLinkOpenPreference.browser),
        ),
        RaftButton(
          key: const ValueKey('web-link-choice-beside'),
          label: raftText(context, 'Open beside'),
          uiVariant: RaftButtonVariant.primary,
          uiSize: RaftButtonSize.lg,
          onPressed: () => choose(WebLinkOpenPreference.beside),
        ),
      ],
    );
  }
}

/// Settings › Appearance › How web links open (Web `HowWebLinksOpenSetting`):
/// where a web link in a message opens when clicked. Only where a page can
/// open beside the conversation (the flag on and a platform WebView): nothing
/// on Linux and Windows. Until the person chooses, here or in the dialog the
/// first click opens, the select shows that the first click asks.
class HowWebLinksOpenSetting extends StatelessWidget {
  const HowWebLinksOpenSetting({super.key, required this.controller});
  final WorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    final flags = ChannelSideFlags.of(controller);
    final store = WebPreviewStore.of(controller);
    return ListenableBuilder(
      listenable: Listenable.merge([
        flags,
        WebLinkOpenPreferences.instance,
        store.platform.voiceOverState,
      ]),
      builder: (context, _) {
        // The OS decides whether there is a row; VoiceOver only changes where
        // a click opens, not what the person may choose.
        if (!desktopBrowserAvailable(controller) &&
            (!flags.webPreview || !store.platform.hasWebView)) {
          return const SizedBox.shrink();
        }
        final t = RaftTokens.of(context);
        final recipe = RaftSettingsRowSpec(
          key: const ValueKey('how-web-links-open-setting'),
          title: raftText(context, 'How web links open'),
          description: raftText(
            context,
            'Where a web link in a message opens when you click it.',
          ),
          control: RaftSettingsSelect<WebLinkOpenPreference>(
            key: const ValueKey('how-web-links-open-select'),
            label: 'How web links open',
            placeholder: 'Ask on the first click',
            value: WebLinkOpenPreferences.instance.value,
            items: [
              RaftSelectItem(
                value: WebLinkOpenPreference.beside,
                label: raftText(context, 'In Raft, beside the conversation'),
              ),
              RaftSelectItem(
                value: WebLinkOpenPreference.browser,
                label: raftText(context, 'In your browser'),
              ),
            ],
            onChanged: (value) {
              if (value != null) WebLinkOpenPreferences.instance.write(value);
            },
          ),
        );
        return Padding(
          padding: const EdgeInsets.only(top: RaftSpace.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: RaftSpace.x2,
            children: [
              RaftSettingsRowGroup(rows: [recipe]),
              Text(
                raftText(context, 'Saved on this device.'),
                style: t.scale(
                  t.typeSlot('caption'),
                  color: t.colors['foreground-hint'],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
