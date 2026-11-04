// Web v1.21.23 IntegrationInvitePage: composition of the canonical Card,
// Banner, Select and Button families. Product text roles resolve from tokens.
import 'package:flutter/material.dart';

import 'card.dart';
import 'raft/icon_tile.dart';
import 'raft/button.dart';
import 'banner.dart';
import 'design_primitives.dart';
import 'icons.dart';
import 'localization.dart';
import 'list_items.dart' show RaftSectionEyebrow;
import 'panel_layout.dart' show RaftCssText;
import 'recipes/button_variants.g.dart';
import 'separator.dart';
import 'select_field.dart';
import 'settings_controls.dart';
import 'settings_layout.dart';
import 'space.dart';
import 'system_inset.dart';
import 'theme.dart';
import 'text_scaling.dart';
import 'tokens/raft_tokens.g.dart' show RaftTypeScale;

class RaftPrivateAppInvitePage extends StatelessWidget {
  const RaftPrivateAppInvitePage({
    super.key,
    this.loading = false,
    this.error,
    this.name,
    this.description,
    this.byline = '',
    this.details = const [],
    this.servers = const [],
    this.selectedServer,
    this.installedServerName,
    this.installed = false,
    this.installing = false,
    this.scopes,
    this.setup,
    required this.onClose,
    required this.onRetry,
    required this.onServer,
    required this.onInstall,
    required this.onSettings,
  });
  final bool loading, installed, installing;
  final String? error, name, description, selectedServer, installedServerName;
  final String byline;
  final List<(String, String)> details;
  final List<RaftSelectItem<String>> servers;
  final Widget? scopes, setup;
  final VoidCallback onClose, onRetry, onInstall, onSettings;
  final ValueChanged<String?> onServer;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    String tr(String value) => raftText(context, value);
    Widget text(String value, List<String> classes) {
      final type =
          RaftTypeScale.byName[classes.first.replaceFirst('text-', '')] ??
          RaftTypeScale.callout;
      return RaftCssText(
        value,
        style:
            RaftTypography.inherited(
              t,
              size: type.fontSize,
              line: type.lineHeight,
              weight: classes.contains('font-medium')
                  ? FontWeight.w500
                  : FontWeight.values[(type.fontWeight ?? 400) ~/ 100 - 1],
              color: classes.contains('text-foreground-hint')
                  ? t.semantic.foregroundHint
                  : classes.contains('text-foreground-muted')
                  ? t.semantic.foregroundMuted
                  : t.semantic.foreground,
            ).copyWith(
              fontFamily: classes.contains('font-mono') ? t.monoFont : null,
              letterSpacing: (type.letterSpacingEm ?? 0) * type.fontSize,
            ),
      );
    }

