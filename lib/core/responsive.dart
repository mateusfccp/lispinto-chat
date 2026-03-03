import 'package:flutter/widgets.dart';

/// Extension on [BuildContext] to provide responsive design utilities.
extension ResponsiveBuildContext on BuildContext {
  /// Returns `true` if the screen width is greater than 600 pixels.
  bool get isDesktop => MediaQuery.sizeOf(this).width > 600;

  /// Returns `true` if the screen width is less than or equal to 600 pixels.
  bool get isMobile => MediaQuery.sizeOf(this).width <= 600;
}
