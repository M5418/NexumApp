import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

enum ScreenSize { mobile, tablet, desktop, largeDesktop }

class Breakpoints {
  // Material-like, tuned to include large phones and many tablets
  static const double mobile = 600;    // <600
  static const double tablet = 1024;   // 600..1023
  static const double desktop = 1440;  // 1024..1439
  static const double largeDesktop = 1920; // 1440+
}

extension ScreenSizeX on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  ScreenSize get screenSize {
    final w = screenWidth;
    if (w < Breakpoints.mobile) return ScreenSize.mobile;
    if (w < Breakpoints.tablet) return ScreenSize.tablet;
    if (w < Breakpoints.desktop) return ScreenSize.desktop;
    return ScreenSize.largeDesktop;
  }

  bool get isMobile => screenSize == ScreenSize.mobile;
  bool get isTablet => screenSize == ScreenSize.tablet;
  bool get isDesktop => screenSize == ScreenSize.desktop;
  bool get isLargeDesktop => screenSize == ScreenSize.largeDesktop;
}

/// Show the app-download banner for web users on small/medium screens.
/// Threshold intentionally <=1200 to include big phones and up to ~12" tablets.
bool shouldShowDownloadBanner(BuildContext context) {
  if (!kIsWeb) return false;
  final w = MediaQuery.sizeOf(context).width;
  return w <= 1200;
}