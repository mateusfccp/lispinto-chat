import 'dart:io';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:fluent/fluent.dart';
import 'package:lispinto_chat/core/generate_localizations_annotation.dart';
import 'package:recase/recase.dart';
import 'package:source_gen/source_gen.dart';

Builder localizationBuilder(BuilderOptions options) =>
    SharedPartBuilder([LocalizationGenerator()], 'localization');

/// A code generator that reads localization files and generates a Dart class.
final class LocalizationGenerator
    extends GeneratorForAnnotation<GenerateLocalizations> {
  @override
  Future<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    final package = buildStep.inputId.package;
    final enAsset = AssetId(package, 'assets/i18n/en.ftl');

    if (!await buildStep.canRead(enAsset)) {
      throw Exception(
        'assets/i18n/en.ftl not found. English is required as the reference language.',
      );
    }

    final enContent = await buildStep.readAsString(enAsset);
    final parsedContent = _parseFtl(enContent);

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
        final parsedOther = _parseFtl(content);

        for (final key in parsedContent.keys) {
          if (!parsedOther.containsKey(key)) {
            stdout.writeln('Warning: Key "$key" is missing in $lang');
            hasWarnings = true;
          }
        }
      }

      if (hasWarnings) {
        stdout.writeln(
          '\\nSome keys are missing in translations. Please add them.\\n',
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

  Map<String, List<String>> _parseFtl(String content) {
    final bundle = FluentBundle('en');
    bundle.addMessages(content);

    final map = <String, List<String>>{};
    for (final MapEntry(:key, :value) in bundle.messages.entries) {
      final elements = value.value?.elements;
      final List<String> arguments;

      if (elements == null) {
        arguments = [];
      } else {
        // This is flaky, but the FluentBundle doesn't export their internal AST, so we have to rely on dynamic and string checks.
        arguments = [
          for (final element in elements)
            if (element.runtimeType.toString() == 'VariableReference')
              (element as dynamic).name
            else if (element.runtimeType.toString() == 'FunctionReference')
              for (final argument in (element as dynamic).arguments)
                if (argument.runtimeType.toString() == 'NamedArgument')
                  (argument as dynamic).name
                else if (argument.runtimeType.toString() ==
                    'PositionalArgument')
                  if ((argument as dynamic).value.runtimeType.toString() ==
                      'VariableReference')
                    (argument as dynamic).value.name,
        ];
      }

      map[key] = arguments;
    }

    // print('Parsed keys and arguments: $map');

    return map;
  }

  String _generateDartCode(String className, Map<String, List<String>> keys) {
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

      for (final MapEntry(:key, value: arguments) in keys.entries) {
        final camelCaseKey = ReCase(key).camelCase;

        if (arguments.isEmpty) {
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
                  for (final argument in arguments)
                    Parameter((builder) {
                      builder.type = refer('Object?');
                      builder.name = argument;
                    }),
                ])
                ..body = refer('fluent')
                    .property('getMessage')
                    .call([
                      literalString(key),
                      literalMap({
                        for (final argument in arguments)
                          argument: refer(argument),
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
