import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:raft_flutter/platform/file_selection.dart';

class _Photos extends ImagePicker {
  final calls = <({String kind, bool metadata, int? limit})>[];
  List<XFile> files = [
    XFile('/fixture/photo.jpg'),
    XFile('/fixture/movie.mov'),
  ];
  @override
  Future<List<XFile>> pickMultipleMedia({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    calls.add((kind: 'media', metadata: requestFullMetadata, limit: limit));
    return files;
  }

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    calls.add((kind: 'images', metadata: requestFullMetadata, limit: limit));
    return files;
  }

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    expect(source, ImageSource.gallery);
    calls.add((kind: 'image', metadata: requestFullMetadata, limit: null));
    return files.firstOrNull;
  }
}

void main() {
  const image = XTypeGroup(
    label: 'Images',
    extensions: ['jpg', 'png'],
    uniformTypeIdentifiers: ['public.image'],
  );
  test('iOS attachment media uses permissionless mixed-media Photos and preserves files', () async {
    final picker = _Photos();
    final files = await selectUploads(
      mediaOnly: true,
      platform: TargetPlatform.iOS,
      picker: picker,
    );
    expect(files, same(picker.files));
    expect(picker.calls.single, (kind: 'media', metadata: false, limit: null));
  });
  test(
    'iOS single-image and feedback pickers disable full library metadata',
    () async {
      final picker = _Photos();
      expect(
        await selectImage(
          typeGroup: image,
          platform: TargetPlatform.iOS,
          picker: picker,
        ),
        picker.files.first,
      );
      await selectImages(
        typeGroup: image,
        platform: TargetPlatform.iOS,
        picker: picker,
      );
      expect(picker.calls, [
        (kind: 'image', metadata: false, limit: null),
        (kind: 'images', metadata: false, limit: null),
      ]);
    },
  );
  test('cancel is an empty selection, never an upload/error', () async {
    final picker = _Photos()..files = [];
    expect(
      await selectUploads(
        mediaOnly: true,
        platform: TargetPlatform.iOS,
        picker: picker,
      ),
      isEmpty,
    );
    expect(
      await selectImage(
        typeGroup: image,
        platform: TargetPlatform.iOS,
        picker: picker,
      ),
      isNull,
    );
    expect(
      await selectImages(
        typeGroup: image,
        platform: TargetPlatform.iOS,
        picker: picker,
      ),
      isEmpty,
    );
  });
  test('filtered document media carries iOS UTIs as well as desktop MIME/extensions', () {
    expect(mediaPickerTypeGroups.single.uniformTypeIdentifiers, [
      'public.image',
      'public.movie',
    ]);
    expect(mediaPickerTypeGroups.single.mimeTypes, ['image/*', 'video/*']);
    expect(
      mediaPickerTypeGroups.single.extensions,
      containsAll(['heic', 'mov', 'webm']),
    );
  });
}
