import 'package:flutter/widgets.dart';

import '../data/attachment_image_repository.dart';
import '../data/source_channel_files_store.dart';
import '../data/source_time_formatter.dart';
import '../data/workspace_controller.dart';
import '../platform/attachment_files.dart';
import 'source_channel_files_actions.dart';

/// What the channel Files list needs besides its rows: the time format of the
/// person's settings and the row images (already decoded ones paint in the
/// first frame). The Files tab and the Files card share it.
class ChannelFilesMedia {
  ChannelFilesMedia(this.w);
  final WorkspaceController w;
  final files = AttachmentFiles();

  SourceTimeFormatter formatter(BuildContext context) => SourceTimeFormatter(
    locale: Localizations.localeOf(context).toLanguageTag(),
    preferredTimezone:
        w.client.user?.string('preferredTimezone') ??
        w.client.user?.string('timezone'),
    preferredTimeFormat: sourceTimeFormatPreference(
      w.client.user?.string('preferredTimeFormat') ??
          w.client.user?.string('timeFormat'),
    ),
    systemTimeFormat: MediaQuery.alwaysUse24HourFormatOf(context)
        ? SourceTimeFormat.twentyFourHour
        : null,
  );

  bool _usesThumbnail(
    SourceChannelFileEntry file,
    SourceChannelImageRendition rendition,
  ) {
    final thumbnail = file.metadata['thumbnailUrl'];
    return thumbnail is String &&
        thumbnail.isNotEmpty &&
        (rendition == SourceChannelImageRendition.thumbnail ||
            file.mimeType.toLowerCase().split(';').first.trim() ==
                'image/svg+xml');
  }

  AttachmentImageKey _imageKey(
    SourceChannelFileEntry file,
    SourceChannelImageRendition rendition,
  ) => AttachmentImageKey.fromMetadata(
    scope: w.attachmentImageScope,
    channelId: file.channelId,
    metadata: file.metadata,
    rendition: _usesThumbnail(file, rendition) ? 'thumbnail' : 'original',
    // The Files row tile is 56px: never decode the original for it (bounded
    // for the densest displays, 3x). Previews decode at full size.
    target: rendition == SourceChannelImageRendition.thumbnail
        ? AttachmentDecodeTarget.box(56, 56, devicePixelRatio: 3, cover: true)
        : null,
  );

  /// Already decoded Files images (tab revisit) paint in the first frame.
  SourceChannelImageLease? peekImage(
    SourceChannelFileEntry file,
    bool Function() authorized,
    SourceChannelImageRendition rendition,
  ) {
    if (!authorized()) return null;
    final lease = w.attachmentMedia.peekImage(
      _imageKey(file, rendition),
      authorized: authorized,
    );
    final provider = lease?.lease.value;
    if (lease == null) return null;
    if (provider == null) {
      lease.release();
      return null;
    }
    return SourceChannelImageLease(
      provider: provider,
      release: () async => lease.release(),
    );
  }

  Future<SourceChannelImageLease?> acquireImage(
    SourceChannelFileEntry file,
    bool Function() authorized,
    SourceChannelImageRendition rendition,
  ) async {
    if (!authorized()) return null;
    final usesThumbnail = _usesThumbnail(file, rendition);
    final thumbnail = file.metadata['thumbnailUrl'];
    final key = _imageKey(file, rendition);
    final lease = w.attachmentMedia.acquireImage(
      key,
      authorized: authorized,
      // The 56px row tile takes whichever version is already on disk; a
      // preview (no decode target) needs its own full-size rendition.
      bestAvailable: rendition == SourceChannelImageRendition.thumbnail,
      load: (cancel) async {
        String url;
        if (usesThumbnail) {
          url = thumbnail;
        } else {
          url = await w.attachmentMedia.url(
            file.id,
            disposition: null,
            channelId: file.channelId,
          );
          if (cancel.isCancelled) throw const StaleAttachmentImage();
        }
        return files.image(url, cancel: cancel);
      },
    );
    try {
      final provider = await lease.lease.ready;
      return SourceChannelImageLease(
        provider: provider,
        release: () async => lease.release(),
      );
    } catch (_) {
      lease.release();
      rethrow;
    }
  }
}
