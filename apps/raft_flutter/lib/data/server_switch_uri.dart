import 'raft_location.dart';

/// Where switching to the server [slug] lands on a phone (Web v1.24
/// `handleSelectServer` -> `tabHomeFor(tab, newSlug)`): the same tab root in
/// the next server (Activity stays Activity), Home otherwise.
Uri serverSwitchUri(RaftLocation? current, String slug) {
  final route = current?.route;
  return RaftLocation.at(
    serverSlug: slug,
    route:
        const {
          RaftRoute.activity,
          RaftRoute.tasks,
          RaftRoute.search,
        }.contains(route)
        ? route!
        : RaftRoute.home,
  ).uri;
}
