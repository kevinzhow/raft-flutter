import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/managed_mcp_credentials.dart';

// The same credential vectors as Web v1.21.12 managedMcpCredentials.test.ts.
void main() {
  test('blank unchanged secrets are retained; renamed/new/duplicate rows are invalid', () {
    expect(
      managedMcpHeadersIncomplete(const [
        ManagedMcpHeader(' authorization ', '', persistedName: 'Authorization'),
      ]),
      isFalse,
    );
    for (final rows in [
      const [ManagedMcpHeader('X-New', '')],
      const [ManagedMcpHeader('X-Renamed', '', persistedName: 'X-Old')],
      const [
        ManagedMcpHeader('Authorization', 'one'),
        ManagedMcpHeader('authorization', 'two'),
      ],
    ]) {
      expect(managedMcpHeadersIncomplete(rows), isTrue);
    }
  });

  test('patch preserves stored rows and explicitly renames, adds and removes others', () {
    expect(
      managedMcpCredentials(
        creating: false,
        authMode: 'headers',
        headers: const [
          ManagedMcpHeader('Authorization', '', persistedName: 'Authorization'),
          ManagedMcpHeader(
            'X-Renamed',
            'renamed-value',
            persistedName: 'X-Old',
          ),
          ManagedMcpHeader('X-New', 'new-value'),
        ],
        persistedNames: const ['Authorization', 'X-Old', 'X-Removed'],
      ),
      {
        'credentialPatch': {
          'upsertHeaders': {'X-Renamed': 'renamed-value', 'X-New': 'new-value'},
          'removeHeaderNames': ['X-Old', 'X-Removed'],
        },
      },
    );
  });

  test(
    'creation includes every entered value without persisting hidden values',
    () {
      expect(
        managedMcpCredentials(
          creating: true,
          authMode: 'headers',
          headers: const [
            ManagedMcpHeader(' Authorization ', 'Bearer fixture'),
            ManagedMcpHeader('X-Key', 'fixture-key'),
          ],
          persistedNames: const [],
        ),
        {
          'headers': {
            'Authorization': 'Bearer fixture',
            'X-Key': 'fixture-key',
          },
        },
      );
    },
  );

  test(
    'removing all rows is explicit; other auth modes do not send header values',
    () {
      expect(
        managedMcpCredentials(
          creating: false,
          authMode: 'headers',
          headers: const [],
          persistedNames: const ['Authorization'],
        ),
        {
          'credentialPatch': {
            'upsertHeaders': <String, String>{},
            'removeHeaderNames': ['Authorization'],
          },
        },
      );
      for (final mode in ['none', 'oauth']) {
        expect(
          managedMcpCredentials(
            creating: false,
            authMode: mode,
            headers: const [ManagedMcpHeader('Authorization', 'discarded')],
            persistedNames: const ['Authorization'],
          ),
          isEmpty,
        );
      }
    },
  );
}
