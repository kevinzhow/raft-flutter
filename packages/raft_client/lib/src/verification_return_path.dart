final _unsafeReturnPath = RegExp(
  r'\\|%5c|[\x00-\x1f\x7f]',
  caseSensitive: false,
);

Uri? raftVerificationReturnPath(Object? value) {
  if (value is! String ||
      value.length > 2048 ||
      !value.startsWith('/') ||
      value.startsWith('//') ||
      _unsafeReturnPath.hasMatch(value)) {
    return null;
  }
  final uri = Uri.tryParse(value)?.normalizePath();
  if (uri == null ||
      uri.hasAuthority ||
      uri.hasScheme ||
      uri.path.startsWith('//') ||
      uri.toString().length > 2048 ||
      uri.toString() == '/') {
    return null;
  }
  return uri;
}
