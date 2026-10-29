// The settings surface of the public server page (Web PublicServerPage
// `publicSettingsGroups` + `SettingsPanel tab=... showAboutWorkspace={false}`).
//
// Signed out, only the About group exists (About, Documentation). A signed-in
// non-member (`public-authenticated-nonmember`, `account-and-resources`)
// also gets the Personal group (Account, Language & Region, Appearance) and
// Feedback and Release Notes in Resources. They are the signed-in Settings
// pages themselves, mounted without a current server.
import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/message_translation_store.dart';
import '../data/personal_presentation.dart';
import '../data/workspace_controller.dart';
import '../platform/app_services.dart';
import 'account_settings.dart';
import 'appearance_section.dart';
import 'locale_settings_page.dart';
import 'public_language_settings.dart';
import 'public_translation.dart';
import 'settings_page.dart';
import 'source_feedback_view.dart';
import 'workspace_settings.dart';

/// What the signed-in pages need from the account.
@immutable
class PublicSettingsAccount {
  const PublicSettingsAccount({
    required this.controller,
    required this.appearance,
    required this.onAppearance,
    this.onLogout,
  });
  final WorkspaceController controller;
  final RaftAppearance appearance;
  final ValueChanged<RaftAppearance> onAppearance;
  final Future<void> Function()? onLogout;
}

/// The destinations of the public settings sidebar, in Web order.
List<RaftSettingsDestination> publicSettingsDestinations({
  required Widget Function(BuildContext) about,
  required VoidCallback documentation,
  PublicSettingsAccount? account,
  PersonalPresentationStore? presentation,
  AppServices? services,
  bool translationEnabled = false,
  PublicLocalPreferences? localPreferences,
  MessageTranslationStore? translations,
}) {
  final w = account?.controller;
  // Web getPublicPersonalSettingsTabIds: Language & Region only where the
  // server offers translation. A signed-out visitor keeps it on this device.
  final language = translationEnabled
      ? [
          if (account != null && w != null)
            RaftSettingsDestination(
              'language-region',
              'Language & Region',
              RaftGlyph.languages,
              (_) => LocaleSettingsPage(controller: w),
            )
          else if (localPreferences != null && translations != null)
            RaftSettingsDestination(
              'language-region',
              'Language & Region',
              RaftGlyph.languages,
              (_) => PublicLanguageRegionPage(
                preferences: localPreferences,
                translations: translations,
              ),
            ),
        ]
      : const <RaftSettingsDestination>[];
  return [
    if (account == null || w == null || presentation == null) ...language,
    if (account != null && w != null && presentation != null) ...[
      RaftSettingsDestination(
        'account',
        'Account',
        RaftGlyph.user,
        (_) => AccountSettings(controller: w, onLogout: account.onLogout),
      ),
      ...language,
      RaftSettingsDestination(
        'appearance',
        'Appearance',
        RaftGlyph.type,
        (_) => RaftAppearanceSection(
          appearance: account.appearance,
          onAppearance: account.onAppearance,
          presentation: presentation,
        ),
      ),
    ],
    RaftSettingsDestination(
      'about',
      'About',
      RaftGlyph.badgeInfo,
      about,
      group: WorkspaceSettings.resources,
    ),
    RaftSettingsDestination.action(
      'documentation',
      'Documentation',
      RaftGlyph.bookOpenText,
      group: WorkspaceSettings.resources,
      onOpen: documentation,
    ),
    if (account != null && w != null) ...[
      RaftSettingsDestination(
        'feedback',
        'Feedback',
        RaftGlyph.messageSquare,
        (_) => SourceFeedbackView(controller: w, onUnreadChanged: (_) {}),
        group: WorkspaceSettings.resources,
        scroll: false,
        ownHeader: true,
        contentColor: RaftSettingsPanelFrame.feedbackSurface,
      ),
      RaftSettingsDestination(
        'release-notes',
        'Release Notes',
        RaftGlyph.fileText,
        (_) => ReleaseNotesView(
          controller: w,
          source: services?.appUpdate?.releaseNotes,
          installedTag: services?.appUpdate?.installedTag,
          installedVersion: services?.appUpdate?.currentVersion,
        ),
        group: WorkspaceSettings.resources,
        // /release-notes renders outside SettingsPanel's attached Panel.
        attached: false,
        // The view scrolls itself so a pull can refresh it.
        scroll: false,
      ),
    ],
  ];
}

/// The settings columns of the public page: the sidebar and the panel of the
/// selected tab.
class PublicServerSettings extends StatefulWidget {
  const PublicServerSettings({
    super.key,
    required this.tab,
    required this.onTab,
    required this.about,
    required this.documentationUrl,
    this.account,
    this.translationEnabled = false,
    this.localPreferences,
    this.translations,
    this.banner,
    this.sidebarWidth,
    this.onSidebarResize,
    this.onSidebarResizeEnd,
  });

  /// The selected tab id; one this visitor has no access to resolves to the
  /// first page (SettingsPanel's denied tab).
  final String tab;
  final ValueChanged<String> onTab;
  final Widget Function(BuildContext) about;
  final String documentationUrl;
  final PublicSettingsAccount? account;

