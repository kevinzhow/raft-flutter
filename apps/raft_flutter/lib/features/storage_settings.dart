import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/attachment_disk_cache.dart';
import '../data/cache_budget.dart';
import '../data/cache_clear.dart';
import '../data/workspace_controller.dart';
import '../platform/video_cache.dart';
import 'message_history_settings.dart';
import 'local_error_diagnostics.dart';
import 'computer_detail_view.dart' show computerFileSize;

/// Settings > Resources > Storage (native only; Web leaves caching to the
/// browser).
///
/// Shows how much this device keeps so that attachments, previews, profile
/// pictures and icons open again without downloading (the total, then
/// "Attachments and previews" and "Profile pictures and icons"), and offers
/// "Clear cache", and lets the user choose how large the cache may grow
/// ([attachmentCacheBudgetTiers], remembered by [CacheBudget]; choosing a lower
/// one evicts the least recently used attachments at once, the profile
/// pictures keep their own small limit). Clearing goes through [CacheClear]: the page knows none of
/// the layers. Only rebuildable data goes; the sign-in, drafts, settings, the
/// workspace database, files the user saved and files received from other apps
/// are stored elsewhere and are never touched.
///
/// Below it, "Video cache" shows how much video this account keeps (live, as
/// videos are watched) and has its own "Clear" (no confirmation: a video is
/// downloaded again on demand and nothing of the user's is in it). It is the
/// signed-in account's folder only (`VideoCache`).
class StorageSettingsPage extends StatefulWidget {
  const StorageSettingsPage({
    super.key,
    this.cache,
    this.coordinator,
    this.workspace,
    this.videoAccount,
  });
  final WorkspaceController? workspace;

  /// Whose video cache is shown; the workspace's signed-in account by
  /// default. Without one the video block is not shown.
  final VideoCacheAccount? videoAccount;

  /// The cache whose size is shown; the app's installed cache by default.
  final AttachmentDiskCache? cache;

  /// What "Clear cache" runs; the app's coordinator by default.
  final CacheClear? coordinator;

  @override
  State<StorageSettingsPage> createState() => _StorageSettingsPageState();
}

class _StorageSettingsPageState extends State<StorageSettingsPage> {
  late final AttachmentDiskCache? cache =
      widget.cache ?? AttachmentDiskCache.installed;

  late final CacheClear coordinator = widget.coordinator ?? CacheClear.instance;

  /// The chosen cap of the whole cache.
  late int budget = CacheBudget.stored();

  late final VideoCacheAccount? videoAccount =
      widget.videoAccount ?? _accountOf(widget.workspace);
  bool clearingVideos = false;

  static VideoCacheAccount? _accountOf(WorkspaceController? workspace) {
    final user = workspace?.client.user?.id;
    if (workspace == null || user == null || user.isEmpty) return null;
    return VideoCacheAccount(workspace.client.origin, user);
  }

  /// Null while the sizes are being measured.
  int? attachmentBytes, publicBytes;
  int? get bytes => switch ((attachmentBytes, publicBytes)) {
    (final a?, final b?) => a + b,
    _ => null,
  };

  @override
  void initState() {
    super.initState();
    unawaited(measure());
  }

  /// The index is built and read with asynchronous file I/O, so a large cache
  /// never blocks a frame.
  Future<void> measure() async {
    final attachments =
        await cache?.sizeBytes(
          namespace: AttachmentCacheNamespace.attachments,
        ) ??
        0;
    final public =
        await cache?.sizeBytes(namespace: AttachmentCacheNamespace.public) ?? 0;
    if (!mounted) return;
    setState(() {
      attachmentBytes = attachments;
      publicBytes = public;
    });
  }

  /// Applies [value] to the cache at once (evicting down to it when lower),
  /// remembers it for the next start, and shows the resulting size.
  Future<void> chooseBudget(int? value) async {
    if (value == null || value == budget) return;
    setState(() => budget = value);
    unawaited(CacheBudget.save(value));
    await cache?.setMaxBytes(value);
    if (mounted) await measure();
  }

  /// Empties this account's video cache and says how it went. The size line
  /// follows the cache on its own (it is live).
  Future<void> clearVideos(VideoCacheAccount account) async {
    setState(() => clearingVideos = true);
    var left = 0;
    try {
      await VideoCache.clear(account);
      left = await VideoCache.sizeBytes(account);
    } on Object {
      left = -1;
    }
    if (!mounted) return;
    setState(() => clearingVideos = false);
    showRaftToast(
      context,
      left == 0
          ? 'Video cache cleared.'
          : 'Some of the video cache could not be cleared. Try again.',
      tone: left == 0 ? RaftToastRecipeTone.success : RaftToastRecipeTone.error,
    );
  }

