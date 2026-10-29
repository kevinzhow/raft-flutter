import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:raft_flutter/platform/file_selection.dart';

class _Photos extends ImagePicker {
  final calls = <({String kind, bool metadata})>[];
  final files = [XFile('/fixture/IMG_1.heic'), XFile('/fixture/clip.mp4')];
  @override
  Future<List<XFile>> pickMultipleMedia({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    calls.add((kind: 'media', metadata: requestFullMetadata));
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
    calls.add((kind: 'images', metadata: requestFullMetadata));
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
    calls.add((kind: 'image', metadata: requestFullMetadata));
    return files.first;
  }
}

class _Documents extends FileSelectorPlatform {
  final opened = <List<XTypeGroup>?>[];
  @override
  Future<List<XFile>> openFiles({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    opened.add(acceptedTypeGroups);
    return [XFile('/doc/a.pdf')];
  }

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    opened.add(acceptedTypeGroups);
    return XFile('/doc/a.pdf');
  }
}

void main() {
  const image = XTypeGroup(label: 'Images', extensions: ['jpg', 'png']);
  late _Documents documents;
  setUp(() {
    documents = _Documents();
    FileSelectorPlatform.instance = documents;
  });

  test('Android media button uses the Photo Picker without full metadata', () async {
    final picker = _Photos();
    final files = await selectUploads(
      mediaOnly: true,
      platform: TargetPlatform.android,
      picker: picker,
    );
    expect(files.map((f) => f.name), ['IMG_1.heic', 'clip.mp4']);
    expect(picker.calls.single, (kind: 'media', metadata: false));
    expect(documents.opened, isEmpty);
  });

  test('Android single and multi image selection use the Photo Picker', () async {
    final picker = _Photos();
    await selectImage(
      typeGroup: image,
      platform: TargetPlatform.android,
      picker: picker,
    );
    await selectImages(
      typeGroup: image,
      platform: TargetPlatform.android,
      picker: picker,
    );
    expect(picker.calls, [
      (kind: 'image', metadata: false),
      (kind: 'images', metadata: false),
    ]);
    expect(documents.opened, isEmpty);
  });

  test('the file button keeps the document picker on every platform', () async {
    for (final platform in TargetPlatform.values) {
      final picker = _Photos();
      await selectUploads(platform: platform, picker: picker);
      expect(picker.calls, isEmpty, reason: '$platform');
    }
    expect(documents.opened, hasLength(TargetPlatform.values.length));
    expect(documents.opened.every((groups) => groups!.isEmpty), isTrue);
  });

  test('desktop media and image paths keep the document picker', () async {
    for (final platform in [
      TargetPlatform.linux,
      TargetPlatform.macOS,
      TargetPlatform.windows,
    ]) {
      final picker = _Photos();
      await selectUploads(mediaOnly: true, platform: platform, picker: picker);
      await selectImage(typeGroup: image, platform: platform, picker: picker);
      await selectImages(typeGroup: image, platform: platform, picker: picker);
      expect(picker.calls, isEmpty, reason: '$platform');
    }
    expect(documents.opened, hasLength(9));
    expect(documents.opened.first, mediaPickerTypeGroups);
  });

  test('startup opts Android into the Photo Picker below Android 16 only there', () {
    final android = ImagePickerAndroid();
    configureAndroidPhotoPicker(
      platform: TargetPlatform.android,
      picker: android,
    );
    expect(android.useAndroidPhotoPicker, isTrue);
    final other = ImagePickerAndroid();
    configureAndroidPhotoPicker(platform: TargetPlatform.iOS, picker: other);
    configureAndroidPhotoPicker(platform: TargetPlatform.linux, picker: other);
    expect(other.useAndroidPhotoPicker, isFalse);
  });
}
