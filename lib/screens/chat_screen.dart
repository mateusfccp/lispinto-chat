import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lispinto_chat/core/delete_aware_text_controller.dart';
import 'package:lispinto_chat/core/get_nickname_color.dart';
import 'package:lispinto_chat/models/chat_message.dart';
import 'package:lispinto_chat/providers/chat_provider.dart';
import 'package:lispinto_chat/widgets/autocomplete_triggers/command_autocomplete_trigger.dart';
import 'package:lispinto_chat/widgets/autocomplete_triggers/tag_autocomplete_trigger.dart';
import 'package:lispinto_chat/widgets/mentions_autocomplete.dart';
import 'package:lispinto_chat/widgets/message_bubble.dart';
import 'package:prototype_constrained_box/prototype_constrained_box.dart';
import 'configurations_screen.dart';

/// The main chat screen of the app.
final class ChatScreen extends StatefulWidget {
  /// Creates a [ChatScreen] with the given [ChatProvider].
  const ChatScreen({super.key, required this.provider});

  /// The chat provider that manages the chat state and communication.
  final ChatProvider provider;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final DeleteAwareEditingController _controller =
      DeleteAwareEditingController(
        onDeleteEmpty: () => widget.provider.setDmMode(null),
        focusNode: _focusNode,
      );
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final listKey = GlobalKey<AnimatedListState>();
  StreamSubscription? _notificationSubscription;

  final List<_NotificationItem> _activeNotifications = [];
  int _notificationCounter = 0;

