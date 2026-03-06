import 'package:flutter/material.dart';
import 'package:prototype_constrained_box/prototype_constrained_box.dart';
import '../core/responsive.dart';

/// A widget that provides a search input field with an animated toggle.
class SearchInput extends StatelessWidget {
  /// Creates a [SearchInput].
  const SearchInput({
    super.key,
    required this.isSearchActive,
    required this.searchController,
    required this.searchFocusNode,
    required this.onToggleSearch,
    required this.onSearchChanged,
  });

  /// Whether the search field is currently visible.
  final bool isSearchActive;

  /// The controller for the search text field.
  final TextEditingController searchController;

  /// The focus node for the search text field.
  final FocusNode searchFocusNode;

  /// Callback to toggle the search field visibility.
  final VoidCallback onToggleSearch;

  /// Callback when the search text changes.
  final ValueChanged<String> onSearchChanged;

  static const _borderWidth = 1.0;

  @override
  Widget build(BuildContext context) {
    final iconButton = IconButton(
      icon: const Icon(Icons.search),
      onPressed: onToggleSearch,
      tooltip: isSearchActive ? 'Close search' : 'Search messages',
    );

    return Align(
      alignment: Alignment.centerRight,
      child: PrototypeConstrainedBox(
        constrainMaxHeight: false,
        constrainMaxWidth: false,
        constrainMinHeight: true,
        constrainMinWidth: true,
        prototype: iconButton,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = isSearchActive
                ? constraints.maxWidth
                : constraints.minWidth + (_borderWidth * 2.0);

            return AnimatedContainer(
              curve: Curves.easeInOut,
              duration: const Duration(milliseconds: 150),
              width: width,
              decoration: BoxDecoration(
                color: Colors.black87,
                border: Border.all(color: Colors.white24, width: _borderWidth),
                borderRadius: BorderRadius.circular(32.0),
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AbsorbPointer(absorbing: isSearchActive, child: iconButton),
                  if (isSearchActive)
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        focusNode: searchFocusNode,
                        onChanged: onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Search messages...',
                          isDense: context.isDesktop,
                          border: InputBorder.none,
                          fillColor: Colors.transparent,
                          filled: true,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
