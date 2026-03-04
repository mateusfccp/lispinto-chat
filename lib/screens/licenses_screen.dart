import 'package:flutter/material.dart';

/// A screen that displays the open-source licenses for all packages used by
/// the application.
///
/// This delegates to Flutter's built-in [LicensePage], which automatically
/// collects licenses from the license registry.
final class LicensesScreen extends StatelessWidget {
  /// Creates a [LicensesScreen].
  const LicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LicensePage(applicationName: 'Lispinto Chat');
  }
}
