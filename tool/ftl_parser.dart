import 'package:fluent/fluent.dart';

/// Represents an argument in a Fluent message.
final class FluentArgument {
  /// The name of the argument as it appears in the Fluent source.
  final String name;

  /// The inferred Dart type of the argument.
  final String type;

  /// Creates a new FTL argument.
  FluentArgument(this.name, this.type);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FluentArgument &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => '$name: $type';
}

/// Represents a parsed Fluent message and its associated arguments.
final class FluentMessage {
  /// The list of arguments identified within this message.
  final List<FluentArgument> arguments;

  /// Creates a new FTL message descriptor.
  FluentMessage(this.arguments);
}

/// A parser that extracts message structures and arguments from Fluent sources.
interface class FluentParser {
  /// Creates a new Fluent parser.
  const FluentParser();

  /// Parses the given [content].
  ///
  /// Returns a map of message IDs to [FluentMessage] descriptors.
  Map<String, FluentMessage> parse(String content) {
    final bundle = FluentBundle('en');
    bundle.addMessages(content);

    final map = <String, FluentMessage>{};
    for (final MapEntry(:key, :value) in bundle.messages.entries) {
      final elements = value.value?.elements;
      final Set<FluentArgument> arguments = {};

      if (elements != null) {
        for (final element in elements) {
          _extractArguments(element, arguments);
        }
      }

      map[key] = FluentMessage(arguments.toList(growable: false));
    }

    return map;
  }

  void _extractArguments(
    dynamic node,
    Set<FluentArgument> arguments, [
    String? functionContext,
  ]) {
    if (node == null) return;
    final type = node.runtimeType.toString();

    if (type == 'VariableReference') {
      final name = (node as dynamic).name as String;
      String inferredType = 'Object?';
      if (functionContext == 'NUMBER') {
        inferredType = 'num';
      } else if (functionContext == 'DATETIME') {
        inferredType = 'DateTime';
      }

      final existing = arguments.lookup(FluentArgument(name, 'Object?'));
      if (existing != null) {
        if (existing.type == 'Object?' && inferredType != 'Object?') {
          arguments.remove(existing);
          arguments.add(FluentArgument(name, inferredType));
        }
      } else {
        arguments.add(FluentArgument(name, inferredType));
      }
    } else if (type == 'FunctionReference') {
      final name = (node as dynamic).name as String;
      for (final argument in (node as dynamic).arguments) {
        _extractArguments(argument, arguments, name);
      }
    } else if (type == 'PositionalArgument') {
      _extractArguments((node as dynamic).value, arguments, functionContext);
    } else if (type == 'NamedArgument') {
      // Named arguments values are Literals, usually not variables.
    } else if (type == 'SelectExpression') {
      _extractArguments((node as dynamic).selector, arguments, functionContext);
      for (final variant in (node as dynamic).variants) {
        _extractArguments(variant, arguments, functionContext);
      }
    } else if (type == 'Variant') {
      final pattern = (node as dynamic).value;
      if (pattern != null) {
        for (final element in (pattern as dynamic).elements) {
          _extractArguments(element, arguments, functionContext);
        }
      }
    } else if (type == 'Placeable') {
      _extractArguments(
        (node as dynamic).expression,
        arguments,
        functionContext,
      );
    } else if (type == 'TermReference') {
      for (final argument in (node as dynamic).arguments) {
        _extractArguments(argument, arguments, functionContext);
      }
    }
  }
}
