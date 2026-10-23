import 'package:flutter/widgets.dart';

/// [normal], or no time at all when the system asks for reduced motion (Web
/// `prefers-reduced-motion: reduce`, Android "remove animations", iOS "Reduce
/// Motion", Windows / macOS "reduce motion"): the change still happens, it is
/// just not animated.
Duration raftMotionDuration(BuildContext context, Duration normal) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : normal;
