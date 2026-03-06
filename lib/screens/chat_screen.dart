import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:lispinto_chat/core/delete_aware_text_controller.dart';
import 'package:lispinto_chat/core/get_nickname_color.dart';
import 'package:lispinto_chat/core/responsive.dart';
import 'package:lispinto_chat/core/router.dart';
import 'package:lispinto_chat/core/service_locator.dart';
import 'package:lispinto_chat/providers/chat_provider.dart';
import 'package:lispinto_chat/widgets/connection_status_indicator.dart';
import 'package:lispinto_chat/widgets/input_area.dart';
import 'package:lispinto_chat/widgets/join_channel_dialog.dart';
import 'package:lispinto_chat/widgets/message_list.dart';
import 'package:lispinto_chat/widgets/search_input.dart';
import 'package:lispinto_chat/widgets/text_styles.dart';
import 'package:lispinto_chat/widgets/user_list_drawers.dart';

/// Intent to trigger the search bar from keyboard shortcuts.
class SearchIntent extends Intent {
  /// Creates a [SearchIntent].
  const SearchIntent();
}

/// Intent to close the search bar from keyboard shortcuts.
class CloseSearchIntent extends Intent {
  /// Creates a [CloseSearchIntent].
  const CloseSearchIntent();
}

/// The main chat screen of the app.
final class ChatScreen extends StatefulWidget {
  /// Creates a [ChatScreen].
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

enum _MobileDrawerType { users, options }

class _ChatScreenState extends State<ChatScreen> {
  late final ChatProvider _provider;
  late final DeleteAwareEditingController _controller;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final listKey = GlobalKey<AnimatedListState>();
  StreamSubscription? _notificationSubscription;

  bool _isSearchVisible = false;
  late final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;

  final List<NotificationItem> _activeNotifications = [];
  int _notificationCounter = 0;
  _MobileDrawerType _mobileDrawerType = _MobileDrawerType.users;

