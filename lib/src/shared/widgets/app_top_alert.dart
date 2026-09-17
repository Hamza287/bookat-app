import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/constants.dart';

/// A banner that slides in from the top of the screen.
///
/// Preferred over a `SnackBar` for confirmations and errors: a SnackBar docks
/// to the bottom, where forms put their action buttons, so it covers the very
/// control the user is about to press. This sits above the content instead.
///
/// It is inserted into the root [Overlay], so it survives a route push and
/// stays visible while the next screen opens.
class AppTopAlert {
  const AppTopAlert._();

  static const _visibleFor = Duration(seconds: 3);

  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    if (message.trim().isEmpty) {
      return;
    }

    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    var removed = false;

    void remove() {
      // Reverse animation and a tap can both land here; removing twice throws.
      if (removed) {
        return;
      }
      removed = true;
      entry.remove();
    }

    entry = OverlayEntry(
      builder: (_) => _TopAlert(
        message: message,
        isError: isError,
        visibleFor: _visibleFor,
        onDismissed: remove,
      ),
    );

    overlay.insert(entry);
  }
}

class _TopAlert extends StatefulWidget {
  const _TopAlert({
    required this.message,
    required this.isError,
    required this.visibleFor,
    required this.onDismissed,
  });

  final String message;
  final bool isError;
  final Duration visibleFor;
  final VoidCallback onDismissed;

  @override
  State<_TopAlert> createState() => _TopAlertState();
}

class _TopAlertState extends State<_TopAlert>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(widget.visibleFor, _dismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    _timer?.cancel();
    if (!mounted) {
      return;
    }

    await _controller.reverse();
    if (mounted) {
      widget.onDismissed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final background = widget.isError ? colors.error : colors.primary;

    return Positioned(
      top: MediaQuery.of(context).padding.top + AppDimensions.spacingMd,
      left: AppDimensions.spacingLg,
      right: AppDimensions.spacingLg,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1.4),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
        ),
        child: FadeTransition(
          opacity: _controller,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              // Tapping dismisses early, and an upward swipe feels natural for
              // something that came down from the top.
              onTap: _dismiss,
              onVerticalDragEnd: (details) {
                if ((details.primaryVelocity ?? 0) < 0) {
                  _dismiss();
                }
              },
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusMedium,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow,
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.spacingMd),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        widget.isError
                            ? Icons.error_outline_rounded
                            : Icons.check_circle_rounded,
                        color: colors.textOnPrimary,
                      ),
                      const SizedBox(width: AppDimensions.spacingSm),
                      Expanded(
                        child: Text(
                          widget.message,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: colors.textOnPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
