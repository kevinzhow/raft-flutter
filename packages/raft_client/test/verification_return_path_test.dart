import 'package:raft_client/raft_client.dart';
import 'package:test/test.dart';

void main() {
  test('verification allows only a normalized application-local target', () {
    expect(
      raftVerificationReturnPath('/s/alpha/a/../tasks?view=list#task')
          .toString(),
      '/s/alpha/tasks?view=list#task',
    );
    for (final invalid in [
      '/',
      'https://example.invalid',
      '//example.invalid',
      '/%5cexample.invalid',
      '/\\example.invalid',
      '/a/..//example.invalid',
      '/a/%2e%2e//example.invalid',
      '/with\nnewline',
      '/${'x' * 2048}',
    ]) {
      expect(raftVerificationReturnPath(invalid), isNull, reason: invalid);
    }
  });
}
