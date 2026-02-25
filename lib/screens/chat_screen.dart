import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Intent to trigger the search bar from keyboard shortcuts.
class SearchIntent extends Intent {
  const SearchIntent();
}

/// Intent to close the search bar from keyboard shortcuts.
class CloseSearchIntent extends Intent {
  const CloseSearchIntent();
}

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

  bool _isSearchVisible = false;
  late final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;

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
          _controller.clear();
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

    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus &&
          _searchController.text.isEmpty &&
          _isSearchVisible) {
        if (mounted) {
          setState(() {
            _isSearchVisible = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
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
      } else if (text == '/quit') {
        _quit();
      } else {
        widget.provider.sendMessage(text);
      }
      _controller.clear();
      _focusNode.requestFocus();
      _scrollToBottom();
    }
  }

  void _openConfig() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ConfigurationsScreen(
          configuration: widget.provider.configuration,
          chatProvider: widget.provider,
        ),
      ),
    );
  }

  void _quit() {
    widget.provider.configuration.setAutoConnect(false);
    widget.provider.disconnect();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      widget.provider.search(query);
      if (mounted) {
        setState(() {}); // Trigger rebuild to show/hide clear icon
      }
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (!_isSearchVisible) {
        _searchController.clear();
        widget.provider.search('');
        _focusNode.requestFocus();
      } else {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyS):
              const SearchIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS):
              const SearchIntent(),
          LogicalKeySet(LogicalKeyboardKey.escape): const CloseSearchIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            SearchIntent: CallbackAction<SearchIntent>(
              onInvoke: (SearchIntent intent) {
                if (!_isSearchVisible) {
                  _toggleSearch();
                } else {
                  _searchFocusNode.requestFocus();
                }
                return null;
              },
            ),
            CloseSearchIntent: CallbackAction<CloseSearchIntent>(
              onInvoke: (CloseSearchIntent intent) {
                if (_isSearchVisible) {
                  _searchController.clear();
                  _onSearchChanged('');
                  setState(() {
                    _isSearchVisible = false;
                    _focusNode.requestFocus();
                  });
                }
                return null;
              },
            ),
          },
          child: Scaffold(
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
                                    onUserMenuTap: _showUserContextMenu,
                                    onOpenConfig: _openConfig,
                                    onQuit: _quit,
                                  ),
                                Expanded(
                                  child: Stack(
                                    children: [
                                      _MessageList(
                                        provider: widget.provider,
                                        controller: _scrollController,
                                        notifications: _activeNotifications,
                                        listKey: listKey,
                                        onRemoveNotification:
                                            _removeNotification,
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
                                          isDesktop: isDesktop,
                                        ),
                                      ),
                                      Positioned(
                                        top: 8.0,
                                        left: 8.0,
                                        right: 8.0,
                                        child: _SearchInput(
                                          isDesktop: isDesktop,
                                          isSearchVisible: _isSearchVisible,
                                          searchController: _searchController,
                                          searchFocusNode: _searchFocusNode,
                                          onToggleSearch: _toggleSearch,
                                          onSearchChanged: _onSearchChanged,
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
                              onUserMenuTap: _showUserContextMenu,
                              onOpenConfig: _openConfig,
                              onQuit: _quit,
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onUserTap(String nickname) {
    final bool didChangeDmMode;
    if (widget.provider.currentDmNickname == nickname) {
      widget.provider.setDmMode(null);
      didChangeDmMode = true;
    } else if (nickname != widget.provider.configuration.nickname) {
      widget.provider.setDmMode(nickname);
      didChangeDmMode = true;
    } else {
      didChangeDmMode = false;
    }

    if (didChangeDmMode) {
      final previousSelection = _controller.selection;
      _focusNode.requestFocus();
      // We wait until the next frame to restore the selection because changing
      // the DM mode might cause the input field to rebuild and mess up the
      // selection.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _controller.selection = previousSelection;
        }
      });
    }
  }

  void _showUserContextMenu(
    BuildContext context,
    Offset position,
    String user,
  ) async {
    final action = await showMenu<VoidCallback>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          value: () => _onUserTap(user),
          child: Text('Direct Message @$user'),
        ),
        PopupMenuItem(
          value: () => widget.provider.sendMessage('/whois $user'),
          child: Text('Whois @$user'),
        ),
      ],
    );

    action?.call();
  }
}

