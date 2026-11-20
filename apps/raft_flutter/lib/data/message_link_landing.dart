/// A failed external message landing belongs to the entry and authority
/// which produced it. No target information is exposed by the failure.
class MessageLinkLanding {
  const MessageLinkLanding({
    required this.authority,
    required this.revision,
    required this.onBack,
  });

  final String authority;
  final int revision;
  final void Function() onBack;
}
