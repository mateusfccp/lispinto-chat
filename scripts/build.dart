import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('android', help: 'Build for Android', defaultsTo: true)
    ..addFlag('macos', help: 'Build for macOS', defaultsTo: true)
    ..addFlag('web', help: 'Build for Web', defaultsTo: true)
    ..addFlag('ios', help: 'Build for iOS', defaultsTo: true)
    ..addOption(
      'output',
      abbr: 'o',
      help: 'Output directory',
      defaultsTo: 'dist',
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help');

  final results = parser.parse(arguments);

  if (results['help'] as bool) {
    stdout.writeln('Usage: dart scripts/build.dart [options]');
    stdout.writeln(parser.usage);
    return;
  }

  final outputDir = Directory(results['output'] as String);
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  final platforms = {
    'android': results['android'] as bool,
    'macos': results['macos'] as bool,
    'web': results['web'] as bool,
    'ios': results['ios'] as bool,
  };

  if (platforms['android']!) {
    await buildAndroid(outputDir);
  }

  if (platforms['macos']!) {
    await buildMacOS(outputDir);
  }

  if (platforms['web']!) {
    await buildWeb(outputDir);
  }

  if (platforms['ios']!) {
    await buildIOS(outputDir);
  }

  stdout.writeln('\nBuild process completed! Files are in ${outputDir.path}');
}

Future<void> buildAndroid(Directory outputDir) async {
  stdout.writeln('Building Android APK (split-per-abi)...');
  await _runFlutter(['build', 'apk', '--release', '--split-per-abi']);

  final apkDir = Directory('build/app/outputs/flutter-apk');
  if (apkDir.existsSync()) {
    final destination = Directory(join(outputDir.path, 'android'));
    if (!destination.existsSync()) destination.createSync(recursive: true);

    await for (final file in apkDir.list()) {
      if (file is File &&
          file.path.endsWith('.apk') &&
          !file.path.contains('output-metadata.json')) {
        await file.copy(join(destination.path, basename(file.path)));
      }
    }
  }
}

Future<void> buildMacOS(Directory outputDir) async {
  stdout.writeln('Building macOS...');
  await _runFlutter(['build', 'macos', '--release']);

  final macDir = Directory('build/macos/Build/Products/Release');
  if (macDir.existsSync()) {
    final destination = Directory(join(outputDir.path, 'macos'));
    if (!destination.existsSync()) destination.createSync(recursive: true);

    // Copy the .app bundle
    await for (final item in macDir.list()) {
      if (item is Directory && item.path.endsWith('.app')) {
        final destPath = join(destination.path, basename(item.path));
        await _copyDirectory(item, Directory(destPath));
      }
    }
  }
}

Future<void> buildWeb(Directory outputDir) async {
  stdout.writeln('Building Web (WASM)...');
  await _runFlutter(['build', 'web', '--release', '--wasm']);

  final webDir = Directory('build/web');
  if (webDir.existsSync()) {
    final destination = Directory(join(outputDir.path, 'web'));
    if (!destination.existsSync()) destination.createSync(recursive: true);
    await _copyDirectory(webDir, destination);
  }
}

Future<void> buildIOS(Directory outputDir) async {
  stdout.writeln('Building iOS IPA...');
  await _runFlutter(['build', 'ipa', '--release', '--no-codesign']);

  final ipaDir = Directory('build/ios/ipa');
  if (ipaDir.existsSync()) {
    final destination = Directory(join(outputDir.path, 'ios'));
    if (!destination.existsSync()) destination.createSync(recursive: true);

    await for (final file in ipaDir.list()) {
      if (file is File && file.path.endsWith('.ipa')) {
        await file.copy(join(destination.path, basename(file.path)));
      }
    }
  }
}

Future<void> _runFlutter(List<String> args) async {
  final result = await Process.run('flutter', args);
  if (result.exitCode != 0) {
    stdout.writeln('Error running flutter ${args.join(' ')}:');
    stdout.writeln(result.stderr);
    exit(result.exitCode);
  }
  stdout.writeln(result.stdout);
}

Future<void> _copyDirectory(Directory source, Directory destination) async {
  await for (final entity in source.list(recursive: false)) {
    if (entity is Directory) {
      final newDirectory = Directory(
        join(destination.absolute.path, basename(entity.path)),
      );
      await newDirectory.create(recursive: true);
      await _copyDirectory(entity.absolute, newDirectory);
    } else if (entity is File) {
      await entity.copy(join(destination.path, basename(entity.path)));
    }
  }
}
