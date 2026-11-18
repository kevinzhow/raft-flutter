import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/forwarded_source.dart';

void main() {
  test('the note is what a person typed, never the generated count', () {
    final one = {
      'forwardedItems': [{}],
    };
    final two = {
      'forwardedItems': [{}, {}],
    };
    expect(forwardedNote(one, 'Forwarded 1 message'), '');
    expect(forwardedNote(two, 'Forwarded 2 messages'), '');
    expect(forwardedNote(two, ' Forwarded 2 messages '), '');
    expect(forwardedNote(one, ''), '');
    expect(forwardedNote(one, 'Please read this'), 'Please read this');
    expect(forwardedNote(two, 'Forwarded 1 message'), 'Forwarded 1 message');
  });
}
