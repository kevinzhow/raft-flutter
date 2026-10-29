import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_updater/src/appimage/ed25519.dart';

List<int> hex(String text) => [
  for (var i = 0; i < text.length; i += 2)
    int.parse(text.substring(i, i + 2), radix: 16),
];

// RFC 8032 section 7.1 (TEST 1, 2, 3) and a signature made by tool/appcast.py
// (the release signer) over 3 bytes with a throwaway key.
const vectors = <(String, String, String)>[
  (
    'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a',
    '',
    'e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b',
  ),
  (
    '3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c',
    '72',
    '92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00',
  ),
  (
    'fc51cd8e6218a1a38da47ed00230f0580816ed13ba3303ac5deb911548908025',
    'af82',
    '6291d657deec24024827e69c3abe01a30ce548a284743a445e3680d7db5ac3ac18ff9b538d16f290ae67f760984dc6594a7c15e9716ed28dc027beceea1ec40a',
  ),
];

void main() {
  group('RFC 8032 vectors', () {
    for (final (key, message, signature) in vectors) {
      test('verifies "$message"', () {
        expect(verifyEd25519(hex(key), hex(signature), hex(message)), isTrue);
      });
    }
  });

  test('the test signer reproduces the RFC 8032 vectors', () {
    final seeds = [
      '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60',
      '4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb',
      'c5aa8df43f9f837bedb7442f31dcb7b166d38535076f094b85ce3a2e0b4458f7',
    ];
    for (var i = 0; i < seeds.length; i++) {
      final (key, message, signature) = vectors[i];
      final signed = ed25519SignForTesting(hex(seeds[i]), hex(message));
      expect(signed.publicKey, hex(key));
      expect(signed.signature, hex(signature));
    }
  });

  test('a streamed message gives the same answer as one chunk', () {
    final (key, message, signature) = vectors[2];
    final check = Ed25519Verifier(hex(key), hex(signature));
    for (final byte in hex(message)) {
      check.add([byte]);
    }
    expect(check.close(), isTrue);
    expect(() => check.close(), throwsStateError);
  });

  test('a changed message byte, key or signature byte is rejected', () {
    final (key, message, signature) = vectors[2];
    expect(verifyEd25519(hex(key), hex(signature), hex('af83')), isFalse);
    expect(verifyEd25519(hex(key), hex(signature), hex('af')), isFalse);
    expect(
      verifyEd25519(hex(key), hex(signature), hex('${message}00')),
      isFalse,
    );
    expect(
      verifyEd25519(hex(vectors[1].$1), hex(signature), hex(message)),
      isFalse,
    );
    for (final at in [0, 31, 32, 63]) {
      final broken = hex(signature)..[at] ^= 1;
      expect(
        verifyEd25519(hex(key), broken, hex(message)),
        isFalse,
        reason: '$at',
      );
    }
  });

  test('malformed keys and signatures throw FormatException', () {
    final (key, _, signature) = vectors[0];
    expect(
      () => Ed25519Verifier(hex(key).sublist(1), hex(signature)),
      throwsFormatException,
    );
    expect(
      () => Ed25519Verifier(hex(key), hex(signature).sublist(1)),
      throwsFormatException,
    );
    // S >= the group order is not a signature.
    final big = hex(signature)..setRange(32, 64, List.filled(32, 0xff));
    expect(() => Ed25519Verifier(hex(key), big), throwsFormatException);
    // y = 2 is not on the curve.
    final offCurve = Uint8List(32)..[0] = 2;
    expect(
      () => Ed25519Verifier(offCurve, hex(signature)),
      throwsFormatException,
    );
    expect(verifyEd25519(offCurve, hex(signature), const []), isFalse);
    expect(
      () => Ed25519Verifier.fromBase64('%%%', 'AAAA'),
      throwsFormatException,
    );
  });

  test('base64 forms are the Sparkle text forms', () {
    final (key, message, signature) = vectors[1];
    final publicKey = base64.encode(hex(key));
    expect(Ed25519Verifier.isPublicKey(publicKey), isTrue);
    expect(Ed25519Verifier.isPublicKey(''), isFalse);
    expect(Ed25519Verifier.isPublicKey('AAAA'), isFalse);
    final check = Ed25519Verifier.fromBase64(
      ' $publicKey\n',
      base64.encode(hex(signature)),
    )..add(hex(message));
    expect(check.close(), isTrue);
  });

  test('a large message streams through without slowing down', () {
    // Not a benchmark: guards against an accidentally quadratic implementation.
    final check = Ed25519Verifier(hex(vectors[0].$1), hex(vectors[0].$3));
    final chunk = Uint8List(1 << 20);
    final clock = Stopwatch()..start();
    for (var i = 0; i < 8; i++) {
      check.add(chunk);
    }
    expect(check.close(), isFalse);
    expect(clock.elapsed, lessThan(const Duration(seconds: 10)));
  });

  test('verifies what the release signer (tool/appcast.py) signs', () async {
    // The publisher signs the AppImage with tool/appcast.py; this is the same
    // code path, with a throwaway key made here and a 3 MiB message.
    var root = Directory.current;
    while (!File('${root.path}/tool/appcast.py').existsSync()) {
      final parent = root.parent;
      if (parent.path == root.path) {
        markTestSkipped('tool/appcast.py not found');
        return;
      }
      root = parent;
    }
    final directory = Directory.systemTemp.createTempSync('ed25519-python');
    addTearDown(() => directory.deleteSync(recursive: true));
    final message = Uint8List.fromList(
      List<int>.generate(3 << 20, (i) => (i * 31 + i ~/ 7) & 0xff),
    );
    File('${directory.path}/message').writeAsBytesSync(message);
    const script = r"""
import base64, os, sys
sys.path.insert(0, sys.argv[1] + '/tool')
import appcast
seed = os.urandom(32)
signature, _ = appcast.sign_file(seed, sys.argv[2])
print(appcast.public_key_text(seed))
print(base64.b64encode(signature).decode())
""";
    final ProcessResult result;
    try {
      result = await Process.run('python3', [
        '-c',
        script,
        root.path,
        '${directory.path}/message',
      ]);
    } on ProcessException {
      markTestSkipped('python3 is not installed');
      return;
    }
    expect(result.exitCode, 0, reason: '${result.stderr}');
    final [publicKey, signature] = '${result.stdout}'.trim().split('\n');
    Ed25519Verifier check() => Ed25519Verifier.fromBase64(publicKey, signature);
    expect((check()..add(message)).close(), isTrue);
    final tampered = Uint8List.fromList(message)..[2 << 20] ^= 1;
    expect((check()..add(tampered)).close(), isFalse);
  });
}
