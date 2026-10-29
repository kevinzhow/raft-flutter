// The persistent attachment cache of the app under test, installed like main() does. The runner replaces this file
// with an empty stub when it tests a build that predates the cache (tool/attachment-open-smoke/run --tree).
import 'package:path_provider/path_provider.dart';
import 'package:raft_flutter/data/attachment_disk_cache.dart';

Future<void> installAttachmentCache() async {
  AttachmentDiskCache.installed ??= AttachmentDiskCache(getApplicationCacheDirectory);
  await AttachmentDiskCache.installed!.warm();
}
