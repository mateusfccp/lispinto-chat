import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lispinto_chat/core/delete_aware_text_controller.dart';
import 'package:lispinto_chat/core/get_nickname_color.dart';
import 'package:lispinto_chat/core/responsive.dart';
import 'package:prototype_constrained_box/prototype_constrained_box.dart';

/// Defines a generic text-based trigger to activate an autocomplete dropdown.
abstract interface class AutocompleteTrigger {
  /// Defines how to detect the trigger from the text preceding the cursor.
  ///
  /// The [textBeforeCursor] parameter will contain the full text from the start
  /// of the input up to the current cursor position, allowing for flexible
  /// detection logic such as looking for specific characters, keywords, or
  /// patterns.
  ///
  /// Should return the raw 'query' string if detected, or null if unrelated.
  String? triggerDetector(String textBeforeCursor);

  /// Defines how the selected item should be formatted before being injected into the text field.
  String formatSelection(String selection);

  /// The suggestions that can be shown when this trigger is active.
  List<String> get suggestions;
}

/// A widget that and provides a popout overlay for autocompleting.
final class AutocompleteDropdown extends StatefulWidget {
  /// Creates a [AutocompleteDropdown].
  const AutocompleteDropdown({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.triggers,
    required this.child,
  });

  /// The text controller of the wrapped input field.
  final TextEditingController controller;

  /// The focus node of the wrapped input field.
  final FocusNode focusNode;

  /// The list of triggers that can activate the autocomplete.
  final List<AutocompleteTrigger> triggers;

  /// The text input widget to wrap.
  final Widget child;

  @override
  State<AutocompleteDropdown> createState() => _AutocompleteDropdownState();
}

final class _AutocompleteDropdownState extends State<AutocompleteDropdown> {
  String? _query;
  int _selectedIndex = 0;
  List<String> _filteredOptions = [];
  AutocompleteTrigger? _activeTrigger;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(AutocompleteDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }

    if (_query != null && !listEquals(widget.triggers, oldWidget.triggers)) {
      _onTextChanged();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final selection = widget.controller.selection;

    // We only care if the cursor is currently valid and collapsed (not highlighting text).
    if (!selection.isValid || !selection.isCollapsed) {
      _hideDropdown();
      return;
    }

    final cursorPosition = selection.baseOffset;
    if (cursorPosition == 0) {
      _hideDropdown();
      return;
    }

    // Extract the substring before the cursor.
    final textBeforeCursor = text.substring(0, cursorPosition);

    final cleanTextBeforeCursor = textBeforeCursor.replaceAll(
      DeleteAwareEditingController.zeroWidthSpace,
      '',
    );

    for (final trigger in widget.triggers) {
      final query = trigger.triggerDetector(cleanTextBeforeCursor);
      if (query != null) {
        _activeTrigger = trigger;
        _filterOptions(query);
        return;
      }
    }

    _hideDropdown();
  }

  void _filterOptions(String query) {
    final source = _activeTrigger?.suggestions;
    if (source == null) {
      _hideDropdown();
      return;
    }

    final lowerQuery = query.toLowerCase();

    final matches = [
      for (final item in source)
        if (item.toLowerCase().startsWith(lowerQuery)) item,
    ];

    matches.sort(); // Sort alphabetically

    setState(() {
      _query = query;
      _filteredOptions = matches;

      // Clamp the selected index to not exceed the new filtered list length
      if (_filteredOptions.isEmpty) {
        _selectedIndex = 0;
      } else if (_selectedIndex >= _filteredOptions.length) {
        _selectedIndex = _filteredOptions.length - 1;
      }
    });
  }

  void _hideDropdown() {
    if (_query != null) {
      setState(() {
        _query = null;
        _activeTrigger = null;
        _filteredOptions = [];
        _selectedIndex = 0;
      });
    }
  }

