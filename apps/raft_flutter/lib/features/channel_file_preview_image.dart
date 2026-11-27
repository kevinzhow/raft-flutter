import '../data/source_channel_files_store.dart';
import 'attachment_image_loader.dart';

bool channelFileUsesRasterThumbnail(SourceChannelFileEntry file) =>
    attachmentNeedsRasterPreview(file.mimeType);

bool channelFileHasImagePreview(SourceChannelFileEntry file) {
  final mime = file.mimeType.toLowerCase().split(';').first.trim();
  return mime.startsWith('image/') &&
      (!channelFileUsesRasterThumbnail(file) ||
          attachmentThumbnailUrl(file.metadata) != null);
}
