import 'package:flutter/widgets.dart';

/// Tells screens when a route above them pops, so they can refresh data that
/// may have changed meanwhile. Registered in the app's `navigatorObservers`;
/// screens subscribe through [RouteAware].
final appRouteObserver = RouteObserver<ModalRoute<void>>();