  void _onItemSelected(String item) {
    final trigger = _activeTrigger;

    if (trigger == null) return;

    final hasZeroWidthPrefix = widget.controller.text.startsWith(
      DeleteAwareEditingController.zeroWidthSpace,
    );
    final cleanText = widget.controller.text.replaceAll(
      DeleteAwareEditingController.zeroWidthSpace,
      '',
    );
    final cleanBaseOffset = hasZeroWidthPrefix
        ? max(0, widget.controller.selection.baseOffset - 1)
        : widget.controller.selection.baseOffset;
    final cleanExtentOffset = hasZeroWidthPrefix
        ? max(0, widget.controller.selection.extentOffset - 1)
        : widget.controller.selection.extentOffset;

    final cleanValue = TextEditingValue(
      text: cleanText,
      selection: widget.controller.selection.copyWith(
        baseOffset: cleanBaseOffset,
        extentOffset: cleanExtentOffset,
      ),
    );

    final textBeforeCursor = cleanValue.text.substring(
      0,
      cleanValue.selection.baseOffset,
    );
    final textAfterCursor = cleanValue.text.substring(
      cleanValue.selection.baseOffset,
    );

    final lastSpaceIndex = textBeforeCursor.lastIndexOf(RegExp(r'[\s]'));
    final startIndex = lastSpaceIndex == -1 ? 0 : lastSpaceIndex + 1;

    final textBeforeItem = textBeforeCursor.substring(0, startIndex);
    final injectedItem = '${trigger.formatSelection(item)} ';

    final newText = textBeforeItem + injectedItem + textAfterCursor;
    final newCursorPosition = textBeforeItem.length + injectedItem.length;

    final newCleanValue = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPosition),
    );

    widget.controller.value = newCleanValue.copyWith(
      text: hasZeroWidthPrefix
          ? '${DeleteAwareEditingController.zeroWidthSpace}${newCleanValue.text}'
          : newCleanValue.text,
      selection: newCleanValue.selection.copyWith(
        baseOffset: hasZeroWidthPrefix
            ? newCleanValue.selection.baseOffset + 1
            : newCleanValue.selection.baseOffset,
        extentOffset: hasZeroWidthPrefix
            ? newCleanValue.selection.extentOffset + 1
            : newCleanValue.selection.extentOffset,
      ),
    );

    _hideDropdown();
    widget.focusNode.requestFocus();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (_query == null || _filteredOptions.isEmpty) {
      return KeyEventResult.ignored;
    }

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final key = event.logicalKey;

      if (key == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _selectedIndex =
              (_selectedIndex - 1 + _filteredOptions.length) %
              _filteredOptions.length;
        });
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _selectedIndex = (_selectedIndex + 1) % _filteredOptions.length;
        });
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.tab) {
        _onItemSelected(_filteredOptions[_selectedIndex]);
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.escape) {
        _hideDropdown();
        return KeyEventResult.handled;
      }
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.tab ||
        key == LogicalKeyboardKey.escape) {
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = context.isDesktop;

    return Focus(
      onKeyEvent: _handleKeyEvent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_query != null && _filteredOptions.isNotEmpty)
            if (isDesktop)
              _DesktopDropdown(
                filteredUsers: _filteredOptions,
                selectedIndex: _selectedIndex,
                onUserSelected: _onItemSelected,
              )
            else
              _MobileDropdown(
                filteredUsers: _filteredOptions,
                onUserSelected: _onItemSelected,
              ),
          widget.child,
        ],
      ),
    );
  }
}

final class _DesktopDropdown extends StatelessWidget {
  const _DesktopDropdown({
    required this.filteredUsers,
    required this.selectedIndex,
    required this.onUserSelected,
  });

  final List<String> filteredUsers;
  final int selectedIndex;
  final ValueChanged<String> onUserSelected;

  @override
  Widget build(BuildContext context) {
    final itemCount = min(5, filteredUsers.length);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 8.0, left: 8.0, right: 8.0),
      child: PrototypeConstrainedBox.tightFor(
        height: true,
        prototype: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            itemCount,
            (_) => const _DesktopDropdownItem.prototype(),
          ),
        ),
        child: ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: min(5, filteredUsers.length),
          prototypeItem: const _DesktopDropdownItem.prototype(),
          itemBuilder: (context, index) {
            final user = filteredUsers[index];
            final isSelected = index == selectedIndex;

            return _DesktopDropdownItem(
              user: user,
              isSelected: isSelected,
              onUserSelected: onUserSelected,
            );
          },
        ),
      ),
    );
  }
}

final class _DesktopDropdownItem extends StatelessWidget {
  const _DesktopDropdownItem({
    required this.user,
    required this.isSelected,
    required this.onUserSelected,
  });

  const _DesktopDropdownItem.prototype()
    : user = 'Prototype',
      isSelected = false,
      onUserSelected = _prototypeOnUserSelected;

  final String user;
  final bool isSelected;
  final ValueChanged<String> onUserSelected;

  static void _prototypeOnUserSelected(String user) {}

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onUserSelected(user),
      child: Container(
        color: isSelected
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Row(
          children: [
            Text(
              user,
              style: TextStyle(
                color: getNicknameColor(user),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _MobileDropdown extends StatelessWidget {
  const _MobileDropdown({
    required this.filteredUsers,
    required this.onUserSelected,
  });

  final List<String> filteredUsers;
  final ValueChanged<String> onUserSelected;

  @override
  Widget build(BuildContext context) {
    final itemCount = min(3, filteredUsers.length);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: PrototypeConstrainedBox.tightFor(
        height: true,
        prototype: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            itemCount,
            (_) => const _MobileDropdownItem.prototype(),
          ),
        ),
        child: ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemCount,
          prototypeItem: const _MobileDropdownItem.prototype(),
          itemBuilder: (context, index) {
            final user = filteredUsers[index];

            return _MobileDropdownItem(
              user: user,
              onUserSelected: onUserSelected,
            );
          },
        ),
      ),
    );
  }
}

final class _MobileDropdownItem extends StatelessWidget {
  const _MobileDropdownItem({required this.user, required this.onUserSelected});

  const _MobileDropdownItem.prototype()
    : user = 'Prototype',
      onUserSelected = _prototypeOnUserSelected;

  final String user;
  final ValueChanged<String> onUserSelected;

  static void _prototypeOnUserSelected(String user) {}

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onUserSelected(user),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Text(
          user,
          style: TextStyle(color: getNicknameColor(user), fontSize: 16),
        ),
      ),
    );
  }
}