final class _SearchInput extends StatelessWidget {
  const _SearchInput({
    required this.isDesktop,
    required this.isSearchVisible,
    required this.searchController,
    required this.searchFocusNode,
    required this.onToggleSearch,
    required this.onSearchChanged,
  });

  final bool isDesktop;
  final bool isSearchVisible;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final VoidCallback onToggleSearch;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = isSearchVisible ? constraints.maxWidth : 44.0;

          return AnimatedContainer(
            curve: Curves.easeInOut,
            duration: const Duration(milliseconds: 150),
            width: width,
            decoration: BoxDecoration(
              color: Colors.black87,
              border: Border.all(color: Colors.white24, width: 2.0),
              borderRadius: BorderRadius.circular(32.0),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4.0,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: [
                AbsorbPointer(
                  absorbing: isSearchVisible,
                  child: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: onToggleSearch,
                  ),
                ),
                if (isSearchVisible)
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      focusNode: searchFocusNode,
                      onChanged: onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search messages...',
                        isDense: isDesktop,
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
    );
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
                    MessageBubble(
                      message: message,
                      searchQuery: provider.searchQuery,
                      showSeconds: provider.configuration.showTimeSeconds,
                    ),
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
    required this.isDesktop,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ChatProvider provider;
  final VoidCallback onSend;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: provider,
        builder: (context, child) {
          final sendButton = IconButton(
            icon: Icon(Icons.send),
            onPressed: provider.isConnected ? onSend : null,
          );

          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isDesktop) ...[
                  PrototypeConstrainedBox.tightFor(
                    height: true,
                    prototype: sendButton,
                    child: Center(
                      child: Text(
                        '[${provider.configuration.nickname}]:',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                ],
                Expanded(
                  child: MentionsAutocomplete(
                    controller: controller,
                    focusNode: focusNode,
                    users: [
                      for (final user in provider.onlineUsers)
                        if (user != provider.configuration.nickname) user,
                    ],
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
                        prefixIcon: provider.currentDmNickname != null
                            ? _DmIndicator(
                                user: provider.currentDmNickname!,
                                onTap: () {
                                  provider.setDmMode(null);
                                  focusNode.requestFocus();
                                },
                              )
                            : null,
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 0,
                          minHeight: 0,
                        ),
                        isDense: isDesktop,
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
                const SizedBox(width: 4.0),
                sendButton,
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
          margin: const EdgeInsets.symmetric(horizontal: 8.0),
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
    required this.onUserMenuTap,
    required this.onOpenConfig,
    required this.onQuit,
  });

  final ChatProvider provider;
  final void Function(BuildContext, Offset, String) onUserMenuTap;
  final VoidCallback onOpenConfig;
  final VoidCallback onQuit;

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
          IconButton(onPressed: onQuit, icon: const Icon(Icons.exit_to_app)),
          IconButton(onPressed: onOpenConfig, icon: const Icon(Icons.settings)),
          for (final user in provider.onlineUsers)
            Builder(
              builder: (buttonContext) {
                return TextButton(
                  child: Text(
                    ' $user ',
                    style: TextStyle(color: getNicknameColor(user)),
                  ),
                  onPressed: () {
                    final box = buttonContext.findRenderObject() as RenderBox;
                    final position = box.localToGlobal(
                      Offset(0, box.size.height),
                    );
                    onUserMenuTap(context, position, user);
                  },
                );
              },
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
    required this.onUserMenuTap,
    required this.onOpenConfig,
    required this.onQuit,
  });

  final ChatProvider provider;
  final ValueChanged<String> onUserTap;
  final void Function(BuildContext, Offset, String) onUserMenuTap;
  final VoidCallback onOpenConfig;
  final VoidCallback onQuit;

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
                        onSecondaryTapDown: (details) {
                          onUserMenuTap(
                            context,
                            details.globalPosition,
                            users[index],
                          );
                        },
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: onOpenConfig,
                      icon: const Icon(Icons.settings),
                      label: const Text('Settings'),
                    ),
                    TextButton.icon(
                      onPressed: onQuit,
                      icon: const Icon(Icons.exit_to_app),
                      label: const Text('Quit'),
                    ),
                  ],
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
  const _VerticalUserListItem({
    required this.user,
    required this.onTap,
    required this.onSecondaryTapDown,
  });

  final Widget user;
  final VoidCallback onTap;
  final GestureTapDownCallback onSecondaryTapDown;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        onSecondaryTapDown: onSecondaryTapDown,
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
