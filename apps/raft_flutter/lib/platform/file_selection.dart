import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

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

/// Uses the host document picker, including Android's Storage Access Framework.
/// Read one selected file at a time so large batches do not duplicate buffers.
Future<List<XFile>> selectUploads() => openFiles();
