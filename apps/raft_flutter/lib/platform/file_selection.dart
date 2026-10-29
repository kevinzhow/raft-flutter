import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart'
    show ImagePickerPlatform;

class PickedUpload {
  const PickedUpload(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

Future<PickedUpload?> selectUpload() async {
  final file = await openFile();
  if (file == null) return null;
  return PickedUpload(file.name, await file.readAsBytes());
}

/// Web MessageInput `MEDIA_PICKER_ACCEPT = "image/*,video/*"`: the media
/// button opens images and videos, the file button anything.
const mediaPickerTypeGroups = [
  XTypeGroup(
    label: 'Media',
    extensions: [
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'bmp',
      'avif',
      'heic',
      'heif',
      'mp4',
      'm4v',
      'mov',
      'webm',
      'mkv',
      'avi',
    ],
    mimeTypes: ['image/*', 'video/*'],
    uniformTypeIdentifiers: ['public.image', 'public.movie'],
  ),
];

/// image_picker_android opens the legacy `ACTION_GET_CONTENT` document UI
/// below Android 16 unless asked for the system Photo Picker (backported
/// through Google Play services). Call once at startup; no-op elsewhere.
void configureAndroidPhotoPicker({
  TargetPlatform? platform,
  ImagePickerPlatform? picker,
}) {
  if (!_isAndroid(platform)) return;
  final instance = picker ?? ImagePickerPlatform.instance;
  if (instance is ImagePickerAndroid) instance.useAndroidPhotoPicker = true;
}

/// iOS Photos (PHPicker) and the Android system Photo Picker need no library
/// or storage permission and no full asset metadata. Desktop keeps its
/// document picker; the file button always uses it.
Future<List<XFile>> selectUploads({
  bool mediaOnly = false,
  TargetPlatform? platform,
  ImagePicker? picker,
}) {
  if (mediaOnly && _usesPhotos(platform)) {
    return (picker ?? ImagePicker()).pickMultipleMedia(
      requestFullMetadata: false,
    );
  }
  return openFiles(
    acceptedTypeGroups: mediaOnly ? mediaPickerTypeGroups : const [],
  );
}

bool _isAndroid(TargetPlatform? platform) =>
    !kIsWeb && (platform ?? defaultTargetPlatform) == TargetPlatform.android;

bool _usesPhotos(TargetPlatform? platform) =>
    !kIsWeb &&
    ((platform ?? defaultTargetPlatform) == TargetPlatform.iOS ||
        _isAndroid(platform));

Future<XFile?> selectImage({
  required XTypeGroup typeGroup,
  TargetPlatform? platform,
  ImagePicker? picker,
}) => _usesPhotos(platform)
    ? (picker ?? ImagePicker()).pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      )
    : openFile(acceptedTypeGroups: [typeGroup]);

Future<List<XFile>> selectImages({
  required XTypeGroup typeGroup,
  TargetPlatform? platform,
  ImagePicker? picker,
}) => _usesPhotos(platform)
    ? (picker ?? ImagePicker()).pickMultiImage(requestFullMetadata: false)
    : openFiles(acceptedTypeGroups: [typeGroup]);
