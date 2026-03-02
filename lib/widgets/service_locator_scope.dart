import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:lispinto_chat/core/service_locator.dart';

/// A function that registers dependencies in a [GetIt] scope.
typedef ServiceLocatorOverrides = void Function(GetIt locator);

/// A widget that creates a new [GetIt] scope for its subtree.
///
/// When this widget is inserted into the tree, it pushes a new scope.
/// When it's removed, it pops the scope.
/// The [overrides] function can be used to register or override dependencies
/// within this new scope.
final class ServiceLocatorScope extends StatefulWidget {
  /// Creates a [ServiceLocatorScope].
  const ServiceLocatorScope({
    super.key,
    required this.child,
    this.overrides,
  });

  /// The widget below this widget in the tree.
  final Widget child;

  /// An optional function to register overrides in the new scope.
  final ServiceLocatorOverrides? overrides;

  @override
  State<ServiceLocatorScope> createState() => _ServiceLocatorScopeState();
}

class _ServiceLocatorScopeState extends State<ServiceLocatorScope> {
  bool _scopePushed = false;

  @override
  void initState() {
    super.initState();
    _pushScope();
  }

  void _pushScope() {
    locator.pushNewScope();
    _scopePushed = true;
    widget.overrides?.call(locator);
  }

  @override
  void dispose() {
    if (_scopePushed) {
      locator.popScope();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
