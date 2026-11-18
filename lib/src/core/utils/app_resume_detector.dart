import 'package:flutter/widgets.dart';

/// Tells a real return from the background apart from a momentary interruption.
///
/// `AppLifecycleState.resumed` fires far more often than people expect. Pulling
/// down the notification shade or quick settings, a permission dialog, the
/// volume slider, an incoming call banner and the task-switcher preview all
/// send the app to `inactive` and then straight back to `resumed` without it
/// ever being backgrounded. Refreshing on every one of those made the screen
/// reload each time the shade was opened.
///
/// Only `paused` (and `detached`) mean the app genuinely left the foreground,
/// so the return trip is counted from there.
class AppResumeDetector {
  bool _wasBackgrounded = false;

  /// Whether the app has actually been backgrounded and not yet come back.
  @visibleForTesting
  bool get wasBackgrounded => _wasBackgrounded;

  /// Feed every lifecycle change here.
  ///
  /// Returns true exactly once per genuine foreground return, and false for
  /// the interruptions above.
  bool didReturnFromBackground(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _wasBackgrounded = true;
        return false;

      case AppLifecycleState.resumed:
        final returned = _wasBackgrounded;
        _wasBackgrounded = false;
        return returned;

      // `hidden` is a step on the way to `paused` on mobile, so it is not
      // treated as backgrounding on its own — `paused` follows and does it.
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        return false;
    }
  }
}