  void _removeNotification(String id) {
    if (!mounted) return;
    final index = _activeNotifications.indexWhere((n) => n.id == id);
    if (index == -1) return;

    final removedItem = _activeNotifications.removeAt(index);
    listKey.currentState?.removeItem(index, (context, animation) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: SizeTransition(
          sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          axisAlignment: 0.0,
          child: Center(
            child: _NotificationPill(
              text: Text(removedItem.text),
              onTap: () {},
            ),
          ),
        ),
      );
    });
  }

  void _onTextChanged() {
    final text = _controller.typedText;

    if (text.startsWith('/dm')) {
      final parts = text.split(RegExp(r'\s+'));
      if (parts case ['/dm', final username, '']) {
        final users = [...widget.provider.onlineUsers]
          ..remove(widget.provider.configuration.nickname);
        if (users.contains(username)) {
          widget.provider.setDmMode(username);
          _controller.typedText = '';
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _notificationSubscription = widget.provider.notifications.listen((
      notification,
    ) {
      if (!mounted) return;

      final id = 'notif_${_notificationCounter++}';
      final item = _NotificationItem(id, notification);

      _activeNotifications.add(item);
      listKey.currentState?.insertItem(_activeNotifications.length - 1);

      Timer(const Duration(seconds: 3), () {
        _removeNotification(id);
      });
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _notificationSubscription?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  void _sendMessage() {
    final text = _controller.typedText.trimRight();
    if (text.isNotEmpty) {
      if (text == '/clear') {
        widget.provider.clearMessages();
      } else {
        widget.provider.sendMessage(text);
      }
      _controller.clear();
      _focusNode.requestFocus();
      _scrollToBottom();
    }
  }

  void _openConfig() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ConfigurationsScreen(
          configuration: widget.provider.configuration,
          chatProvider: widget.provider,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 600;
                return Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          if (!isDesktop)
                            _HorizontalUserList(
                              provider: widget.provider,
                              onUserTap: _onUserTap,
                              onOpenConfig: _openConfig,
                            ),
                          Expanded(
                            child: Stack(
                              children: [
                                _MessageList(
                                  provider: widget.provider,
                                  controller: _scrollController,
                                  notifications: _activeNotifications,
                                  listKey: listKey,
                                  onRemoveNotification: _removeNotification,
                                ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: _InputArea(
                                    controller: _controller,
                                    focusNode: _focusNode,
                                    provider: widget.provider,
                                    onSend: _sendMessage,
                                    showNickname: isDesktop,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isDesktop)
                      _VerticalUserList(
                        provider: widget.provider,
                        onUserTap: _onUserTap,
                        onOpenConfig: _openConfig,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _onUserTap(String nickname) {
    if (widget.provider.currentDmNickname == nickname) {
      widget.provider.setDmMode(null);
      _focusNode.requestFocus();
    } else if (nickname != widget.provider.configuration.nickname) {
      widget.provider.setDmMode(nickname);
      _focusNode.requestFocus();
    }
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.provider,
    required this.controller,
    required this.notifications,
    required this.listKey,
    required this.onRemoveNotification,
  });

  final ChatProvider provider;
  final ScrollController controller;
  final List<_NotificationItem> notifications;
  final GlobalKey<AnimatedListState> listKey;
  final ValueSetter<String> onRemoveNotification;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: provider,
      builder: (context, child) {
        final messages = provider.messages;
        return Stack(
          children: [
            ListView.builder(
              padding:
                  MediaQuery.paddingOf(context) +
                  const EdgeInsets.only(bottom: 8.0),
              reverse: true,
              controller: controller,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              itemCount: messages.length + 1,
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

                final message = messages[messages.length - index];
                bool showDateDivider = false;
                if (index == messages.length) {
                  showDateDivider = message.date != null;
                } else {
                  final previousMessage = messages[messages.length - index - 1];
                  showDateDivider = _shouldShowDateDivider(
                    previousMessage,
                    message,
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showDateDivider)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                          child: Text(
                            '${message.date!.year}-${message.date!.month.toString().padLeft(2, '0')}-${message.date!.day.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    MessageBubble(message: message),
                  ],
                );
              },
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
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

final class _InputArea extends StatelessWidget {
  const _InputArea({
    required this.controller,
    required this.focusNode,
    required this.provider,
    required this.onSend,
    required this.showNickname,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ChatProvider provider;
  final VoidCallback onSend;
  final bool showNickname;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: provider,
        builder: (context, child) {
          final users = [...provider.onlineUsers]
            ..remove(provider.configuration.nickname);
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (showNickname) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14.0),
                    child: Text(
                      '[${provider.configuration.nickname}]:',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                ],
                Expanded(
                  child: MentionsAutocomplete(
                    controller: controller,
                    focusNode: focusNode,
                    users: users,
                    triggers: [
                      const TagAutocompleteTrigger(),
                      const CommandAutocompleteTrigger(command: 'dm'),
                      const CommandAutocompleteTrigger(command: 'whois'),
                    ],
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      enabled: provider.isConnected,
                      decoration: InputDecoration(
                        prefix: provider.currentDmNickname != null
                            ? _DmIndicator(
                                user: provider.currentDmNickname!,
                                onTap: () {
                                  provider.setDmMode(null);
                                  focusNode.requestFocus();
                                },
                              )
                            : null,
                        hintText: 'Type a message...',
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(32.0)),
                        ),
                        fillColor: Colors.black87,
                        filled: true,
                      ),
                      onSubmitted: (_) => onSend(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: provider.isConnected ? onSend : null,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

final class _NotificationsArea extends StatefulWidget {
  const _NotificationsArea({
    required this.listKey,
    required this.notifications,
    required this.onRemoveNotification,
  });

  final GlobalKey<AnimatedListState> listKey;
  final List<_NotificationItem> notifications;
  final ValueSetter<String> onRemoveNotification;

  @override
  State<_NotificationsArea> createState() => _NotificationsAreaState();
}

class _NotificationsAreaState extends State<_NotificationsArea> {
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: widget.notifications.isEmpty,
      child: AnimatedList.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(8.0),
        key: widget.listKey,
        initialItemCount: widget.notifications.length,
        removedSeparatorBuilder: (context, index, animation) {
          return const SizedBox(height: 8.0);
        },
        separatorBuilder: (context, index, animation) {
          return const SizedBox(height: 8.0);
        },
        itemBuilder: (context, index, animation) {
          final notification = widget.notifications[index];
          return Center(
            child: _NotificationPill(
              text: Text(notification.text),
              onTap: () => widget.onRemoveNotification(notification.id),
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

final class _DmIndicator extends StatelessWidget {
  const _DmIndicator({required this.user, required this.onTap});

  final String user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 8.0),
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          decoration: BoxDecoration(
            color: getNicknameColor(user).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Text(
            '@$user',
            style: TextStyle(
              color: getNicknameColor(user),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

final class _HorizontalUserList extends StatelessWidget {
  const _HorizontalUserList({
    required this.provider,
    required this.onUserTap,
    required this.onOpenConfig,
  });

  final ChatProvider provider;
  final ValueChanged<String> onUserTap;
  final VoidCallback onOpenConfig;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.black12,
      width: double.infinity,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8.0,
        runSpacing: 8.0,
        children: [
          IconButton(onPressed: onOpenConfig, icon: const Icon(Icons.settings)),
          for (final user in provider.onlineUsers)
            TextButton(
              child: Text(
                ' $user ',
                style: TextStyle(color: getNicknameColor(user)),
              ),
              onPressed: () => onUserTap(user),
            ),
        ],
      ),
    );
  }
}

final class _VerticalUserList extends StatelessWidget {
  const _VerticalUserList({
    required this.provider,
    required this.onUserTap,
    required this.onOpenConfig,
  });

  final ChatProvider provider;
  final ValueChanged<String> onUserTap;
  final VoidCallback onOpenConfig;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 250),
      child: Card(
        child: ListenableBuilder(
          listenable: provider,
          builder: (context, _) {
            final users = provider.onlineUsers;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(8.0),
                  color: Colors.black12,
                  child: Text(
                    'Online Users (${users.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      return _VerticalUserListItem(
                        user: Text(
                          users[index],
                          style: TextStyle(
                            color: getNicknameColor(users[index]),
                          ),
                        ),
                        onTap: () => onUserTap(users[index]),
                      );
                    },
                  ),
                ),
                TextButton.icon(
                  onPressed: onOpenConfig,
                  icon: const Icon(Icons.settings),
                  label: const Text('Settings'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

final class _VerticalUserListItem extends StatelessWidget {
  const _VerticalUserListItem({required this.user, required this.onTap});

  final Widget user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: user,
        ),
      ),
    );
  }
}

class _NotificationItem {
  final String id;
  final String text;

  _NotificationItem(this.id, this.text);
}
