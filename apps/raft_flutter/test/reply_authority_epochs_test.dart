import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/reply_authority_epochs.dart';

void main() {
  test('null channel remains a null JSON slot, distinct from an empty id', () {
    final authority = ReplyAuthorityEpochs();
    expect(authority.token('principal', null), '["principal",0,null,0]');
    authority.invalidateChannel('');
    expect(authority.token('principal', null), '["principal",0,null,0]');
    expect(authority.token('principal', ''), '["principal",0,"",1]');
    authority.invalidateAll();
    expect(authority.token('principal', null), '["principal",1,null,0]');
    expect(authority.token('principal', ''), '["principal",1,"",1]');
  });

  test('identity is opaque text and never parsed or normalized', () {
    final authority = ReplyAuthorityEpochs();
    const identity = '["https://fixture.invalid",7,"s","人",null]';
    expect(jsonDecode(authority.token(identity, 'thread:a')), [
      identity,
      0,
      'thread:a',
      0,
    ]);
  });
}
