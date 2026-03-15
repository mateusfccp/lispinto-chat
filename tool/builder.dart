import 'dart:io';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:lispinto_chat/core/generate_localizations_annotation.dart';
import 'package:recase/recase.dart';
import 'package:source_gen/source_gen.dart';

import 'ftl_parser.dart';

/// The function that registers the [LocalizationGenerator] to the build system.
Builder localizationBuilder(BuilderOptions options) {
  return SharedPartBuilder([LocalizationGenerator()], 'localization_builder');
}

/// A code generator that reads localization files and generates a Dart class.
final class LocalizationGenerator
    extends GeneratorForAnnotation<GenerateLocalizations> {
  @override
  Future<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    final enAsset = AssetId(buildStep.inputId.package, 'assets/i18n/en.ftl');

    if (!await buildStep.canRead(enAsset)) {
      throw Exception(
        'assets/i18n/en.ftl not found. English is required as the reference language.',
      );
    }

    final enContent = await buildStep.readAsString(enAsset);
    final parser = const FluentParser();
    final parsedContent = parser.parse(enContent);

    // We can confidently read the other languages to output warnings,
    final i18nDir = Directory('assets/i18n');
    if (i18nDir.existsSync()) {
      final entries = i18nDir.listSync();
      final otherFiles = [
        for (final entry in entries)
          if (entry is File &&
              entry.path.endsWith('.ftl') &&
              !entry.path.endsWith('en.ftl'))
            entry,
      ];

      bool hasWarnings = false;
      for (final file in otherFiles) {
        final lang = file.uri.pathSegments.last;
        final content = await file.readAsString();
        final parsedOther = parser.parse(content);

        for (final key in parsedContent.keys) {
          if (!parsedOther.containsKey(key)) {
            stdout.writeln('Warning: Key "$key" is missing in $lang');
            hasWarnings = true;
          }
        }
      }

      if (hasWarnings) {
        stdout.writeln(
          '\nSome keys are missing in translations. Please add them.\n',
        );
      }
    }

    if (element is! ClassElement) {
      throw StateError(
        'The @GenerateLocalizations annotation can only be applied to classes.',
      );
    }

    return _generateDartCode(element.name!, parsedContent);
  }

  String _generateDartCode(String className, Map<String, FluentMessage> keys) {
    final mixin = Mixin((builder) {
      builder.name = '_\$${className}Mixin';

      builder.methods.add(
        Method((builder) {
          builder
            ..name = 'fluent'
            ..returns = refer('FluentLocalizations')
            ..type = MethodType.getter;
        }),
      );

      for (final MapEntry(:key, value: message) in keys.entries) {
        final camelCaseKey = ReCase(key).camelCase;

        if (message.arguments.isEmpty) {
          builder.methods.add(
            Method((builder) {
              builder
                ..name = camelCaseKey
                ..returns = refer('String')
                ..type = MethodType.getter
                ..body = refer('fluent')
                    .property('getMessage')
                    .call([literalString(key)])
                    .ifNullThen(literalString(key))
                    .code;
            }),
          );
        } else {
          builder.methods.add(
            Method((methodBuilder) {
              methodBuilder
                ..name = camelCaseKey
                ..returns = refer('String')
                ..requiredParameters.addAll([
                  for (final argument in message.arguments)
                    Parameter((builder) {
                      builder.type = refer(argument.type);
                      builder.name = argument.name;
                    }),
                ])
                ..body = refer('fluent')
                    .property('getMessage')
                    .call([
                      literalString(key),
                      literalMap({
                        for (final argument in message.arguments)
                          argument.name: refer(argument.name),
                      }),
                    ])
                    .ifNullThen(literalString(key))
                    .code;
            }),
          );
        }
      }
    });

    final emitter = DartEmitter(
      orderDirectives: true,
      useNullSafetySyntax: true,
    );

    return mixin.accept(emitter).toString();
  }
}
