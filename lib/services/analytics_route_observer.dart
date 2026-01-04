import 'package:flutter/material.dart';
import 'analytics_service.dart';

/// Custom NavigatorObserver that logs screen views to Firebase Analytics.
/// 
/// This observer tracks route changes (push, pop, replace, remove) and
/// logs screen_view events for each navigation action.
class AnalyticsRouteObserver extends NavigatorObserver {
  final AnalyticsService _analyticsService;

  AnalyticsRouteObserver({AnalyticsService? analyticsService})
      : _analyticsService = analyticsService ?? AnalyticsService.instance;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _logScreenView(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    // Log the screen we're returning to
    if (previousRoute != null) {
      _logScreenView(previousRoute);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _logScreenView(newRoute);
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    // Log the screen we're returning to after removal
    if (previousRoute != null) {
      _logScreenView(previousRoute);
    }
  }

  /// Extracts screen name from route and logs the screen view.
  void _logScreenView(Route<dynamic> route) {
    final settings = route.settings;
    final screenName = _extractScreenName(settings);
    final screenClass = _extractScreenClass(route);

    _analyticsService.logScreenView(
      screenName: screenName,
      screenClass: screenClass,
    );
  }

  /// Extracts a clean screen name from route settings.
  String _extractScreenName(RouteSettings settings) {
    final name = settings.name;
    if (name == null || name.isEmpty) {
      // Try to get name from arguments if it's a map with 'screenName'
      final args = settings.arguments;
      if (args is Map<String, dynamic>) {
        final screenName = args['screenName'];
        if (screenName is String && screenName.isNotEmpty) {
          return screenName;
        }
      }
      return 'unknown_screen';
    }
    // Remove leading slash and clean up
    String cleanName = name.startsWith('/') ? name.substring(1) : name;
    // Handle empty after removing slash (root route)
    if (cleanName.isEmpty) {
      cleanName = 'home';
    }
    return cleanName;
  }

  /// Extracts the screen class name from the route.
  String _extractScreenClass(Route<dynamic> route) {
    // Try to get the widget type from MaterialPageRoute or similar
    if (route is MaterialPageRoute) {
      // The builder creates the widget, but we can't easily get the type
      // Use the route's runtime type as fallback
      return route.runtimeType.toString();
    }
    return route.runtimeType.toString();
  }
}
