// Web v1.24.0 components/auth/secondFactorSignIn.ts "D4: start with the
// method this device used last": the sign-in second step and "Verify it's
// you" open on the way this device answered with last, when the server lists
// it; otherwise on the first one listed. Only the method is kept (no
// account), under Web's key. Without device preferences (storage off) the
// listed order is used, as on Web.
import 'package:raft_client/raft_client.dart';

import 'device_preferences.dart';

/// Web `LAST_METHOD_KEY`; the value is the method's wire name.
const secondFactorLastMethodKey = 'raft.second-factor.last-method';

/// Web `rememberSecondFactorMethod`, after an answer passed.
void rememberSecondFactorMethod(SecondFactorMethod method) {
  try {
    DevicePreferences.current?.setString(
      secondFactorLastMethodKey,
      method.wire,
    );
  } catch (_) {
    // Storage off: the next sign-in starts with the listed order.
  }
}

/// Web `initialMethod`: the method used last here when [methods] lists it,
/// else the first listed, else null.
SecondFactorMethod? initialSecondFactorMethod(
  List<SecondFactorMethod> methods,
) {
  String? last;
  try {
    last = DevicePreferences.current?.getString(secondFactorLastMethodKey);
  } catch (_) {
    last = null;
  }
  for (final method in methods) {
    if (method.wire == last) return method;
  }
  return methods.firstOrNull;
}
