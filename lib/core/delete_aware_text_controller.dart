import 'package:flutter/widgets.dart';

/// Builder that constructs a [TextSpan] for the content of the text field.
///
/// The provided [text] will not contain the [zeroWidthSpace] prefix.
///
/// This allows for custom text styling, such as syntax highlighting, while
/// still supporting the delete-aware functionality of the controller.
typedef DeleteAwareEditingControllerBuilder =
    TextSpan Function(
      BuildContext context,
      String text,
      TextStyle? style,
      bool withComposing,
    );

/// A custom [TextEditingController] that manages a zero-width space prefix to
/// detect when a user deletes everything in the field using the backspace key.
///
/// This is particularly useful in scenarios where you want to show a visual
/// indicator inside the text field that can be dismissed by pressing backspace
/// when the actual text is empty.
///
/// It works by injecting a zero-width space `\u200B` at the beginning of the
/// text field. If the user presses backspace repeatedly until that invisible
/// space gets deleted, it triggers [onDeleteEmpty], effectively catching
/// the backspace on an apparently empty text field.
///
/// It also listens to the provided [focusNode] to ensure the prefix is
/// only active when the field actually has focus, preventing it from
/// absorbing the `hintText` when the user isn't interacting with it.
final class DeleteAwareEditingController extends TextEditingController {
  /// Creates a [DeleteAwareEditingController].
  DeleteAwareEditingController({
    super.text,
    required this.onDeleteEmpty,
    required this.focusNode,
    this.builder,
  }) {
    focusNode.addListener(_onFocusChanged);
    _onFocusChanged();
  }

  /// The zero-width space character.
  ///
  /// This is used as a prefix to detect when the user has deleted all visible
  /// text in the field. It is invisible to the user but allows us to track
  /// backspace.
  static const zeroWidthSpace = '\u200B';

  /// Callback fired when the user hits backspace on an empty field.
  ///
  /// This is triggered when the user deletes the zero-width space prefix, which
  /// indicates that they have attempted to delete past the point of having any
  /// visible text left in the field.
  final VoidCallback onDeleteEmpty;

  /// The focus node attached to the text field this controller is controlling.
  final FocusNode focusNode;

  /// An optional builder callback that allows for custom [TextSpan] building.
  ///
  /// The provided [text] will not contain the [zeroWidthSpace] prefix.
  final DeleteAwareEditingControllerBuilder? builder;

  bool _isDeletingFromApi = false;

  void _onFocusChanged() {
    if (focusNode.hasFocus) {
      if (!text.startsWith(zeroWidthSpace)) {
        _isDeletingFromApi = true;
        value = value.copyWith(
          text: '$zeroWidthSpace$text',
          selection: TextSelection.collapsed(
            offset: value.selection.baseOffset + 1,
          ),
        );
        _isDeletingFromApi = false;
      }
    } else {
      if (text == zeroWidthSpace) {
        _isDeletingFromApi = true;
        value = const TextEditingValue(
          text: '',
          selection: TextSelection.collapsed(offset: 0),
        );
        _isDeletingFromApi = false;
      }
    }
  }

  @override
  void dispose() {
    focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  /// Returns the actual user-input text without the zero-width space prefix.
  String get typedText {
    if (text.startsWith(zeroWidthSpace)) {
      return text.substring(1);
    } else {
      return text;
    }
  }

  @override
  set value(TextEditingValue newValue) {
    if (_isDeletingFromApi) {
      super.value = newValue;
      return;
    }

    if (focusNode.hasFocus) {
      if (value.text.startsWith(zeroWidthSpace) &&
          !newValue.text.startsWith(zeroWidthSpace)) {
        // User deleted the space
        final textWithoutZeroWidth = newValue.text.replaceAll(
          zeroWidthSpace,
          '',
        );
        _isDeletingFromApi = true;
        super.value = newValue.copyWith(
          text: textWithoutZeroWidth,
          selection: TextSelection.collapsed(
            offset: textWithoutZeroWidth.length,
          ),
        );
        _isDeletingFromApi = false;
        onDeleteEmpty();
        return;
      } else if (!newValue.text.startsWith(zeroWidthSpace)) {
        // Enforce the space programmatically
        _isDeletingFromApi = true;
        final newText = '$zeroWidthSpace${newValue.text}';
        super.value = newValue.copyWith(
          text: newText,
          selection: TextSelection.collapsed(
            offset: newValue.selection.baseOffset + 1,
          ),
        );
        _isDeletingFromApi = false;
        return;
      }
    }

    super.value = newValue;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = this.text;

    if (text.isEmpty) {
      return TextSpan(text: text, style: style);
    }

    // Handle zeroWidthSpace prefix
    final hasPrefix = text.startsWith(zeroWidthSpace);
    final contentText = hasPrefix ? text.substring(1) : text;

    final TextSpan contentSpan;
    if (builder case final builder?) {
      contentSpan = builder(context, contentText, style, withComposing);
    } else {
      contentSpan = TextSpan(text: contentText, style: style);
    }

    if (!hasPrefix) {
      return contentSpan;
    }

    return TextSpan(
      children: [
        TextSpan(text: zeroWidthSpace, style: style),
        contentSpan,
      ],
      style: style,
    );
  }
}
