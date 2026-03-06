import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lispinto_chat/services/chat_service.dart';

/// A widget that shows the current connection status with a colored dot and tooltip.
final class ConnectionStatusIndicator extends StatelessWidget {
  /// Creates a [ConnectionStatusIndicator].
  const ConnectionStatusIndicator({
    super.key,
    required this.state,
    required this.shouldShowLabel,
  });

  /// The current connection state.
  final ChatConnectionState state;

  /// Whether to show the label next to the colored dot.
  final bool shouldShowLabel;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (state) {
      ChatConnectionState.disconnected => (Colors.red, 'Disconnected'),
      ChatConnectionState.connecting => (Colors.orange, 'Connecting...'),
      ChatConnectionState.connected => (
        Colors.yellow,
        'Connected (Logging in...)',
      ),
      ChatConnectionState.loggedIn => (Colors.green, 'Online'),
      ChatConnectionState.reconnecting => (Colors.orange, 'Reconnecting...'),
    };

    return Tooltip(
      message: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8.0,
            height: 8.0,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          if (shouldShowLabel) ...[
            const Gap(4.0),
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.8),
                fontSize: 10.0,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
