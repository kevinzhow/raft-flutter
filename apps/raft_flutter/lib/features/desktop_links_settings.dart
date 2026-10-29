import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../platform/linux_uri_scheme.dart';
import 'appearance_section.dart';

/// Linux AppImage only: whether `raft://` links (invites, shared messages)
/// open this app. The packaged launcher registers itself; an AppImage
/// installs nothing, so this is where the member sees and changes it.
class DesktopLinksSettings extends StatefulWidget {
  const DesktopLinksSettings({super.key, this.service});
  final LinuxUriSchemeRegistration? service;
  @override
  State<DesktopLinksSettings> createState() => _DesktopLinksSettingsState();
}

class _DesktopLinksSettingsState extends State<DesktopLinksSettings>
    with WidgetsBindingObserver {
  LinuxUriSchemeRegistration get service =>
      widget.service ?? LinuxUriSchemeRegistration.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(service.refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The handler may have been changed in the system settings meanwhile.
    if (state == AppLifecycleState.resumed) unawaited(service.refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: service,
    builder: (context, _) {
      final r = RaftAppearanceSectionRecipe(RaftTokens.of(context));
      final other = service.status == LinuxSchemeStatus.otherHandler;
      // English only: the zh wording must come from Web's catalog, which has
      // no counterpart for this Linux AppImage setting (needs owner wording).
      const label = 'Open raft:// links with this app';
      const description =
          'Invite and share links that start with raft:// open Raft, even when it is not running.';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RaftSettingsSectionHeader(
            label: 'Desktop',
            glyph: RaftGlyph.monitor,
          ),
          Container(
            padding: RaftAppearanceSectionRecipe.inset,
            decoration: r.card,
            child: RaftGapColumn(
              gap: RaftSpace.x3,
              children: [
                Row(
                  spacing: RaftSpace.x4,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: RaftGapColumn(
                        gap: RaftSpace.x1,
                        children: [
                          Text(label, style: r.heading),
                          Text(description, style: r.description),
                        ],
                      ),
                    ),
                    RaftSwitch(
                      key: const ValueKey('raft-uri-scheme-switch'),
                      value: service.registered,
                      semanticLabel: label,
                      semanticDescription: description,
                      onChanged:
                          service.busy ||
                              service.status == LinuxSchemeStatus.unknown
                          ? null
                          : (on) => unawaited(
                              on ? service.register() : service.unregister(),
                            ),
                    ),
                  ],
                ),
                if (other)
                  Text(
                    'Another app (${service.otherHandler ?? ''}) currently opens raft:// links. Raft leaves it as it is unless you turn this on.',
                    key: const ValueKey('raft-uri-scheme-other'),
                    style: r.description,
                  ),
                if (other && service.promptPending)
                  Row(
                    spacing: RaftSpace.x2,
                    children: [
                      RaftSettingsRecipeButton(
                        key: const ValueKey('raft-uri-scheme-use'),
                        label: 'Use Raft',
                        onPressed: service.busy
                            ? null
                            : () => unawaited(service.register()),
                      ),
                      RaftSettingsRecipeButton(
                        key: const ValueKey('raft-uri-scheme-keep'),
                        label: 'Keep It',
                        onPressed: service.busy
                            ? null
                            : () => unawaited(service.keepOtherHandler()),
                      ),
                    ],
                  ),
                if (service.error != null)
                  RaftErrorBanner(
                    service.error!,
                    key: const ValueKey('raft-uri-scheme-error'),
                    small: true,
                  ),
              ],
            ),
          ),
        ],
      );
    },
  );
}
