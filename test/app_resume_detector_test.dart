import 'package:bookat/src/core/utils/app_resume_detector.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// `resumed` fires for far more than returning from the background. Pulling
/// down the notification shade sends the app to `inactive` and straight back
/// to `resumed`, and treating that as a resume made every screen refetch each
/// time the shade was opened.
void main() {
  late AppResumeDetector detector;

  setUp(() => detector = AppResumeDetector());

  /// Feeds a run of states and reports which ones counted as a return.
  List<AppLifecycleState> returnsFor(List<AppLifecycleState> states) {
    return [
      for (final state in states)
        if (detector.didReturnFromBackground(state)) state,
    ];
  }

  group('interruptions that are not a resume', () {
    test('pulling down the notification shade', () {
      // The shade is an overlay: the app is interrupted but never backgrounded.
      expect(
        returnsFor(const [
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]),
        isEmpty,
      );
    });

    test('opening and closing it repeatedly', () {
      expect(
        returnsFor(const [
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]),
        isEmpty,
      );
    });

    test('a permission dialog or call banner', () {
      expect(
        returnsFor(const [
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]),
        isEmpty,
      );
    });

    test('a bare resumed with no prior interruption', () {
      expect(returnsFor(const [AppLifecycleState.resumed]), isEmpty);
    });
  });

  group('a real return from the background', () {
    test('counts once, through the full transition', () {
      // What Flutter emits going to the launcher and back.
      expect(
        returnsFor(const [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]),
        [AppLifecycleState.resumed],
      );
    });

    test('is not re-counted by a later shade pull', () {
      expect(
        returnsFor(const [
          AppLifecycleState.paused,
          AppLifecycleState.resumed,
          // Shade, straight after coming back.
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]),
        hasLength(1),
      );
    });

    test('each background trip counts separately', () {
      expect(
        returnsFor(const [
          AppLifecycleState.paused,
          AppLifecycleState.resumed,
          AppLifecycleState.paused,
          AppLifecycleState.resumed,
        ]),
        hasLength(2),
      );
    });

    test('detached counts as backgrounded too', () {
      expect(
        returnsFor(const [
          AppLifecycleState.detached,
          AppLifecycleState.resumed,
        ]),
        hasLength(1),
      );
    });

    test('hidden alone is not enough', () {
      // On mobile `hidden` is a step towards `paused`, which does the work.
      expect(
        returnsFor(const [
          AppLifecycleState.hidden,
          AppLifecycleState.resumed,
        ]),
        isEmpty,
      );
    });
  });
}