  Widget videoCache(
    BuildContext context,
    VideoCacheAccount account,
    RaftSettingsText text,
  ) => RaftSettingsPreference(
    gapBefore: RaftSpace.x6,
    title: 'Video cache',
    description: 'Videos you watch are kept on this device so they play again without downloading. They are removed when you sign out.',
    child: ValueListenableBuilder<int?>(
      valueListenable: VideoCache.watchSize(account),
      builder: (context, bytes, _) => Row(
        children: [
          Expanded(
            child: Semantics(
              key: const Key('storage-video-size'),
              container: true,
              liveRegion: true,
              child: Text(
                bytes == null
                    ? raftText(context, 'Calculating…')
                    : raftFormat(context, 'Video cache: {size}', {
                        'size': computerFileSize(bytes),
                      }),
                style: text.description,
              ),
            ),
          ),
          const SizedBox(width: RaftSpace.x3),
          RaftSettingsRecipeButton(
            key: const Key('storage-video-clear'),
            label: 'Clear',
            glyph: RaftGlyph.trash2,
            onPressed: bytes == null || bytes == 0 || clearingVideos
                ? null
                : () => clearVideos(account),
          ),
        ],
      ),
    ),
  );

  Future<void> confirmClear() async {
    final cleared = await RaftConfirmDialog.show(
      context,
      RaftConfirmDialog(
        surfaceKey: const ValueKey('storage-clear-dialog'),
        confirmKey: const Key('storage-clear-confirm'),
        title: raftText(context, 'Clear Cache'),
        message: raftText(
          context,
          'Downloaded attachments and previews, profile pictures and icons, and temporary preview files are removed from this device. They are downloaded again the next time you open them. Files that are open right now are kept, and so are your sign-in, drafts, settings, files you saved and files shared to Raft.',
        ),
        confirmLabel: raftText(context, 'Clear Cache'),
        cancelLabel: raftText(context, 'Keep Cache'),
        loadingLabel: raftText(context, 'Clearing…'),
        onConfirm: () async {
          final result = await coordinator.run();
          if (!result.ok) {
            throw const RaftUserError(
              'Some of the cache could not be cleared. Try again.',
            );
          }
        },
      ),
    );
    if (cleared != true || !mounted) return;
    unawaited(measure());
    showRaftToast(context, 'Cache cleared.', tone: RaftToastRecipeTone.success);
  }

  @override
  Widget build(BuildContext context) {
    final text = RaftSettingsText(RaftTokens.of(context));
    final size = bytes;
    Widget row(Key key, String label, int? value) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: RaftSpace.x1),
        Row(
          children: [
            Expanded(
              child: Text(raftText(context, label), style: text.description),
            ),
            Text(
              key: key,
              value == null ? '…' : computerFileSize(value),
              style: text.description,
            ),
          ],
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.workspace case final w?)
          MessageHistorySettings.forWorkspace(w),
        const RaftSettingsSectionHeader(
          label: 'Storage',
          glyph: RaftGlyph.hardDrive,
        ),
        RaftSettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RaftSettingsPreference(
                title: 'Cache',
                description: 'Attachments, previews, profile pictures and icons you open are kept on this device so they open again without downloading. Your sign-in, drafts, settings and files you saved are not part of the cache.',
                child: Semantics(
                  key: const Key('storage-size'),
                  container: true,
                  liveRegion: true,
                  child: Text(
                    size == null
                        ? raftText(context, 'Calculating…')
                        : raftFormat(context, 'Cache size: {size}', {
                            'size': computerFileSize(size),
                          }),
                    style: text.description,
                  ),
                ),
              ),
              const SizedBox(height: RaftSpace.x3),
              row(
                const Key('storage-attachments-size'),
                'Attachments and previews',
                attachmentBytes,
              ),
              row(
                const Key('storage-public-size'),
                'Profile pictures and icons',
                publicBytes,
              ),
              const SizedBox(height: RaftSpace.x4),
              RaftSettingsPreference(
                title: 'Cache limit',
                description: 'The most space the cache may use on this device. When it is full, the attachments and previews you opened longest ago are removed first. Profile pictures and icons keep their own small limit.',
                child: RaftSelectField<int>(
                  key: const Key('storage-budget'),
                  label: 'Cache limit',
                  value: budget,
                  items: [
                    for (final tier in attachmentCacheBudgetTiers)
                      RaftSelectItem(
                        value: tier,
                        label: CacheBudget.label(tier),
                        labelKey: Key('storage-budget-$tier'),
                      ),
                  ],
                  onChanged: cache == null ? null : chooseBudget,
                ),
              ),
              const SizedBox(height: RaftSpace.x4),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: RaftSettingsRecipeButton(
                  key: const Key('storage-clear'),
                  label: 'Clear Cache',
                  glyph: RaftGlyph.trash2,
                  onPressed: cache == null || size == null
                      ? null
                      : confirmClear,
                ),
              ),
              if (videoAccount case final account? when VideoCache.enabled)
                videoCache(context, account, text),
            ],
          ),
        ),
        const SizedBox(height: RaftSpace.x6),
        const LocalErrorDiagnosticsCard(),
        const SizedBox(height: RaftSpace.x6),
      ],
    );
  }
}