  @override
  void initState() {
    super.initState();
    _provider = locator<ChatProvider>();
    _controller = DeleteAwareEditingController(
      onDeleteEmpty: () => _provider.setDmMode(null),
      focusNode: _focusNode,
      builder: (context, text, style, withComposing) {
        return TextSpan(
          style: style,
          children: buildStylizedText(context: context, text: text),
        );
      },
    );

    _controller.addListener(_onTextChanged);
    _notificationSubscription = _provider.notifications.listen((notification) {
      if (!mounted) return;

      final id = 'notif_${_notificationCounter++}';
      final item = NotificationItem(id, notification);

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

  void _removeNotification(String id) {
    if (!mounted) return;
    final index = _activeNotifications.indexWhere((n) => n.id == id);
    if (index == -1) return;

    final removedItem = _activeNotifications.removeAt(index);
    if (listKey.currentState == null) return;

    listKey.currentState!.removeItem(index, (context, animation) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: SizeTransition(
          sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          axisAlignment: 0.0,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Center(
              child: Material(
                borderRadius: BorderRadius.circular(32.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 4.0,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.inversePrimary,
                    borderRadius: BorderRadius.circular(32.0),
                  ),
                  child: Text(
                    removedItem.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
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
        final users = [..._provider.onlineUsers]
          ..remove(_provider.configuration.nickname);
        if (users.contains(username)) {
          _provider.setDmMode(username);
          _controller.clear();
        }
      }
    }
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
        _provider.clearMessages();
      } else if (text == '/quit') {
        _quit();
      } else {
        _provider.sendMessage(text);
      }
      _controller.clear();
      _focusNode.requestFocus();
      _scrollToBottom();
    }
  }

  void _openConfig() {
    const ConfigurationsRoute().push(context);
  }

  void _quit() {
    _provider.configuration.setAutoConnect(false);
    _provider.disconnect();
    if (mounted) {
      const InitialRoute().go(context);
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _provider.search(query);
        });
      }
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (!_isSearchVisible) {
        _searchController.clear();
        _provider.search('');
        _focusNode.requestFocus();
      } else {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = context.isDesktop;

    return FocusableActionDetector(
      autofocus: true,
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
            const SearchIntent(),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            const SearchIntent(),
        const SingleActivator(LogicalKeyboardKey.escape):
            const CloseSearchIntent(),
      },
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
        appBar: !isDesktop ? _buildMobileAppBar() : null,
        endDrawer: !isDesktop
            ? switch (_mobileDrawerType) {
                _MobileDrawerType.users => _buildMobileUserDrawer(),
                _MobileDrawerType.options => _buildMobileOptionsMenuDrawer(),
              }
            : null,
        body: isDesktop
            ? SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    Expanded(flex: 3, child: _buildChatArea()),
                    VerticalUserList(
                      provider: _provider,
                      onUserTap: _onUserTap,
                      onUserMenuTap: _showUserContextMenu,
                      onOpenConfig: _openConfig,
                      onQuit: _quit,
                      onAddChannel: _showAddChannelDialog,
                    ),
                  ],
                ),
              )
            : SafeArea(bottom: false, child: _buildChatArea()),
      ),
    );
  }

  void _onUserTap(String nickname) {
    if (context.isMobile) {
      if (mounted) Navigator.maybePop(context);
    }

    final bool didChangeDmMode;
    if (_provider.currentDmNickname == nickname) {
      _provider.setDmMode(null);
      didChangeDmMode = true;
    } else if (nickname != _provider.configuration.nickname) {
      _provider.setDmMode(nickname);
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

  /// Shows a dialog to join or create a channel.
  Future<void> _showAddChannelDialog() {
    return showDialog(
      context: context,
      builder: (context) => JoinChannelDialog(onJoin: _provider.joinChannel),
    );
  }

  Widget _buildChatArea() {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              MessageList(
                provider: _provider,
                controller: _scrollController,
                notifications: _activeNotifications,
                listKey: listKey,
                onRemoveNotification: _removeNotification,
              ),
              Positioned(
                left: 0.0,
                right: 0.0,
                bottom: 0.0,
                child: InputArea(
                  controller: _controller,
                  focusNode: _focusNode,
                  provider: _provider,
                  onSend: _sendMessage,
                ),
              ),
              Positioned(
                top: 8.0,
                left: 8.0,
                right: 8.0,
                child: SearchInput(
                  isSearchActive: _isSearchVisible,
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
    );
  }

  void _showUserContextMenu(
    BuildContext context,
    Offset position,
    String user,
  ) async {
    final isSelf = user == _provider.configuration.nickname;
    final action = await showMenu<VoidCallback>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        if (!isSelf)
          PopupMenuItem(
            value: () => _onUserTap(user),
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Direct Message '),
                  TextSpan(
                    text: user,
                    style: TextStyle(
                      color: getNicknameColor(user),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        PopupMenuItem(
          value: () => _provider.sendMessage('/whois $user'),
          child: isSelf
              ? const Text('Who am I?')
              : Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Who is '),
                      TextSpan(
                        text: user,
                        style: TextStyle(
                          color: getNicknameColor(user),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(text: '?'),
                    ],
                  ),
                ),
        ),
      ],
    );

    action?.call();
  }

  PreferredSizeWidget _buildMobileAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          ListenableBuilder(
            listenable: _provider,
            builder: (context, child) {
              return ConnectionStatusIndicator(
                state: _provider.connectionState,
                shouldShowLabel: false,
              );
            },
          ),
          const Gap(8.0),
          InkWell(
            mouseCursor: SystemMouseCursors.click,
            onTap: () {
              showModalBottomSheet(
                context: context,
                builder: (context) {
                  return MobileChannelSheet(
                    provider: _provider,
                    onChannelSelected: (channel) {
                      _provider.joinChannel(channel);
                      Navigator.pop(context);
                    },
                  );
                },
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListenableBuilder(
                    listenable: _provider,
                    builder: (context, child) {
                      return Text(_provider.activeChannel);
                    },
                  ),
                  const Icon(Icons.expand_more),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.people),
              onPressed: () {
                setState(() => _mobileDrawerType = _MobileDrawerType.users);
                Scaffold.of(context).openEndDrawer();
              },
              tooltip: 'Online Users',
            );
          },
        ),
        Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {
                setState(() => _mobileDrawerType = _MobileDrawerType.options);
                Scaffold.of(context).openEndDrawer();
              },
              tooltip: 'Options',
            );
          },
        ),
      ],
    );
  }

  Widget _buildMobileOptionsMenuDrawer() {
    return Drawer(
      shape: const LinearBorder(),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              width: double.infinity,
              child: Text(
                'Options',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            if (_provider.activeChannel != '#general' &&
                _provider.currentDmNickname == null)
              ListenableBuilder(
                listenable: _provider,
                builder: (context, _) {
                  return SwitchListTile(
                    title: const Text('Private Channel'),
                    value: _provider.isCurrentChannelPrivate,
                    onChanged: (value) {
                      _provider.setPrivateChannel(value);
                    },
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                _openConfig();
              },
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip),
              title: const Text('Privacy Policy'),
              onTap: () {
                Navigator.pop(context);
                const PrivacyPolicyRoute().go(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('Licenses'),
              onTap: () {
                Navigator.pop(context);
                const LicensesRoute().go(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app),
              title: const Text('Quit'),
              onTap: () {
                Navigator.pop(context);
                _quit();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileUserDrawer() {
    return Drawer(
      shape: const LinearBorder(),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: _provider,
          builder: (context, child) {
            final users = _provider.onlineUsers;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16.0),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Text(
                    'Online Users (${users.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      return VerticalUserListItem(
                        user: Text(
                          users[index],
                          style: TextStyle(
                            color: getNicknameColor(users[index]),
                          ),
                        ),
                        onTap: () => _onUserTap(users[index]),
                        onSecondaryTapDown: (details) {
                          _showUserContextMenu(
                            context,
                            details.globalPosition,
                            users[index],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