    final selection = RaftSelectField<String>(
      key: const ValueKey('private-app-invite-server'),
      value: selectedServer,
      label: tr('Install target'),
      items: servers,
      onChanged: installing ? null : onServer,
    );
    final action = installed
        ? RaftSettingsRecipeButton(
            key: const ValueKey('private-app-invite-open-settings'),
            label: tr('Open settings'),
            size: RaftButtonRecipeSize.lg,
            glyph: RaftGlyph.externalLink,
            glyphSize: 14,
            onPressed: onSettings,
          )
        : RaftSettingsRecipeButton(
            key: const ValueKey('private-app-invite-install'),
            label: tr(installing ? 'Installing...' : 'Install app'),
            size: RaftButtonRecipeSize.lg,
            glyph: RaftGlyph.check,
            glyphSize: 14,
            variant: RaftButtonRecipeVariant.accent,
            onPressed: installing || selectedServer == null ? null : onInstall,
          );
    final children = <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RaftSectionEyebrow(tr('Private app invite')),
                const SizedBox(height: RaftSpace.x1),
                text(tr('Install connected app'), ['text-title']),
              ],
            ),
          ),
          const RaftIconTile(glyph: RaftGlyph.link2, size: RaftIconTileSize.lg),
        ],
      ),
      const RaftSeparator(),
      if (loading)
        Padding(
          padding: const EdgeInsets.only(
            top: RaftSpace.x4 * 2,
            bottom: RaftSpace.x4 * 3,
          ),
          child: Center(
            child: text(tr('Loading invite...'), [
              'text-callout',
              'text-foreground-muted',
            ]),
          ),
        ),
      if (error case final String value)
        RaftBanner(
          description: value,
          centerAction: true,
          action: RaftButton(
            key: const ValueKey('private-app-invite-retry'),
            glyph: RaftGlyph.refreshCw,
            tooltip: tr('Retry'),
            semanticLabel: tr('Retry'),
            uiSize: RaftButtonSize.iconXs,
            uiVariant: RaftButtonVariant.ghost,
            onPressed: onRetry,
          ),
        ),
      if (name != null) ...[
        if (installed)
          RaftBanner(
            status: RaftBannerRecipeStatus.success,
            description: raftFormat(
              context,
              '{app} is installed for {server}.',
              {
                'app': name,
                'server':
                    installedServerName ??
                    servers
                        .where((s) => s.value == selectedServer)
                        .firstOrNull
                        ?.label ??
                    tr('this server'),
              },
            ),
          ),
        if (setup != null) setup!,
        RaftCard(
          padding: const EdgeInsets.all(RaftSpace.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: RaftSpace.x3,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: RaftSpace.x1,
                children: [
                  text(name!, ['text-headline']),
                  text(byline, ['text-caption', 'text-foreground-hint']),
                ],
              ),
              if (description != null)
                text(description!, ['text-callout', 'text-foreground-muted']),
              Padding(
                padding: const EdgeInsets.only(top: RaftSpace.x1),
                child: LayoutBuilder(
                  builder: (context, box) => Wrap(
                    spacing: RaftSpace.x3,
                    runSpacing: RaftSpace.x3,
                    children: [
                      for (final (label, value) in details)
                        SizedBox(
                          width: MediaQuery.sizeOf(context).width >= 640
                              ? (box.maxWidth - RaftSpace.x3) / 2
                              : box.maxWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              text(tr(label), [
                                'text-footnote',
                                'text-foreground-hint',
                                'font-medium',
                              ]),
                              text(
                                value,
                                label == 'Invite expiry'
                                    ? ['text-callout']
                                    : ['text-mono-meta', 'font-mono'],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (scopes != null)
          RaftCard(padding: const EdgeInsets.all(RaftSpace.x4), child: scopes!),
        if (servers.isEmpty)
          RaftBanner(
            description: tr(
              'You need to be an owner or admin of a server to install this app.',
            ),
          )
        else
          RaftCard(
            padding: const EdgeInsets.all(RaftSpace.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: RaftSpace.x3,
              children: [
                RaftSectionEyebrow(tr('Install target')),
                if (MediaQuery.sizeOf(context).width >=
                        RaftLayoutMetrics.desktopBreakpoint &&
                    !RaftScaled.grows(context))
                  Row(
                    spacing: RaftSpace.x3,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: selection),
                      action,
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: RaftSpace.x3,
                    children: [selection, action],
                  ),
              ],
            ),
          ),
      ],
    ];
    return DefaultTextStyle(
      style: RaftTypography.inherited(
        t,
        size: RaftTypeScale.callout.fontSize,
        line: RaftTypeScale.callout.lineHeight,
        color: t.semantic.foreground,
      ).copyWith(inherit: false, decoration: TextDecoration.none),
      child: ColoredBox(
        color: t.colors['layer-sidebar'] ?? t.panel,
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final safe = MediaQuery.paddingOf(context);
                final padding = raftScrollPadding(
                  context,
                  EdgeInsets.fromLTRB(
                    RaftSpace.x4 + safe.left,
                    RaftSpace.x4 * 2 + safe.top,
                    RaftSpace.x4 + safe.right,
                    RaftSpace.x4 * 2,
                  ),
                  RaftSpace.x4,
                );
                return SingleChildScrollView(
                  padding: padding,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - padding.vertical)
                          .clamp(0, double.infinity),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth:
                              RaftLayoutMetrics.desktopBreakpoint -
                              RaftSpace.x4 * 2,
                        ),
                        child: RaftCard(
                          padding: const EdgeInsets.all(RaftSpace.x5),
                          child: Column(
                            key: const ValueKey('integration-invite-page'),
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: RaftSpace.x4,
                            children: children,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + RaftSpace.x2,
              right: MediaQuery.paddingOf(context).right + RaftSpace.x2,
              child: RaftButton(
                key: const ValueKey('private-app-invite-close'),
                glyph: RaftGlyph.x,
                tooltip: tr('Go to Raft'),
                semanticLabel: tr('Go to Raft'),
                onPressed: onClose,
                uiSize: RaftButtonSize.iconSm,
                uiVariant: RaftButtonVariant.ghost,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
