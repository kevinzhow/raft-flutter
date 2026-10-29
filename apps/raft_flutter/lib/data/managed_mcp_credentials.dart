/// Mounted Web v1.21.12 managedMcpCredentials.ts. Catalog responses contain
/// header names only; an unchanged blank row retains its encrypted value.
class ManagedMcpHeader {
  const ManagedMcpHeader(this.name, this.value, {this.persistedName});
  final String name, value;
  final String? persistedName;

  String get normalizedName => name.trim().toLowerCase();
  bool get retainsValue =>
      persistedName != null &&
      normalizedName == persistedName!.trim().toLowerCase();
}

const managedMcpHeaderError =
    'Credential header names must be unique, and new or renamed headers need a value.';

bool managedMcpHeadersIncomplete(List<ManagedMcpHeader> headers) {
  final names = <String>{};
  return headers.any(
    (header) =>
        header.normalizedName.isEmpty ||
        !names.add(header.normalizedName) ||
        !header.retainsValue && header.value.trim().isEmpty,
  );
}

Map<String, dynamic> managedMcpCredentials({
  required bool creating,
  required String authMode,
  required List<ManagedMcpHeader> headers,
  required List<String> persistedNames,
}) {
  if (authMode != 'headers') return {};
  if (creating) {
    return {
      'headers': {
        for (final header in headers) header.name.trim(): header.value,
      },
    };
  }
  final retained = {
    for (final header in headers)
      if (header.retainsValue) header.normalizedName,
  };
  return {
    'credentialPatch': {
      'upsertHeaders': {
        for (final header in headers)
          if (header.value.trim().isNotEmpty) header.name.trim(): header.value,
      },
      'removeHeaderNames': [
        for (final name in persistedNames)
          if (!retained.contains(name.trim().toLowerCase())) name,
      ],
    },
  };
}
