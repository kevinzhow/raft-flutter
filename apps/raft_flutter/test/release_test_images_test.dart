import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart'
    show
        ImageConfiguration,
        ImageInfo,
        ImageStreamListener,
        MemoryImage,
        imageCache;
import 'package:flutter_test/flutter_test.dart';

import 'support/release_test_images.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAGUlEQVR4nGP8V7uCgRTARJLqUQ2jGoaUBgC7qgJDBU0aZAAAAABJRU5ErkJggg==',
);

void main() {
  test('releaseTestImages disposes the images the cache still held', () async {
    var open = 0;
    void onEvent(ObjectEvent event) {
      if (event.object is! ui.Image && event.object is! ImageInfo) return;
      if (event is ObjectCreated) open++;
      if (event is ObjectDisposed) open--;
    }

    FlutterMemoryAllocations.instance.addListener(onEvent);
    addTearDown(
      () => FlutterMemoryAllocations.instance.removeListener(onEvent),
    );
    addTearDown(imageCache.clear);

    // A widget that showed the picture and went away: the cache is the only
    // holder left (a keep-alive handle on a completer with a decoded frame).
    final decoded = Completer<void>();
    final stream = MemoryImage(_png).resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      info.dispose();
      stream.removeListener(listener);
      decoded.complete();
    });
    stream.addListener(listener);
    await decoded.future;
    expect(imageCache.currentSize, 1);
    expect(open, greaterThan(0));

    await releaseTestImages();

    expect(imageCache.currentSize, 0);
    expect(
      open,
      0,
      reason:
          'ImageCache.clear frees the handle in a post-frame callback; '
          'without a frame the last test of a file leaks it',
    );
  });
}
