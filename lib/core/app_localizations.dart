import 'package:fluent_i18n/fluent_i18n.dart';
import 'package:flutter/material.dart';

import 'generate_localizations_annotation.dart';

part 'app_localizations.g.dart';

/// The class that provides access to localized strings for the app. This
@GenerateLocalizations()
final class AppLocalizations with _$AppLocalizationsMixin {
  /// Gets the [AppLocalizations] instance for the given [context].
  factory AppLocalizations.of(BuildContext context) =>
      AppLocalizations._(context);

  AppLocalizations._(BuildContext context) : _context = context;

  final BuildContext _context;

  @override
  FluentLocalizations get fluent => FluentLocalizations.of(_context)!;
}
