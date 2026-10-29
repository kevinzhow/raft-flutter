import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

// Ed25519 (RFC 8032, pure) signature verification over a streamed message.
//
// Why not a package: the app's dependency tree has no Ed25519 implementation,
// and the published ones take the whole message as one `Uint8List`, while the
// signed message here is the whole AppImage (well over 100 MB). Verification
// needs only public data, so it is the short reference arithmetic of RFC 8032
// section 6 on `BigInt` plus the SHA-512 from `package:crypto` (already a
// dependency), fed chunk by chunk while the update is hashed anyway. The same
// arithmetic signs in `tool/appcast.py`; both are pinned by the RFC 8032 test
// vectors (test/ed25519_test.dart, tool/tests/test_appcast.py).
//
// The key pair is the one Sparkle uses for macOS and Windows (the base64 of
// the raw 32-byte public key; signatures are the base64 of the raw 64 bytes).

final BigInt _p = (BigInt.one << 255) - BigInt.from(19);
final BigInt _l =
    (BigInt.one << 252) +
    BigInt.parse('27742317777372353535851937790883648493');
final BigInt _d =
    (BigInt.from(-121665) * BigInt.from(121666).modInverse(_p)) % _p;
final BigInt _sqrtMinusOne = BigInt.two.modPow((_p - BigInt.one) >> 2, _p);

typedef _Point = (BigInt x, BigInt y, BigInt z, BigInt t);

final _Point _identity = (BigInt.zero, BigInt.one, BigInt.one, BigInt.zero);

BigInt? _recoverX(BigInt y, int sign) {
  if (y >= _p) return null;
  final x2 = (y * y - BigInt.one) * (_d * y * y + BigInt.one).modInverse(_p);
  final square = x2 % _p;
  if (square == BigInt.zero) return sign == 1 ? null : BigInt.zero;
  var x = square.modPow((_p + BigInt.from(3)) >> 3, _p);
  if ((x * x - square) % _p != BigInt.zero) x = x * _sqrtMinusOne % _p;
  if ((x * x - square) % _p != BigInt.zero) return null;
  if ((x.isOdd ? 1 : 0) != sign) x = _p - x;
  return x;
}

final _Point _base = () {
  final y = BigInt.from(4) * BigInt.from(5).modInverse(_p) % _p;
  final x = _recoverX(y, 0)!;
  return (x, y, BigInt.one, x * y % _p);
}();

_Point _add(_Point a, _Point b) {
  final a1 = (a.$2 - a.$1) * (b.$2 - b.$1) % _p;
  final b1 = (a.$2 + a.$1) * (b.$2 + b.$1) % _p;
  final c = BigInt.two * a.$4 * b.$4 * _d % _p;
  final d = BigInt.two * a.$3 * b.$3 % _p;
  final e = b1 - a1, f = d - c, g = d + c, h = b1 + a1;
  return (e * f % _p, g * h % _p, f * g % _p, e * h % _p);
}

_Point _multiply(BigInt scalar, _Point point) {
  var result = _identity;
  var addend = point;
  var rest = scalar;
  while (rest > BigInt.zero) {
    if (rest.isOdd) result = _add(result, addend);
    addend = _add(addend, addend);
    rest >>= 1;
  }
  return result;
}

_Point? _decode(List<int> bytes) {
  if (bytes.length != 32) return null;
  final value = _littleEndian(bytes);
  final sign = (value >> 255).toInt();
  final y = value & ((BigInt.one << 255) - BigInt.one);
  final x = _recoverX(y, sign);
  return x == null ? null : (x, y, BigInt.one, x * y % _p);
}

Uint8List _encode(_Point point) {
  final zInverse = point.$3.modInverse(_p);
  final x = point.$1 * zInverse % _p, y = point.$2 * zInverse % _p;
  final value = y | ((x.isOdd ? BigInt.one : BigInt.zero) << 255);
  return _toLittleEndian(value, 32);
}

Uint8List _toLittleEndian(BigInt value, int length) {
  final bytes = Uint8List(length);
  var rest = value;
  for (var i = 0; i < length; i++) {
    bytes[i] = (rest & BigInt.from(0xff)).toInt();
    rest >>= 8;
  }
  return bytes;
}

bool _equal(_Point a, _Point b) =>
    (a.$1 * b.$3 - b.$1 * a.$3) % _p == BigInt.zero &&
    (a.$2 * b.$3 - b.$2 * a.$3) % _p == BigInt.zero;

