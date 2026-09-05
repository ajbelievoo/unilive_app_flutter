import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Global route observer used to detect when the home (MainScreen) route
/// becomes active again after a pushed route is popped. Screens can mix in
/// [RouteAware] and subscribe to this observer to auto-refresh on return.
final RouteObserver<Route<dynamic>> routeObserver =
    RouteObserver<Route<dynamic>>();
