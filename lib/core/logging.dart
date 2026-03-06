import 'package:ansicolor/ansicolor.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

AnsiPen _levelColor(Level level) {
  return switch (level) {
    .SHOUT => AnsiPen()..magenta(),
    .SEVERE => AnsiPen()..red(),
    .WARNING => AnsiPen()..yellow(),
    .INFO => AnsiPen()..blue(),
    .CONFIG => AnsiPen()..cyan(),
    .FINE || .FINER || .FINEST => AnsiPen()..green(),
    _ => AnsiPen(),
  };
}

/// Configures the root logger for the application.
void setupLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    if (kDebugMode) {
      final pen = _levelColor(record.level);
      debugPrint(
        '[${pen(record.level.name)}] ${record.time}: [${record.loggerName}] ${record.message}',
      );
      if (record.error != null) {
        debugPrint('Error: ${record.error}');
      }
      if (record.stackTrace != null) {
        debugPrintStack(stackTrace: record.stackTrace);
      }
    }
  });
}