  /// The server offers translation: Language & Region is a tab (a signed-out
  /// visitor's form needs [localPreferences] and [translations]).
  final bool translationEnabled;
  final PublicLocalPreferences? localPreferences;
  final MessageTranslationStore? translations;

  /// The sign in / join banner: under the panel from sm up, under both
  /// columns below it (Web v1.21.23 grid, `sm:col-start-2`).
  final Widget? banner;

  /// The dragged sidebar width, at sm and up where the columns sit side by
  /// side; null below it (`w-36`, no handle).
  final double? sidebarWidth;
  final ValueChanged<double>? onSidebarResize;
  final VoidCallback? onSidebarResizeEnd;

  @override
  State<PublicServerSettings> createState() => _PublicServerSettingsState();
}

class _PublicServerSettingsState extends State<PublicServerSettings> {
  /// The Appearance page's device choices (font size, live activity, ...): the
  /// same per-account record the workspace reads.
  PersonalPresentationStore? presentation;

  @override
  void initState() {
    super.initState();
    if (widget.account != null) {
      presentation = PersonalPresentationStore(
        desktop:
            !kIsWeb &&
            const [
              TargetPlatform.linux,
              TargetPlatform.macOS,
              TargetPlatform.windows,
            ].contains(defaultTargetPlatform),
      );
      _bindPresentation();
    }
  }

  void _bindPresentation() {
    final w = widget.account?.controller;
    if (w == null) return;
    unawaited(
      presentation?.bind(
        w.client.origin,
        w.client.user?.id,
        profileFont: w.client.user?.string('preferredMessageBodyFontSize'),
      ),
    );
  }

  @override
  void dispose() {
    presentation?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destinations = publicSettingsDestinations(
      about: widget.about,
      documentation: () => unawaited(
        launchUrl(
          Uri.parse(widget.documentationUrl),
          mode: LaunchMode.externalApplication,
        ),
      ),
      account: widget.account,
      presentation: presentation,
      services: AppServicesScope.maybeOf(context),
      translationEnabled: widget.translationEnabled,
      localPreferences: widget.localPreferences,
      translations: widget.translations,
    );
    final pages = destinations.where((d) => d.builder != null).toList();
    final active =
        pages.where((d) => d.id == widget.tab).firstOrNull ?? pages.first;
    final groups = [
      for (final group in destinations.map((d) => d.group).toSet())
        RaftSettingsNavGroup(group, [
          for (final d in destinations.where((d) => d.group == group))
            RaftSettingsNavEntry(
              id: d.id,
              label: d.label,
              glyph: d.glyph,
              onTap: d.onOpen ?? () => widget.onTab(d.id),
            ),
        ]),
    ];
    final t = RaftTokens.of(context);
    final header = RaftSettingsPanelHeader(
      title: active.title ?? active.label,
      glyph: active.glyph,
      mobile: false,
    );
    Widget page() => active.scroll
        ? ListView(
            key: PageStorageKey('public-settings-page-${active.id}'),
            primary: false,
            padding: raftScrollPadding(
              context,
              RaftSettingsPanelFrame.contentInset,
            ),
            children: [
              KeyedSubtree(
                key: ValueKey(active.id),
                child: active.builder!(context),
              ),
            ],
          )
        : KeyedSubtree(
            key: ValueKey(active.id),
            child: active.builder!(context),
          );
    final width = widget.sidebarWidth;
    final sideBySide = raftBreakpointWidth(context) >= 640;
    final banner = widget.banner;
    Widget panel(Widget frame) => sideBySide && banner != null
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: frame),
              banner,
            ],
          )
        : frame;
    final columns = Row(
      key: const ValueKey('public-server-settings-surface'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftPublicSettingsSidebar(
          title: raftText(context, 'Settings'),
          width: widget.sidebarWidth,
          child: RaftSettingsSidebarList(groups: groups, activeId: active.id),
        ),
        Expanded(
          child: panel(
            RaftSettingsPanelFrame(
              attached: active.attached,
              contentColor: active.contentColor?.call(t),
              header: active.ownHeader ? null : header,
              child: active.ownHeader
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        header,
                        Expanded(child: page()),
                      ],
                    )
                  : page(),
            ),
          ),
        ),
      ],
    );
    // Below sm the banner spans both columns.
    final body = !sideBySide && banner != null
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: columns),
              banner,
            ],
          )
        : columns;
    if (width == null || widget.onSidebarResize == null) return body;
    // PanelResizeHandle: an 8px strip centred on the sidebar's edge, over both
    // columns (`-right-1`), so it never takes width from either.
    return Stack(
      fit: StackFit.expand,
      children: [
        body,
        Positioned(
          left: width - RaftPanelResizeHandle.hitExtent / 2,
          top: 0,
          bottom: 0,
          width: RaftPanelResizeHandle.hitExtent,
          child: RaftPanelResizeHandle(
            key: const ValueKey('public-server-settings-sidebar-resize-handle'),
            label: raftText(context, 'Resize sidebar'),
            value: width,
            hairline: true,
            onChanged: widget.onSidebarResize!,
            onChangeEnd: widget.onSidebarResizeEnd,
          ),
        ),
      ],
    );
  }
}
