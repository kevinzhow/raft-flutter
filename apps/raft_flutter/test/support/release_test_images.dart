import 'package:flutter/painting.dart' show imageCache;
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:raft_ui/raft_ui.dart' show RaftHotImages, RaftImageBytes;

/// Empties every image holder a test can leave behind, and lets the engine
/// release what it held. Runs after every test (see `flutter_test_config.dart`).
///
/// The shared image cache keeps decoded images (and their handles) after a
/// test ends; they are not leaks of the test, so empty it before the report.
/// Avatars are held by [RaftHotImages] beyond the widget tree (that is its
/// job); release them with the cache.
///
/// `ImageCache.clear` does not dispose a cached image itself: it defers the
/// keep-alive handle's disposal (and with it the completer's last `ui.Image`
/// and `ImageInfo`) to a post-frame callback. A real app always has a next
/// frame; a test binding has none, so the last test of a file (the order a
/// random seed picks) ended with the callback never run and the report
/// blamed that test for a `notDisposed` Image, ImageInfo and
/// ImageStreamCompleterHandle. Drive one frame after clearing.
Future<void> releaseTestImages() async {
  RaftHotImages.instance.releaseAll();
  RaftImageBytes.instance = RaftImageBytes();
  RaftImageBytes.resetClient();
  imageCache
    ..clear()
    ..clearLiveImages();
  // The test binding is out of its test here (`pump` asserts `inTest`), so
  // run the frame by hand; nothing is mounted any more, it only drains the
  // post-frame callbacks.
  final scheduler = SchedulerBinding.instance;
  scheduler
    ..handleBeginFrame(Duration.zero)
    ..handleDrawFrame();
}
