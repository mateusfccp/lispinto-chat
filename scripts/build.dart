import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('android-apks', help: 'Build Android APKs', defaultsTo: true)
    ..addFlag('android-aab', help: 'Build Android AAB', defaultsTo: true)
    ..addFlag('macos', help: 'Build for macOS', defaultsTo: true)
    ..addFlag('web', help: 'Build for Web', defaultsTo: true)
    ..addFlag('ios', help: 'Build for iOS', defaultsTo: true)
    ..addFlag('linux', help: 'Build for Linux (AppImage)', defaultsTo: true)
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
    'android-apks': results['android-apks'] as bool,
    'android-aab': results['android-aab'] as bool,
    'macos': results['macos'] as bool,
    'web': results['web'] as bool,
    'ios': results['ios'] as bool,
    'linux': results['linux'] as bool,
  };

  if (platforms['android-apks']!) {
    await buildAndroidApks(outputDir);
  }

  if (platforms['android-aab']!) {
    await buildAndroidAab(outputDir);
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

  if (platforms['linux']!) {
    await buildLinux(outputDir);
  }

  stdout.writeln('\nBuild process completed! Files are in ${outputDir.path}');
}

Future<void> buildAndroidApks(Directory outputDir) async {
  stdout.writeln('Building Android APKs (split-per-abi)...');
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

Future<void> buildAndroidAab(Directory outputDir) async {
  stdout.writeln('Building Android AAB...');
  await _runFlutter(['build', 'appbundle', '--release']);

  final aabDir = Directory('build/app/outputs/bundle/release');
  if (aabDir.existsSync()) {
    final destination = Directory(join(outputDir.path, 'android'));
    if (!destination.existsSync()) destination.createSync(recursive: true);

    await for (final file in aabDir.list()) {
      if (file is File && file.path.endsWith('.aab')) {
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
  await _runFlutter([
    'build',
    'ipa',
    '--release',
    '--export-method',
    'development',
  ]);

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

Future<void> buildLinux(Directory outputDir) async {
  stdout.writeln('Building Linux...');
  await _runFlutter(['build', 'linux', '--release']);

  final bundleDir = Directory('build/linux/x64/release/bundle');
  if (!bundleDir.existsSync()) {
    stdout.writeln('Linux build output not found.');
    return;
  }

  stdout.writeln('Packaging as AppImage...');
  final appDir = Directory(join(outputDir.path, 'linux', 'AppDir'));
  if (appDir.existsSync()) appDir.deleteSync(recursive: true);
  appDir.createSync(recursive: true);

  // Copy bundle into AppDir/usr/bin
  final usrBin = Directory(join(appDir.path, 'usr', 'bin'));
  usrBin.createSync(recursive: true);
  await _copyDirectory(bundleDir, usrBin);

  // Create .desktop file
  final desktopFile = File(join(appDir.path, 'lispinto_chat.desktop'));
  desktopFile.writeAsStringSync('''
[Desktop Entry]
Name=Lispinto Chat
Exec=lispinto_chat
Icon=lispinto_chat
Type=Application
Categories=Network;Chat;
''');

  // Copy icon
  final iconSource = File('assets/icon/icon.png');
  if (iconSource.existsSync()) {
    iconSource.copySync(join(appDir.path, 'lispinto_chat.png'));
  }

  // Create AppRun script
  final appRun = File(join(appDir.path, 'AppRun'));
  appRun.writeAsStringSync('''
#!/bin/bash
HERE="\$(dirname "\$(readlink -f "\$0")")"
export LD_LIBRARY_PATH="\$HERE/usr/bin/lib:\$LD_LIBRARY_PATH"
exec "\$HERE/usr/bin/lispinto_chat" "\$@"
''');
  await Process.run('chmod', ['+x', appRun.path]);

  // Run appimagetool
  final destination = Directory(join(outputDir.path, 'linux'));
  if (!destination.existsSync()) destination.createSync(recursive: true);

  final appImagePath = join(destination.path, 'LispintoChat.AppImage');
  final appImageResult = await Process.run('appimagetool', [
    appDir.path,
    appImagePath,
  ]);

  if (appImageResult.exitCode != 0) {
    stdout.writeln('Error creating AppImage:');
    stdout.writeln(appImageResult.stderr);
    exit(appImageResult.exitCode);
  }

  stdout.writeln(appImageResult.stdout);

  // Clean up AppDir
  appDir.deleteSync(recursive: true);
  stdout.writeln('AppImage created at $appImagePath');
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
