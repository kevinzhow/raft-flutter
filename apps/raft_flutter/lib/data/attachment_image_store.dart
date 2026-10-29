import 'dart:typed_data';

/// Where one fetched attachment source (image bytes, preview JSON, a preview
/// file) is persisted. [identity] binds the entry to origin/principal/server;
/// [channelId] lets a revoked channel be purged as a unit. No URL or
/// credential is part of it: the signed URL is a short-lived capability, the
/// cache is keyed by the attachment itself.
class AttachmentImageStoreKey {
  const AttachmentImageStoreKey({
    required this.identity,
    required this.channelId,
    required this.entry,
  });
  final String identity, channelId, entry;
}

/// Persistent encoded-bytes cache behind the attachment image repository.
/// Reads are only issued after the repository has verified the current
/// identity and channel authority; the store itself never grants access.
abstract interface class AttachmentImageByteStore {
  Future<Uint8List?> read(AttachmentImageStoreKey key);
  Future<void> write(AttachmentImageStoreKey key, Uint8List bytes);
  Future<void> remove(AttachmentImageStoreKey key);
  Future<void> purgeChannel(String identity, String channelId);
  Future<void> purgeIdentity(String identity);
}
