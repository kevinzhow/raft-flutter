import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Key ordering matches the mounted TypeScript provider-probe request contract.
String providerProbeCanonicalJson(Object? value) {
  if (value is List)
    return '[${value.map(providerProbeCanonicalJson).join(',')}]';
  if (value is Map<String, dynamic>) {
    final keys = value.keys.toList()..sort();
    return '{${keys.map((key) => '${jsonEncode(key)}:${providerProbeCanonicalJson(value[key])}').join(',')}}';
  }
  return jsonEncode(value);
}

String providerProbeRequestDigest({
  required String connectionId,
  required String computerId,
  required String model,
}) => sha256
    .convert(
      utf8.encode(
        providerProbeCanonicalJson(<String, dynamic>{
          'connectionId': connectionId,
          'computerId': computerId,
          'runtime': 'builtin',
          'model': model,
          'probeKind': 'canary',
          'schema': 'provider-probe-request.v1',
        }),
      ),
    )
    .toString();
