import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lispinto_chat/core/service_locator.dart';
import 'package:lispinto_chat/core/user_configuration.dart';
import 'package:lispinto_chat/models/chat_message.dart';
import 'package:lispinto_chat/providers/chat_provider.dart';
import 'package:lispinto_chat/widgets/message_bubble.dart';
import 'package:prototype_constrained_box/prototype_constrained_box.dart';

import '../core/message_grouper.dart';

/// A widget that displays a list of chat messages and floating notifications.
final class MessageList extends StatelessWidget {
  /// Creates a [MessageList].
  const MessageList({
    super.key,
    required this.provider,
    required this.controller,
    required this.notifications,
    required this.listKey,
    required this.onRemoveNotification,
  });

  /// The provider that manages the chat state.
  final ChatProvider provider;

  /// The controller for the scrollable list.
  final ScrollController controller;

  /// The list of active floating notifications.
  final List<NotificationItem> notifications;

  /// The key for the animated list of notifications.
  final GlobalKey<AnimatedListState> listKey;

  /// Callback when a notification is tapped or timed out.
  final ValueSetter<String> onRemoveNotification;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: provider,
      builder: (context, child) {
        final messages = provider.messages;
        final configuration = locator<UserConfiguration>();
        final displayedMessages = configuration.groupMessages
            ? locator<MessageGrouper>().group(messages)
            : messages;

        return Stack(
          children: [
            if (displayedMessages.isEmpty)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      provider.searchQuery.isEmpty
                          ? Icons.chat_bubble_outline
                          : Icons.search_off,
                      size: 64.0,
                      color: Colors.grey.withValues(alpha: 0.5),
                    ),
                    const Gap(16.0),
                    Text(
                      provider.searchQuery.isEmpty
                          ? 'No messages yet in ${provider.activeChannel}'
                          : 'No messages found for "${provider.searchQuery}"',
                      style: TextStyle(
                        color: Colors.grey.withValues(alpha: 0.8),
                        fontSize: 16.0,
                      ),
                    ),
                    if (provider.searchQuery.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Start the conversation!',
                          style: TextStyle(
                            color: Colors.grey.withValues(alpha: 0.5),
                            fontSize: 12.0,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ListView.builder(
              padding:
                  MediaQuery.paddingOf(context) +
                  const EdgeInsets.only(bottom: 8.0),
              reverse: true,
              controller: controller,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              itemCount: displayedMessages.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const PrototypeConstrainedBox.tight(
                    prototype: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: TextField(),
                    ),
                    child: SizedBox(),
                  );
                }

                final message =
                    displayedMessages[displayedMessages.length - index];
                final bool showDateDivider;
                final date = message.date;
                if (index == displayedMessages.length) {
                  showDateDivider = message.date != null;
                } else {
                  final previousMessage =
                      displayedMessages[displayedMessages.length - index - 1];
                  showDateDivider = _shouldShowDateDivider(
                    previousMessage,
                    message,
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showDateDivider && date != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                          child: Text(
                            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    MessageBubble(
                      message: message,
                      searchQuery: provider.searchQuery,
                    ),
                  ],
                );
              },
            ),
            Positioned(
              left: 0.0,
              right: 0.0,
              top: 0.0,
              child: _NotificationsArea(
                notifications: notifications,
                listKey: listKey,
                onRemoveNotification: onRemoveNotification,
              ),
            ),
          ],
        );
      },
    );
  }

  bool _shouldShowDateDivider(ChatMessage previous, ChatMessage current) {
    final currentDate = current.date;
    if (currentDate == null) return false;

    final previousDate = previous.date;
    if (previousDate == null) return true;

    return previousDate.year != currentDate.year ||
        previousDate.month != currentDate.month ||
        previousDate.day != currentDate.day;
  }
}

/// Represents a floating notification item.
class NotificationItem {
  /// Creates a [NotificationItem].
  NotificationItem(this.id, this.text);

  /// The unique identifier of the notification.
  final String id;

  /// The text to display in the notification.
  final String text;
}

final class _NotificationsArea extends StatefulWidget {
  const _NotificationsArea({
    required this.listKey,
    required this.notifications,
    required this.onRemoveNotification,
  });

  final GlobalKey<AnimatedListState> listKey;
  final List<NotificationItem> notifications;
  final ValueSetter<String> onRemoveNotification;

  @override
  State<_NotificationsArea> createState() => _NotificationsAreaState();
}

class _NotificationsAreaState extends State<_NotificationsArea> {
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: widget.notifications.isEmpty,
      child: AnimatedList(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(8.0),
        key: widget.listKey,
        initialItemCount: widget.notifications.length,
        itemBuilder: (context, index, animation) {
          final notification = widget.notifications[index];
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: SizeTransition(
              sizeFactor: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              axisAlignment: 0.0,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Center(
                  child: _NotificationPill(
                    text: Text(notification.text),
                    onTap: () => widget.onRemoveNotification(notification.id),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

final class _NotificationPill extends StatelessWidget {
  const _NotificationPill({required this.text, required this.onTap});

  final Widget text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(32.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.inversePrimary,
            borderRadius: BorderRadius.circular(32.0),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4.0,
                offset: Offset(0.0, 2.0),
              ),
            ],
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            child: text,
          ),
        ),
      ),
    );
  }
}