BigInt _littleEndian(List<int> bytes) {
  var value = BigInt.zero;
  for (var i = bytes.length - 1; i >= 0; i--) {
    value = (value << 8) | BigInt.from(bytes[i]);
  }
  return value;
}

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}

/// Checks one Ed25519 signature over a message that arrives in chunks.
///
/// ```dart
/// final check = Ed25519Verifier.fromBase64(publicKey, signature);
/// check.add(chunk); // the message, in order
/// final valid = check.close();
/// ```
class Ed25519Verifier {
  Ed25519Verifier._(this._a, this._r, this._s, this._sink, this._input);

  /// Throws [FormatException] when the key or the signature is not a valid
  /// encoding (wrong length, a point off the curve, or `S` out of range), so a
  /// malformed value is told apart from a signature that simply does not match.
  factory Ed25519Verifier(List<int> publicKey, List<int> signature) {
    if (publicKey.length != 32) {
      throw const FormatException('An Ed25519 public key is 32 bytes.');
    }
    if (signature.length != 64) {
      throw const FormatException('An Ed25519 signature is 64 bytes.');
    }
    final a = _decode(publicKey);
    if (a == null) {
      throw const FormatException('The Ed25519 public key is not a point.');
    }
    final rBytes = Uint8List.fromList(signature.sublist(0, 32));
    final r = _decode(rBytes);
    final s = _littleEndian(signature.sublist(32));
    if (r == null || s >= _l) {
      throw const FormatException('The Ed25519 signature is not valid.');
    }
    final sink = _DigestSink();
    final input = sha512.startChunkedConversion(sink)
      ..add(rBytes)
      ..add(publicKey);
    return Ed25519Verifier._(a, r, s, sink, input);
  }

  /// The Sparkle text forms: base64 of the 32-byte key and of the 64-byte
  /// signature. Throws [FormatException] like the default constructor.
  factory Ed25519Verifier.fromBase64(String publicKey, String signature) =>
      Ed25519Verifier(_base64(publicKey), _base64(signature));

  static List<int> _base64(String text) {
    try {
      return base64.decode(base64.normalize(text.trim()));
    } on FormatException {
      throw const FormatException('Not base64 text.');
    }
  }

  /// True when [text] is a base64 Ed25519 public key (32 bytes, on the curve).
  static bool isPublicKey(String text) {
    try {
      final bytes = _base64(text);
      return bytes.length == 32 && _decode(bytes) != null;
    } on FormatException {
      return false;
    }
  }

  final _Point _a, _r;
  final BigInt _s;
  final _DigestSink _sink;
  final ByteConversionSink _input;
  bool _closed = false;

  /// Feeds the next part of the signed message.
  void add(List<int> chunk) => _input.add(chunk);

  /// Ends the message and returns whether the signature is valid for it.
  bool close() {
    if (_closed) throw StateError('The verifier is already closed.');
    _closed = true;
    _input.close();
    final k = _littleEndian(_sink.value!.bytes) % _l;
    return _equal(_multiply(_s, _base), _add(_r, _multiply(k, _a)));
  }
}

/// Signs [message] with the 32-byte [seed] (RFC 8032) and returns the public
/// key and the 64-byte signature.
///
/// For tests only: the app never signs. Releases are signed by
/// `tool/appcast.py` in CI; the tests cross-check the two.
@visibleForTesting
({Uint8List publicKey, Uint8List signature}) ed25519SignForTesting(
  List<int> seed,
  List<int> message,
) {
  final h = sha512.convert(seed).bytes;
  final scalar =
      (_littleEndian(h.sublist(0, 32)) &
          ((BigInt.one << 254) - BigInt.from(8))) |
      (BigInt.one << 254);
  final publicKey = _encode(_multiply(scalar, _base));
  BigInt digest(List<List<int>> parts) =>
      _littleEndian(sha512.convert([for (final part in parts) ...part]).bytes);
  final r = digest([h.sublist(32), message]) % _l;
  final rPoint = _encode(_multiply(r, _base));
  final k = digest([rPoint, publicKey, message]) % _l;
  final s = (r + k * scalar) % _l;
  return (
    publicKey: publicKey,
    signature: Uint8List.fromList([...rPoint, ..._toLittleEndian(s, 32)]),
  );
}

/// Convenience for a message held in memory: false for any malformed input.
bool verifyEd25519(
  List<int> publicKey,
  List<int> signature,
  List<int> message,
) {
  try {
    return (Ed25519Verifier(publicKey, signature)..add(message)).close();
  } on FormatException {
    return false;
  }
}
