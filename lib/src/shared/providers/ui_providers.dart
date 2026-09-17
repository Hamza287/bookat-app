import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Password-visibility toggle, keyed by a caller-chosen id so unrelated
/// fields (e.g. login vs. register) don't share state. Purely local UI state
/// with no reason to live anywhere but a provider that resets once the
/// screen holding the field is gone.
final obscureTextProvider = StateProvider.autoDispose.family<bool, String>(
  (ref, key) => true,
);
