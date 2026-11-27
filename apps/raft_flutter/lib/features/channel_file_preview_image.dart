import 'dart:typed_data';

import '../data/source_channel_files_store.dart';
import 'attachment_image_loader.dart';

final _svgUtf8Prefix = RegExp(
  r'^data:image/svg\+xml;utf8,',
  caseSensitive: false,
);

bool channelFileUsesRasterThumbnail(SourceChannelFileEntry file) =>
    attachmentNeedsRasterPreview(file.mimeType);

bool channelFileHasImagePreview(SourceChannelFileEntry file) {
  final mime = file.mimeType.toLowerCase().split(';').first.trim();
  return mime.startsWith('image/') &&
      (!channelFileUsesRasterThumbnail(file) ||
          attachmentThumbnailUrl(file.metadata) != null);
}

Uint8List? channelFileEmbeddedSvgThumbnail(SourceChannelFileEntry file) {
  if (channelFileUsesRasterThumbnail(file)) return null;
  final thumbnailUrl = file.metadata['thumbnailUrl'];
  if (thumbnailUrl is! String) return null;
  final encoded = thumbnailUrl.replaceFirst(
    _svgUtf8Prefix,
    'data:image/svg+xml;charset=utf-8,',
  );
  final data = Uri.tryParse(encoded)?.data;
  return data != null && data.mimeType == 'image/svg+xml'
      ? data.contentAsBytes()
      : null;
}
