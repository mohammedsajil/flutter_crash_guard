import 'package:flutter/material.dart';
import 'package:flutter_crash_guard/src/crashlytics_service.dart';

/// A NavigatorObserver that logs screen changes to Firebase Crashlytics.
class CrashlyticsNavigatorObserver extends NavigatorObserver {
  final ErrorHandlingService errorHandlingService;

  CrashlyticsNavigatorObserver(this.errorHandlingService);

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    _logScreenChange(route, 'Push');
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    _logScreenChange(previousRoute, 'Pop'); // Log the screen we're returning to
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _logScreenChange(newRoute, 'Replace');
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    super.didRemove(route, previousRoute);
    // This is less common for screen tracking, but can be useful
    _logScreenChange(previousRoute, 'Remove'); // Log the screen that might become active
  }

  void _logScreenChange(Route? route, String action) {
    final screenName = route?.settings.name;
    if (screenName != null && screenName.isNotEmpty) {
      errorHandlingService.log('Navigation: $action to $screenName');
      errorHandlingService.setCustomKey('current_screen', screenName);
    } else {
      // For routes without names (e.g., MaterialPageRoute without a name)
      // You might want to log the route type or a generic message.
      errorHandlingService.log('Navigation: $action to unnamed route (${route.runtimeType})');
      errorHandlingService.setCustomKey('current_screen', 'Unnamed Route: ${route.runtimeType}');
    }
  }
}
