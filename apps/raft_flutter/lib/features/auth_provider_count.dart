// Web v1.24 hooks/useAuthProviders.ts `expectedCount`: how many sign-in
// buttons a server showed last time, so a sign-in page keeps their space
// while `/auth/providers` is on its way and nothing moves when they arrive.
// Web remembers it per browser; the app per server origin for this run. A
// server not seen yet reserves every provider Raft has (Google, GitHub,
// Apple), what production shows.

const _allProviders = 3;
final _seen = <String, int>{};

/// The buttons to reserve for [origin] while its providers load.
int expectedAuthProviders(String origin) => _seen[origin] ?? _allProviders;

/// Records what [origin] answered (enabled providers only).
void rememberAuthProviders(String origin, int count) =>
    _seen[origin] = count.clamp(0, _allProviders);
