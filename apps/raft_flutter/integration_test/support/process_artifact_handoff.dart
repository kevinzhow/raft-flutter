// A native integration test app can be removed by Flutter's driver teardown.
// Persist its exact private artifacts on the owned fixture host before returning.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

Future<void> handoffAndroidProcessArtifacts({
  required String base,
  required Directory directory,
  required String fixtureSha,
}) async {
  final run = directory.uri.pathSegments.where((part) => part.isNotEmpty).last;
  final files = <String, Map<String, String>>{};
  for (final file in directory.listSync(recursive: true).whereType<File>()) {
    final name = file.path.substring(directory.path.length + 1);
    final bytes = file.readAsBytesSync();
    files[name] = {
      'base64': base64Encode(bytes),
      'sha256': sha256.convert(bytes).toString(),
    };
  }
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client.postUrl(
      Uri.parse('$base/__process/artifacts/$run/upload'),
    );
    request.headers.contentType = ContentType.json;
    request.write(
      jsonEncode({'run': run, 'fixtureSha': fixtureSha, 'files': files}),
    );
    final response = await request.close().timeout(const Duration(seconds: 45));
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode != 200) {
      throw StateError(
        'Android artifact handoff rejected: ${response.statusCode} $body',
      );
    }
    final receipt = jsonDecode(body) as Map<String, dynamic>;
    final result = jsonDecode(
      File('${directory.path}/result.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    for (final key in [
      'fixtureSha',
      'productSha',
      'testSha',
      'device',
      'platform',
      'sourceInputSha',
      'runtimeSha',
      'result',
      'rendererFrameCount',
    ]) {
      if (receipt[key] != result[key]) {
        throw StateError('Android persisted receipt differs: $key');
      }
    }
    if (receipt['run'] != run || receipt['fileCount'] != files.length) {
      throw StateError('Android persisted inventory differs from this run.');
    }
    final hashes = Map<String, dynamic>.from(receipt['files'] as Map);
    if (files.length != hashes.length ||
        files.entries.any(
          (entry) => hashes[entry.key] != entry.value['sha256'],
        )) {
      throw StateError(
        'Android persisted artifact hashes differ from this run.',
      );
    }
  } finally {
    client.close(force: true);
  }
}
