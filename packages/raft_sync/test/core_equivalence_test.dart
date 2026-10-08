import 'dart:io';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:raft_sync/raft_sync.dart';

void main() {
  final fixture = [
    File('test/fixtures/ts-core-vectors.json'),
    File('packages/raft_sync/test/fixtures/ts-core-vectors.json'),
    File('../../packages/raft_sync/test/fixtures/ts-core-vectors.json'),
  ].firstWhere((file) => file.existsSync());
  final root = jsonDecode(fixture.readAsStringSync());
  for (final scenario in root['scenarios']) {
    test('TS/Dart equivalence: ${scenario['name']}', () {
      final core = SyncCore(
        violationCapacity: 4,
        domains: [
          SyncDomain(
            name: 'test',
            density: SyncDensity.values.byName(scenario['density']),
            initialState: () => [],
            fold: (state, event, scope, seq) => [...state, event],
            fromSnapshot: (s) => s.state,
            eventFingerprint: scenario['fingerprint'] == true
                ? (event) => jsonEncode(event)
                : null,
          ),
        ],
      );
      final steps = scenario['steps'] as List;
      for (var i = 0; i < steps.length; i++) {
        final raw = steps[i];
        final String scope = raw['scopeId'];
        final String? epoch = raw['epoch'];
        late Map<String, dynamic> result;
        if (raw['kind'] == 'frame') {
          result = core.ingestFrame(
            'test',
            SyncFrame(
              scopeId: scope,
              seq: BigInt.parse(raw['seq']),
              event: raw['event'],
              epoch: epoch,
            ),
          );
        } else if (raw['kind'] == 'snapshot') {
          result = core.ingestSnapshot(
            'test',
            SyncSnapshot(
              scopeId: scope,
              watermark: BigInt.parse(raw['watermark']),
              state: raw['state'],
              epoch: epoch,
            ),
          );
        } else {
          result = core.ingestDifference(
            'test',
            SyncDifference(
              scopeId: scope,
              epoch: epoch,
              fromSeq: BigInt.parse(raw['fromSeq']),
              toSeq: BigInt.parse(raw['toSeq']),
              partial: raw['partial'] == true,
              snapshotRequired: raw['snapshotRequired'] == true,
              events: (raw['events'] as List)
                  .map(
                    (e) => SyncFrame(
                      scopeId: scope,
                      seq: BigInt.parse(e['seq']),
                      event: e['event'],
                      epoch: epoch,
                    ),
                  )
                  .toList(),
            ),
          );
        }
        expect(
          {
            'result': result,
            'requests': core.pendingRequests(),
            'state': core.state('test', scope),
            'sync': core.scopeSyncState('test', scope),
            'violations': core.violations(0),
          },
          scenario['expected'][i],
          reason: 'step $i: ${raw['kind']}',
        );
      }
    });
  }
}
