/// AIFeatureGuard — widget wrapper that conditionally shows / hides / locks
/// a child widget based on the Master AI Control Engine feature flags.
///
/// Behaviour:
///  * [AIFeatureState.available]  → render [child] as-is.
///  * [AIFeatureState.locked]     → render [lockedBuilder] (default: child
///    with a lock badge). On tap, show a toast/snackbar with the admin
///    `lockedMessage` and optionally navigate to [lockedAction].
///  * [AIFeatureState.disabled]   → render [hiddenBuilder] (default:
///    `SizedBox.shrink()`), i.e. completely remove the button.
///
/// Use this anywhere a Live Room / Audio Room overlay button is gated by an
/// AI feature (voice changer, 3D spatial audio, beauty effects, PK
/// matchmaker, 3D gift trigger, etc.).
library;

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/ai_feature_model.dart';
import '../providers/ai_feature_manager.dart';
import '../routes/app_routes.dart';

class AIFeatureGuard extends StatelessWidget {
  const AIFeatureGuard({
    super.key,
    required this.featureKey,
    required this.child,
    this.lockedBuilder,
    this.hiddenBuilder,
    this.onLockedTap,
    this.showToastOnLocked = true,
  });

  /// Feature key to evaluate (see [AIFeatureKeys]).
  final String featureKey;

  /// Widget to render when the feature is available to the current user.
  final Widget child;

  /// Override the default locked appearance (child + lock badge). If null,
  /// a default [AIFeatureLockedButton] wrapping [child] is used.
  final WidgetBuilder? lockedBuilder;

  /// Override the default hidden appearance. Defaults to a zero-size box.
  final WidgetBuilder? hiddenBuilder;

  /// Optional extra callback invoked when the locked button is tapped (in
  /// addition to the default toast / navigation).
  final VoidCallback? onLockedTap;

  /// If false, suppresses the default toast when the locked button is tapped.
  final bool showToastOnLocked;

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AIFeatureManager>();
    final state = ai.stateForCurrentUser(featureKey);
    switch (state) {
      case AIFeatureState.available:
        return child;
      case AIFeatureState.locked:
        final feature = ai.feature(featureKey);
        final message = ai.lockedMessageFor(featureKey);
        final action = ai.lockedActionFor(featureKey);
        return lockedBuilder?.call(context) ??
            AIFeatureLockedButton(
              message: message,
              actionRoute: action,
              featureKey: featureKey,
              disabledBehavior: feature?.uiBehavior.disabledBehavior ?? 'locked',
              onLockedTap: onLockedTap,
              showToastOnLocked: showToastOnLocked,
              child: child,
            );
      case AIFeatureState.disabled:
        return hiddenBuilder?.call(context) ?? const SizedBox.shrink();
    }
  }
}

/// Default locked-button appearance: clones the child but intercepts taps
/// to show the admin `lockedMessage` and optionally navigate to the
/// `lockedAction` route.
class AIFeatureLockedButton extends StatelessWidget {
  const AIFeatureLockedButton({
    super.key,
    required this.child,
    required this.message,
    required this.featureKey,
    this.actionRoute,
    this.disabledBehavior = 'locked',
    this.onLockedTap,
    this.showToastOnLocked = true,
  });

  final Widget child;
  final String message;
  final String featureKey;
  final String? actionRoute;
  final String disabledBehavior;
  final VoidCallback? onLockedTap;
  final bool showToastOnLocked;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _onTap(context),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topLeft,
        children: [
          // Render the child greyed-out so the user can see what they would
          // get, but it is clearly not interactive.
          Opacity(opacity: 0.45, child: IgnorePointer(ignoring: true, child: child)),
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.amber,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock, size: 12, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  void _onTap(BuildContext context) {
    onLockedTap?.call();
    if (showToastOnLocked) {
      Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.black87,
        textColor: Colors.white,
      );
    }
    final route = actionRoute;
    if (route != null && route.isNotEmpty) {
      // Map a few well-known short codes to app routes.
      switch (route) {
        case 'vip':
          context.pushNamed(AppRoutes.vip);
          break;
        case 'wallet':
        case 'recharge':
          context.pushNamed(AppRoutes.recharge);
          break;
        case 'store':
          context.pushNamed(AppRoutes.store);
          break;
        default:
          // Treat as a named GoRouter route.
          try {
            context.pushNamed(route);
          } catch (_) {
            // Unknown route — ignore; the toast already told the user.
          }
      }
    }
  }
}
