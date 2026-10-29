import '../data/resource_snapshot_cache.dart';

/// The recently visited Search request shapes (query and filters, without the
/// window) and their last accepted results. A revisit of the Search page finds
/// the window of the query it restores and shows it at once, then revalidates
/// it in place (Source keeps the search store across navigation).
class SearchSnapshot extends PageSnapshot {
  const SearchSnapshot({
    required super.identity,
    required this.windows,
    required this.channelAccess,
  });

  final Map<String, ResourceViewWindow> windows;
  final Map<String, Map<String, dynamic>> channelAccess;
}
