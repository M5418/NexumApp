import 'package:flutter/widgets.dart';
import 'responsive_breakpoints.dart';

typedef ResponsiveWidgetBuilder = Widget Function(BuildContext context);

class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
    this.largeDesktop,
  });

  final ResponsiveWidgetBuilder mobile;
  final ResponsiveWidgetBuilder? tablet;
  final ResponsiveWidgetBuilder? desktop;
  final ResponsiveWidgetBuilder? largeDesktop;

  @override
  Widget build(BuildContext context) {
    switch (context.screenSize) {
      case ScreenSize.mobile:
        return mobile(context);
      case ScreenSize.tablet:
        return (tablet ?? mobile)(context);
      case ScreenSize.desktop:
        return (desktop ?? tablet ?? mobile)(context);
      case ScreenSize.largeDesktop:
        return (largeDesktop ?? desktop ?? tablet ?? mobile)(context);
    }
  }
}