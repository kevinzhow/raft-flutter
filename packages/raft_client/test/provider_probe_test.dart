import 'package:test/test.dart';
import 'package:raft_client/src/provider_probe.dart';

void main() {
  test('probe request digest matches shared TypeScript Unicode vector', () {
    expect(
      providerProbeRequestDigest(
        connectionId: 'connection-1',
        computerId: 'computer-1',
        model: '日本語 model',
      ),
      '58fe256ffbd7de44966e04b81ba6c88c6b230d3cd336863a25d8beddb3350d4d',
    );
  });
  test('canonical nested object sorts keys and preserves array order', () {
    expect(
      providerProbeCanonicalJson(<String, dynamic>{
        'z': <String, dynamic>{'b': true, 'a': null},
        'a': ['二', 1],
      }),
      '{"a":["二",1],"z":{"a":null,"b":true}}',
    );
  });
}
