// Administration sections whose one Switch applies at once (Web v1.24.0
// features/settings/administration/SystemChannelsSection.tsx,
// MemberPermissionsSection.tsx, ServerTranslationSection.tsx, on
// components/settings/ImmediateSetting.tsx): no Save button; a failure shows
// under the row and the Switch goes back to the stored value.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'administration_immediate.dart';
import 'administration_support.dart';

/// Rebuild helper: a `setState` that survives an unmounted state.
mixin _Refresh<T extends StatefulWidget> on State<T> {
  void refresh() {
    if (mounted) setState(() {});
  }
}

// ------------------------------------------------------------ System Channels

class AdminSystemChannelsSection extends StatefulWidget {
  const AdminSystemChannelsSection({super.key, required this.w});
  final WorkspaceController w;
  @override
  State<AdminSystemChannelsSection> createState() => _SystemChannelsState();
}

class _SystemChannelsState extends State<AdminSystemChannelsSection>
    with _Refresh {
  WorkspaceController get w => widget.w;
  late final hideAllSave = ImmediateSave(refresh);

  /// The switch shows the change while it is on its way, then the channel
  /// list's answer.
  bool? pending;

  bool get currentHidden => !w.channels.any((c) => c.name == 'all');

  @override
  void initState() {
    super.initState();
    w.addListener(refresh);
  }

  @override
  void dispose() {
    w.removeListener(refresh);
    super.dispose();
  }

  Future<bool> saveHidden(bool checked) async {
    pending = checked;
    final saved = await hideAllSave.run(
      () async {
        // #all has dedicated hide/restore endpoints; they need no channel id.
        await w.command(
          'POST',
          '/channels/system/all/${checked ? 'hide' : 'restore'}',
        );
        await w.refreshChannels();
      },
      (e) => adminApiError(e, 'Failed to update #all channel setting'),
    );
    pending = null;
    refresh();
    return saved;
  }

  /// Hiding #all takes it away from everyone, so it is confirmed first, with
  /// the same confirmation as the channel's own settings; bringing it back is
  /// at once.
  void changed(bool checked) {
    if (!checked) {
      unawaited(saveHidden(false));
      return;
    }
    unawaited(
      adminConfirm(
        context,
        title: 'Hide #all',
        message:
            '#all will disappear from channel lists, and server members and agents will no longer be able to read or post there — including you. Existing history is preserved. To bring it back, go to Settings → Administration → System Channels and turn off "Hide #all channel".',
        confirmLabel: 'Hide',
        loadingLabel: 'Updating…',
        confirmVariant: RaftButtonRecipeVariant.warning,
        confirmKey: const ValueKey('hide-all-channel-confirm'),
        onConfirm: () async {
          await saveHidden(true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => RaftAdminSection(
    regionKey: adminRegion('system-channels'),
    label: 'System channels',
    glyph: RaftGlyph.eye,
    child: RaftAdminImmediateSwitchRow(
      switchKey: const ValueKey('admin-hide-all'),
      title: 'Hide #all channel',
      description:
          'When enabled, #all disappears from channel lists, search, posting, members, and agent channel surfaces. Existing history is preserved.',
      checked: pending ?? currentHidden,
      onChanged: hideAllSave.saving ? null : changed,
      failure: hideAllSave.failure,
    ),
  );
}

// ------------------------------------------------------------ Member Permissions

class AdminMemberPermissionsSection extends StatefulWidget {
  const AdminMemberPermissionsSection({super.key, required this.w});
  final WorkspaceController w;
  @override
  State<AdminMemberPermissionsSection> createState() =>
      _MemberPermissionsState();
}

class _MemberPermissionsState extends State<AdminMemberPermissionsSection>
    with _Refresh {
  WorkspaceController get w => widget.w;
  late final hideHumansSave = ImmediateSave(refresh);
  bool? pending;

  bool get stored => w.server?.json['hideHumansFromMembers'] == true;

  @override
  void initState() {
    super.initState();
    w.addListener(refresh);
  }

  @override
  void dispose() {
    w.removeListener(refresh);
    super.dispose();
  }

  Future<bool> saveHideHumans(bool checked) async {
    pending = checked;
    final saved = await hideHumansSave.run(
      () async {
        await w.command(
          'PATCH',
          '/servers/${w.server!.id}',
          data: {'hideHumansFromMembers': checked},
        );
        await w.recoverMembership();
      },
      (e) => adminApiError(e, 'Failed to update member permissions'),
    );
    pending = null;
    refresh();
    return saved;
  }

  /// Hiding the directory changes what every member sees, and it can be turned
  /// back: it applies at once with Undo on a toast. Showing it again needs no
  /// Undo.
  Future<void> changed(bool checked) async {
    final serverId = w.server?.id;
    final saved = await saveHideHumans(checked);
    if (!saved || !checked || serverId == null || !mounted) return;
    showUndoToast(
      context,
      w,
      title: 'Hid the human directory and counts from members',
      serverId: serverId,
      undo: () => unawaited(saveHideHumans(false)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (w.server == null) return const SizedBox.shrink();
    final canEdit = w.can('editServerSettings');
    return RaftAdminSection(
      regionKey: adminRegion('member-permissions'),
      label: 'Member permissions',
      glyph: RaftGlyph.users,
      child: RaftAdminImmediateSwitchRow(
        switchKey: const ValueKey('admin-hide-humans'),
        title: 'Hide human directory and counts from members',
        description:
            'Member role users cannot see server-wide human lists or human counts.',
        checked: pending ?? stored,
        onChanged: !canEdit || hideHumansSave.saving
            ? null
            : (value) => unawaited(changed(value)),
        failure: hideHumansSave.failure,
      ),
    );
  }
}

// ------------------------------------------------------------ Translation

class AdminTranslationSection extends StatefulWidget {
  const AdminTranslationSection({super.key, required this.w});
  final WorkspaceController w;
  @override
  State<AdminTranslationSection> createState() => _TranslationState();
}

class _TranslationState extends State<AdminTranslationSection> with _Refresh {
  WorkspaceController get w => widget.w;
  late final enabledSave = ImmediateSave(refresh);

  /// The switch shows the change while it is on its way; a failure puts the
  /// stored value back.
  bool? pending;

  @override
  void initState() {
    super.initState();
    w.services.translations.addListener(refresh);
    w.services.translations.ensureSettings();
  }

  @override
  void dispose() {
    w.services.translations.removeListener(refresh);
    super.dispose();
  }

  Future<bool> saveEnabled(bool checked) async {
    pending = checked;
    final saved = await enabledSave.run(
      () async {
        final response = await w.command(
          'PATCH',
          '/servers/${w.server!.id}/translation-settings',
          data: {'translationEnabled': checked},
        );
        // Message rows follow the accepted gate without a reload.
        w.services.translations.adoptServerSettings(response);
      },
      (e) => adminApiError(e, 'Failed to update server translation setting'),
    );
    pending = null;
    refresh();
    return saved;
  }

  /// Turning translation off stops it for every member, and it can be turned
  /// back on: it applies at once with Undo on a toast. Turning it on needs
  /// none.
  Future<void> changed(bool checked) async {
    final serverId = w.server?.id;
    final saved = await saveEnabled(checked);
    if (!saved || checked || serverId == null || !mounted) return;
    showUndoToast(
      context,
      w,
      title: 'Turned off message translation for this server',
      serverId: serverId,
      undo: () => unawaited(saveEnabled(true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (w.server == null) return const SizedBox.shrink();
    final store = w.services.translations, settings = store.settings;
    final enabled = pending ?? settings.serverEnabled;
    final error = store.settingsError;
    return RaftAdminSection(
      regionKey: adminRegion('translation'),
      label: 'Translation',
      glyph: RaftGlyph.languages,
      child: RaftAdminImmediateSwitchRow(
        switchKey: const ValueKey('admin-translation'),
        title: 'Enable message translation for this server',
        description:
            "Turn on message translation for this server. When this is off, members' language and display preferences will not translate messages here.",
        checked: enabled,
        onChanged:
            enabledSave.saving || store.settingsLoading || !settings.canManage
            ? null
            : (value) => unawaited(changed(value)),
        failure: enabledSave.failure,
        footer: [
          if (enabled && !settings.providerAvailable)
            const RaftErrorBanner(
              'Translation is enabled for this server, but no translation provider is configured.',
              small: true,
            ),
          if (error != null) RaftErrorBanner(error, small: true),
        ],
      ),
    );
  }
}
