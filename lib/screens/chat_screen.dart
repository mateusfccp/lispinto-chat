import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lispinto_chat/core/delete_aware_text_controller.dart';
import 'package:lispinto_chat/core/get_nickname_color.dart';
import 'package:lispinto_chat/core/message_grouper.dart';
import 'package:lispinto_chat/core/responsive.dart';
import 'package:lispinto_chat/core/router.dart';
import 'package:lispinto_chat/core/service_locator.dart';
import 'package:lispinto_chat/core/user_configuration.dart';
import 'package:lispinto_chat/models/chat_message.dart';
import 'package:lispinto_chat/providers/chat_provider.dart';
import 'package:lispinto_chat/services/image_upload_service.dart';
import 'package:lispinto_chat/widgets/autocomplete_dropdown.dart';
import 'package:lispinto_chat/widgets/autocomplete_triggers/channel_autocomplete_trigger.dart';
import 'package:lispinto_chat/widgets/autocomplete_triggers/command_autocomplete_trigger.dart';
import 'package:lispinto_chat/widgets/autocomplete_triggers/tag_autocomplete_trigger.dart';
import 'package:lispinto_chat/widgets/message_bubble.dart';
import 'package:lispinto_chat/widgets/text_styles.dart';
import 'package:prototype_constrained_box/prototype_constrained_box.dart';
import 'package:super_clipboard/super_clipboard.dart';

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

  final List<_NotificationItem> _activeNotifications = [];
  int _notificationCounter = 0;
  _MobileDrawerType _mobileDrawerType = .users;

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
              child: _NotificationPill(
                text: Text(removedItem.text),
                onTap: () {},
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
                .users => _buildMobileUserDrawer(),
                .options => _buildMobileOptionsMenuDrawer(),
              }
            : null,
        body: isDesktop
            ? SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    Expanded(flex: 3, child: _buildChatArea()),
                    _VerticalUserList(
                      provider: _provider,
                      onUserTap: _onUserTap,
                      onUserMenuTap: _showUserContextMenu,
                      onOpenConfig: _openConfig,
                      onQuit: _quit,
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

  Widget _buildChatArea() {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              _MessageList(
                provider: _provider,
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
                  provider: _provider,
                  onSend: _sendMessage,
                ),
              ),
              Positioned(
                top: 8.0,
                left: 8.0,
                right: 8.0,
                child: _SearchInput(
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
      title: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: () {
          showModalBottomSheet(
            context: context,
            builder: (context) => _MobileChannelSheet(
              provider: _provider,
              onChannelSelected: (channel) {
                _provider.joinChannel(channel);
                Navigator.pop(context);
              },
            ),
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
      actions: [
        Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.people),
              onPressed: () {
                setState(() => _mobileDrawerType = .users);
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
                setState(() => _mobileDrawerType = .options);
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
      shape: LinearBorder(),
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
                Navigator.pop(context); // Close the drawer
                _openConfig();
              },
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app),
              title: const Text('Quit'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
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
      shape: LinearBorder(),
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
                      return _VerticalUserListItem(
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

final class _SearchInput extends StatelessWidget {
  const _SearchInput({
    required this.isSearchActive,
    required this.searchController,
    required this.searchFocusNode,
    required this.onToggleSearch,
    required this.onSearchChanged,
  });

  final bool isSearchActive;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final VoidCallback onToggleSearch;
  final ValueChanged<String> onSearchChanged;

  static final _borderWidth = 1.0;

  @override
  Widget build(BuildContext context) {
    final iconButton = IconButton(
      icon: const Icon(Icons.search),
      onPressed: onToggleSearch,
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
        final configuration = locator<UserConfiguration>();
        final displayedMessages = configuration.groupMessages
            ? locator<MessageGrouper>().group(messages)
            : messages;

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
                bool showDateDivider = false;
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

enum _AttachmentOption { uploadPhoto }

final class _InputArea extends StatefulWidget {
  const _InputArea({
    required this.controller,
    required this.focusNode,
    required this.provider,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ChatProvider provider;
  final VoidCallback onSend;

  @override
  State<_InputArea> createState() => _InputAreaState();
}

class _InputAreaState extends State<_InputArea> {
  bool _isUploading = false;

  Future<void> _uploadImage(Uint8List imageBytes) async {
    final imgbbApiKey = locator<UserConfiguration>().imgbbApiKey.trim();
    if (imgbbApiKey.isEmpty) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('ImgBB API Key Required'),
            content: const Text(
              'To upload images, please configure your ImgBB API Key in the settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  const ConfigurationsRoute().push(context);
                },
                child: const Text('Go to Settings'),
              ),
            ],
          ),
        );
      }
      return;
    }

    setState(() {
      _isUploading = true;
    });
    try {
      final uploadService = locator<ImageUploadService>();
      final url = await uploadService.uploadImage(imageBytes);
      final currentText = widget.controller.text;
      if (currentText.isEmpty) {
        widget.controller.text = url;
      } else {
        widget.controller.text = '$currentText $url';
      }
      widget.focusNode.requestFocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to upload image: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      final bytes = await file.readAsBytes();
      await _uploadImage(bytes);
    }
  }

  Future<void> _handleSuperClipboardPaste() async {
    final clipboard = SystemClipboard.instance;
    bool uploaded = false;

    if (clipboard != null) {
      final imgbbApiKey = locator<UserConfiguration>().imgbbApiKey.trim();
      final canUpload = imgbbApiKey.isNotEmpty;

      final reader = await clipboard.read();

      for (final item in reader.items) {
        if (canUpload && item.canProvide(Formats.fileUri)) {
          final uri = await item.readValue(Formats.fileUri);
          if (uri != null) {
            final path = uri.toFilePath().toLowerCase();
            if (path.endsWith('.png') ||
                path.endsWith('.jpg') ||
                path.endsWith('.jpeg') ||
                path.endsWith('.gif') ||
                path.endsWith('.webp')) {
              final bytes = await File.fromUri(uri).readAsBytes();
              await _uploadImage(bytes);
              uploaded = true;
              continue; // Handled this item
            }
          }
        }

        // Try raw image data
        if (canUpload && item.canProvide(Formats.png)) {
          item.getFile(Formats.png, (file) async {
            final bytes = await file.readAll();
            if (mounted) _uploadImage(bytes);
          });
          uploaded = true;
        } else if (canUpload && item.canProvide(Formats.jpeg)) {
          item.getFile(Formats.jpeg, (file) async {
            final bytes = await file.readAll();
            if (mounted) _uploadImage(bytes);
          });
          uploaded = true;
        }
      }
    }

    if (!uploaded && mounted) {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null && data!.text!.isNotEmpty) {
        final text = data.text!;
        final selection = widget.controller.selection;
        if (selection.isValid && selection.start >= 0) {
          final newText = widget.controller.text.replaceRange(
            selection.start,
            selection.end,
            text,
          );
          widget.controller.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(
              offset: selection.start + text.length,
            ),
          );
        } else {
          final newText = widget.controller.text + text;
          widget.controller.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newText.length),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: widget.provider,
        builder: (context, child) {
          final sendButton = IconButton(
            icon: const Icon(Icons.send),
            onPressed: (widget.provider.isConnected && !_isUploading)
                ? widget.onSend
                : null,
          );

          final users = [
            for (final user in widget.provider.onlineUsers)
              if (user != widget.provider.configuration.nickname) user,
          ];

          final channels = [...widget.provider.channels.keys];

          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PrototypeConstrainedBox.tightFor(
                  height: true,
                  prototype: sendButton,
                  child: PopupMenuButton<_AttachmentOption>(
                    icon: const Icon(Icons.add),
                    onSelected: (value) {
                      if (value == .uploadPhoto) {
                        final imgbbApiKey = locator<UserConfiguration>()
                            .imgbbApiKey
                            .trim();
                        if (imgbbApiKey.isEmpty) {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('ImgBB API Key Required'),
                              content: const Text(
                                'To upload images, please configure your ImgBB API Key in the settings.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    const ConfigurationsRoute().push(context);
                                  },
                                  child: const Text('Go to Settings'),
                                ),
                              ],
                            ),
                          );
                        } else {
                          _pickImage();
                        }
                      }
                    },
                    itemBuilder: (context) {
                      return [
                        const PopupMenuItem(
                          value: .uploadPhoto,
                          child: Text('Upload photo'),
                        ),
                      ];
                    },
                  ),
                ),
                const Gap(8.0),
                Expanded(
                  child: AutocompleteDropdown(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    triggers: [
                      TagAutocompleteTrigger(suggestions: users),
                      ChannelAutocompleteTrigger(suggestions: channels),
                      CommandAutocompleteTrigger(
                        command: 'dm',
                        suggestions: users,
                      ),
                      CommandAutocompleteTrigger(
                        command: 'whois',
                        suggestions: users,
                      ),
                    ],
                    child: Focus(
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent) {
                          final isEnter =
                              event.logicalKey == LogicalKeyboardKey.enter ||
                              event.logicalKey ==
                                  LogicalKeyboardKey.numpadEnter;

                          if (isEnter &&
                              !HardwareKeyboard.instance.isShiftPressed) {
                            widget.onSend();
                            return KeyEventResult.handled;
                          }

                          if (event.logicalKey == LogicalKeyboardKey.keyV &&
                              (HardwareKeyboard.instance.isMetaPressed ||
                                  HardwareKeyboard.instance.isControlPressed)) {
                            _handleSuperClipboardPaste();
                            return KeyEventResult.handled;
                          }
                        }
                        return KeyEventResult.ignored;
                      },
                      child: TextField(
                        controller: widget.controller,
                        focusNode: widget.focusNode,
                        enabled: widget.provider.isConnected && !_isUploading,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        contextMenuBuilder: (context, editableTextState) {
                          final buttonItems =
                              editableTextState.contextMenuButtonItems;
                          final pasteButton = ContextMenuButtonItem(
                            type: ContextMenuButtonType.paste,
                            onPressed: () {
                              _handleSuperClipboardPaste();
                              editableTextState.hideToolbar();
                            },
                          );
                          final index = buttonItems.indexWhere(
                            (item) => item.type == ContextMenuButtonType.paste,
                          );
                          if (index >= 0) {
                            buttonItems[index] = pasteButton;
                          } else {
                            buttonItems.add(pasteButton);
                          }
                          return AdaptiveTextSelectionToolbar.buttonItems(
                            anchors: editableTextState.contextMenuAnchors,
                            buttonItems: buttonItems,
                          );
                        },
                        decoration: InputDecoration(
                          prefixIcon: widget.provider.currentDmNickname != null
                              ? _DmIndicator(
                                  user: widget.provider.currentDmNickname!,
                                  onTap: () {
                                    widget.provider.setDmMode(null);
                                    widget.focusNode.requestFocus();
                                  },
                                )
                              : null,
                          suffixIcon: _isUploading
                              ? const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : null,
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 0,
                            minHeight: 0,
                          ),
                          isDense: context.isDesktop,
                          hintText: 'Type a message...',
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(
                              Radius.circular(32.0),
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20.0,
                            vertical: 12.0,
                          ),
                          fillColor: Colors.black87,
                          filled: true,
                        ),
                      ),
                    ),
                  ),
                ),
                const Gap(4.0),
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
            user,
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

final class _VerticalUserList extends StatefulWidget {
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
  State<_VerticalUserList> createState() => _VerticalUserListState();
}

class _VerticalUserListState extends State<_VerticalUserList> {
  final ScrollController _channelsScrollController = ScrollController();
  String? _lastActiveChannel;

  @override
  void initState() {
    super.initState();
    _lastActiveChannel = widget.provider.activeChannel;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToActiveChannel(),
    );
  }

  @override
  void didUpdateWidget(covariant _VerticalUserList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.provider.activeChannel != _lastActiveChannel) {
      _lastActiveChannel = widget.provider.activeChannel;
      _scrollToActiveChannel();
    }
  }

  @override
  void dispose() {
    _channelsScrollController.dispose();
    super.dispose();
  }

  void _scrollToActiveChannel() {
    // We add a small delay to ensure the widget is fully built and laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = GlobalObjectKey(widget.provider.activeChannel);
      final context = key.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.5, // Center the active channel in the viewport
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = context.isDesktop;

    final child = Card(
      child: ListenableBuilder(
        listenable: widget.provider,
        builder: (context, _) {
          final users = widget.provider.onlineUsers;
          final channels = widget.provider.channels;
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
                        style: TextStyle(color: getNicknameColor(users[index])),
                      ),
                      onTap: () => widget.onUserTap(users[index]),
                      onSecondaryTapDown: (details) {
                        widget.onUserMenuTap(
                          context,
                          details.globalPosition,
                          users[index],
                        );
                      },
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8.0),
                color: Colors.black12,
                child: Text(
                  'Channels (${channels.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final channelEntry in channels.entries)
                      _VerticalChannelListItem(
                        channel: channelEntry.key,
                        userCount: channelEntry.value,
                        isActive:
                            channelEntry.key == widget.provider.activeChannel,
                        onTap: () =>
                            widget.provider.joinChannel(channelEntry.key),
                      ),
                  ],
                ),
              ),
              if (widget.provider.activeChannel != '#general')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      const Text('Private Channel'),
                      const Spacer(),
                      Switch(
                        value: widget.provider.isCurrentChannelPrivate,
                        onChanged: widget.provider.setPrivateChannel,
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4.0,
                  runSpacing: 4.0,
                  children: [
                    TextButton.icon(
                      onPressed: widget.onOpenConfig,
                      icon: const Icon(Icons.settings, size: 18),
                      label: const Text(
                        'Settings',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: widget.onQuit,
                      icon: const Icon(Icons.exit_to_app, size: 18),
                      label: const Text('Quit', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    if (isDesktop) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 250),
        child: child,
      );
    }
    return child;
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
    return InkWell(
      mouseCursor: SystemMouseCursors.click,
      onTap: onTap,
      onSecondaryTapDown: onSecondaryTapDown,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: user,
      ),
    );
  }
}

class _NotificationItem {
  final String id;
  final String text;

  _NotificationItem(this.id, this.text);
}

final class _VerticalChannelListItem extends StatelessWidget {
  const _VerticalChannelListItem({
    required this.channel,
    required this.userCount,
    required this.isActive,
    required this.onTap,
  });

  final String channel;
  final int userCount;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? Colors.white24 : Colors.transparent,
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            '$channel ($userCount)',
            style: TextStyle(
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileChannelSheet extends StatelessWidget {
  final ChatProvider provider;
  final ValueChanged<String> onChannelSelected;

  const _MobileChannelSheet({
    required this.provider,
    required this.onChannelSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        final channels = provider.channels;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Channels',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final channelEntry in channels.entries)
                    ListTile(
                      title: Text(channelEntry.key),
                      trailing: Text('${channelEntry.value} user(s)'),
                      selected: channelEntry.key == provider.activeChannel,
                      onTap: () => onChannelSelected(channelEntry.key),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
