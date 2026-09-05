/// System UI / navigation handling service.
///
/// Detects the Android navigation mode (3-button, 2-button, gesture) via a
/// platform channel and applies the correct [SystemUiMode] so that the app
/// draws edge-to-edge behind the status bar, but never draws behind a visible
/// 3-button navigation bar.
library system_ui_service;

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Android navigation interaction modes.
enum NavigationMode {
  /// Classic 3-button navigation (back / home / recents).
  threeButton,

  /// 2-button navigation (back + pill).
  twoButton,

  /// Full gesture navigation.
  gesture,

  /// Navigation bar is hidden / not present.
  hidden,

  /// Could not be determined.
  unknown;

  static NavigationMode fromString(String? value) {
    switch (value) {
      case 'threeButton':
        return NavigationMode.threeButton;
      case 'twoButton':
        return NavigationMode.twoButton;
      case 'gesture':
        return NavigationMode.gesture;
      case 'hidden':
        return NavigationMode.hidden;
      default:
        return NavigationMode.unknown;
    }
  }

  /// Whether this mode means a visible (button) navigation bar.
  bool get hasVisibleNavigationBar =>
      this == NavigationMode.threeButton || this == NavigationMode.twoButton;
}

class SystemUiService {
  static const String _channelName = 'com.believoo.app/system';
  static const _channel = MethodChannel(_channelName);

  SystemUiService._();
  static final SystemUiService instance = SystemUiService._();

  NavigationMode? _lastMode;

  /// Current navigation mode (or [NavigationMode.unknown] on iOS/fallback).
  Future<NavigationMode> getNavigationMode() async {
    if (!Platform.isAndroid) return NavigationMode.gesture;
    try {
      final value = await _channel.invokeMethod<String>('getNavigationMode');
      _lastMode = NavigationMode.fromString(value);
    } catch (e) {
      _lastMode = NavigationMode.unknown;
    }
    return _lastMode ?? NavigationMode.unknown;
  }

  /// True if the device should be rendered edge-to-edge (full screen) at the
  /// bottom (i.e. no visible 3-button nav bar).
  Future<bool> shouldUseEdgeToEdge() async {
    final mode = await getNavigationMode();
    return !mode.hasVisibleNavigationBar;
  }

  /// Apply the default app system UI (used on launch and when leaving a live
  /// room). Status bar is transparent so the app draws behind it; the
  /// navigation bar is given a solid color when a visible 3-button bar is
  /// present, while gesture/hidden devices use full transparent edge-to-edge.
  Future<void> applyDefault() async {
    final useEdgeToEdge = await shouldUseEdgeToEdge();
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    if (useEdgeToEdge) {
      // Gesture / hidden nav: full edge-to-edge, nothing opaque at the bottom.
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarContrastEnforced: false,
        ),
      );
    } else {
      // Visible 3/2-button nav: app behind status, solid bar at the bottom.
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: AppTheme.background,
          systemNavigationBarIconBrightness: Brightness.dark,
          systemNavigationBarDividerColor: AppTheme.background,
        ),
      );
    }
  }

  /// Apply the live-room system UI. Dark, edge-to-edge status, but keeps a
  /// solid navigation bar when a 3-button bar is present.
  Future<void> applyForLive() async {
    final useEdgeToEdge = await shouldUseEdgeToEdge();
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    if (useEdgeToEdge) {
      // Gesture / hidden nav: full dark edge-to-edge.
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarDividerColor: Colors.transparent,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarContrastEnforced: false,
        ),
      );
    } else {
      // Visible 3/2-button nav: dark status (app behind), solid black nav.
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.black,
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarDividerColor: Colors.black,
        ),
      );
    }
  }

  /// Restore the default app UI (e.g. on dispose of a live room).
  Future<void> restoreDefault() => applyDefault();
}
