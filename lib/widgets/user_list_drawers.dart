import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lispinto_chat/core/app_localizations.dart';
import 'package:lispinto_chat/core/responsive.dart';
import 'package:lispinto_chat/providers/chat_provider.dart';

import '../core/get_nickname_color.dart';
import 'connection_status_indicator.dart';

/// A vertical list of users and channels for desktop-like layouts.
class VerticalUserList extends StatefulWidget {
  /// Creates a [VerticalUserList].
  const VerticalUserList({
    super.key,
    required this.provider,
    required this.onUserTap,
    required this.onUserMenuTap,
    required this.onOpenConfig,
    required this.onQuit,
    required this.onAddChannel,
  });

  /// The provider that manages the chat state.
  final ChatProvider provider;

  /// Called when a user's name is tapped.
  final ValueChanged<String> onUserTap;

  /// Called when the context menu for a user is triggered.
  final void Function(BuildContext, Offset, String) onUserMenuTap;

  /// Called to open the configurations screen.
  final VoidCallback onOpenConfig;

  /// Called to quit the app.
  final VoidCallback onQuit;

  /// Called to join or add a new channel.
  final VoidCallback onAddChannel;

  @override
  State<VerticalUserList> createState() => _VerticalUserListState();
}

class _VerticalUserListState extends State<VerticalUserList> {
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
  void didUpdateWidget(covariant VerticalUserList oldWidget) {
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = GlobalObjectKey(widget.provider.activeChannel);
      final context = key.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.5,
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
        builder: (context, child) {
          final usersFuture = widget.provider.usersFuture;
          final channelsFuture = widget.provider.channelsFuture;

          final users = usersFuture?.result?.asValue?.value ?? [];
          final channels = channelsFuture?.result?.asValue?.value ?? {};

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                color: Colors.black12,
                child: Row(
                  children: [
                    Expanded(
                      child: usersFuture != null && usersFuture.result == null
                          ? const Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Online Users',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Gap(8.0),
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'Online Users (${users.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                    const Gap(8.0),
                    ConnectionStatusIndicator(
                      state: widget.provider.connectionState,
                      shouldShowLabel: isDesktop,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    return VerticalUserListItem(
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 4.0,
                ),
                color: Colors.black12,
                child: Row(
                  children: [
                    if (channelsFuture != null && channelsFuture.result == null)
                      const Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Channels',
                                style: TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Gap(8.0),
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ],
                        ),
                      )
                    else
                      Expanded(
                        child: Text(
                          'Channels (${channels.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.add_box, size: 18.0),
                      padding: EdgeInsets.zero,
                      onPressed: widget.onAddChannel,
                      tooltip: AppLocalizations.of(context).joinChannel,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final channelEntry in channels.entries)
                      VerticalChannelListItem(
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
              if (widget.provider.activeChannel != 'general')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context).privateChannel,
                        ),
                      ),
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
                      icon: const Icon(Icons.settings, size: 18.0),
                      label: const Text(
                        'Settings',
                        style: TextStyle(fontSize: 12.0),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: widget.onQuit,
                      icon: const Icon(Icons.exit_to_app, size: 18.0),
                      label: const Text(
                        'Quit',
                        style: TextStyle(fontSize: 12.0),
                      ),
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
        constraints: const BoxConstraints(maxWidth: 250.0),
        child: child,
      );
    }
    return child;
  }
}

/// A list item representing a user in the user list.
class VerticalUserListItem extends StatelessWidget {
  /// Creates a [VerticalUserListItem].
  const VerticalUserListItem({
    super.key,
    required this.user,
    required this.onTap,
    required this.onSecondaryTapDown,
  });

  /// The widget displaying the user's name/info.
  final Widget user;

  /// Called when the item is tapped.
  final VoidCallback onTap;

  /// Called when the item is right-clicked or long-pressed.
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

/// A list item representing a channel in the channel list.
class VerticalChannelListItem extends StatelessWidget {
  /// Creates a [VerticalChannelListItem].
  const VerticalChannelListItem({
    super.key,
    required this.channel,
    required this.userCount,
    required this.isActive,
    required this.onTap,
  });

  /// The name of the channel.
  final String channel;

  /// The number of online users in the channel.
  final int userCount;

  /// Whether this is the currently active channel.
  final bool isActive;

  /// Called when the channel is tapped.
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

/// A bottom sheet for selecting channels on mobile.
class MobileChannelSheet extends StatelessWidget {
  /// The provider that manages the chat state.
  final ChatProvider provider;

  /// Called when a channel is selected.
  final ValueChanged<String> onChannelSelected;

  /// Called to join or add a new channel.
  final VoidCallback onAddChannel;

  /// Creates a [MobileChannelSheet].
  const MobileChannelSheet({
    super.key,
    required this.provider,
    required this.onChannelSelected,
    required this.onAddChannel,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: provider,
      builder: (context, child) {
        final channelsFuture = provider.channelsFuture;
        final channels = channelsFuture?.result?.asValue?.value ?? {};
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              width: double.infinity,
              child: Row(
                children: [
                  Expanded(
                    child:
                        channelsFuture != null && channelsFuture.result == null
                        ? Row(
                            children: [
                              Text(
                                'Channels',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const Gap(8.0),
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            'Channels (${channels.length})',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_box),
                    onPressed: onAddChannel,
                    tooltip: AppLocalizations.of(context).joinChannel,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final channelEntry in channels.entries)
                    ListTile(
                      selected: channelEntry.key == provider.activeChannel,
                      title: Text(channelEntry.key),
                      trailing: Text(
                        AppLocalizations.of(
                          context,
                        ).userCount(channelEntry.value),
                      ),
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
