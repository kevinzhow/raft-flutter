/// feedbackTicketUrl (feedback/feedbackTicketLink.ts, feedbackPaths.ts): a
/// ticket's own browser-openable address, Settings > Feedback > the ticket, on
/// the web [origin]. Null without a server [slug]: settings only live under
/// `/s/<slug>`. The web's `?platform=` suffix for a ticket filed in a mobile
/// App does not apply here: this client files its tickets in the web's own
/// Hands app.
String? feedbackTicketUrl({
  required Uri origin,
  required String? slug,
  required String ticketId,
}) {
  if (slug == null || slug.isEmpty) return null;
  return '${origin.origin}/s/$slug/settings/feedback/ticket/'
      '${Uri.encodeComponent(ticketId)}';
}
