import 'package:meta/meta_meta.dart';

/// Annotation to mark a class for which localization files should be generated.
@Target({TargetKind.classType})
final class GenerateLocalizations {
  /// Creates a [GenerateLocalizations] annotation.
  const GenerateLocalizations();
}
