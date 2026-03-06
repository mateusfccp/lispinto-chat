import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lispinto_chat/core/in_memory_user_configuration.dart';
import 'package:lispinto_chat/core/message_grouper.dart';
import 'package:lispinto_chat/core/router.dart';
import 'package:lispinto_chat/core/service_locator.dart';
import 'package:lispinto_chat/core/user_configuration.dart';
import 'package:lispinto_chat/models/chat_message.dart';
import 'package:lispinto_chat/providers/chat_provider.dart';
import 'package:lispinto_chat/widgets/message_bubble.dart';
import 'package:lispinto_chat/widgets/service_locator_scope.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// A screen that allows the user to configure their settings.
final class ConfigurationsScreen extends StatefulWidget {
  /// Creates a [ConfigurationsScreen].
  const ConfigurationsScreen({super.key});

  @override
  State<ConfigurationsScreen> createState() => _ConfigurationsScreenState();
}

final class _ConfigurationsScreenState extends State<ConfigurationsScreen> {
  late final UserConfiguration _configuration;
  late final ChatProvider _chatProvider;
  late final TextEditingController _nicknameController;
  late final TextEditingController _serverUrlController;
  late final TextEditingController _imgbbApiKeyController;
  late bool _pushNotificationsEnabled;
  late bool _mentionNotificationsEnabled;
  late bool _showTimeSeconds;
  late bool _showImagePreviews;
  late bool _showMarkdown;
  late bool _showEmptyChannels;
  late bool _groupMessages;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _configuration = locator<UserConfiguration>();
    _chatProvider = locator<ChatProvider>();
    _nicknameController = TextEditingController(text: _configuration.nickname);
    _serverUrlController = TextEditingController(
      text: _configuration.serverUrl,
    );
    _imgbbApiKeyController = TextEditingController(
      text: _configuration.imgbbApiKey,
    );
    _pushNotificationsEnabled = _configuration.pushNotificationsEnabled;
    _mentionNotificationsEnabled = _configuration.mentionNotificationsEnabled;
    _showTimeSeconds = _configuration.showTimeSeconds;
    _showImagePreviews = _configuration.showImagePreviews;
    _showMarkdown = _configuration.showMarkdown;
    _showEmptyChannels = _configuration.showEmptyChannels;
    _groupMessages = _configuration.groupMessages;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _serverUrlController.dispose();
    _imgbbApiKeyController.dispose();
    super.dispose();
  }

  bool get _isDirty {
    return _nicknameController.text.trim() != _configuration.nickname ||
        _serverUrlController.text.trim() != _configuration.serverUrl ||
        _imgbbApiKeyController.text.trim() != _configuration.imgbbApiKey ||
        _pushNotificationsEnabled != _configuration.pushNotificationsEnabled ||
        _mentionNotificationsEnabled !=
            _configuration.mentionNotificationsEnabled ||
        _showTimeSeconds != _configuration.showTimeSeconds ||
        _showImagePreviews != _configuration.showImagePreviews ||
        _showMarkdown != _configuration.showMarkdown ||
        _showEmptyChannels != _configuration.showEmptyChannels ||
        _groupMessages != _configuration.groupMessages;
  }

  Future<void> _saveAndPop() async {
    if (_formKey.currentState?.validate() ?? false) {
      final newNickname = _nicknameController.text.trim();
      final newServerUrl = _serverUrlController.text.trim();
      final newImgbbApiKey = _imgbbApiKeyController.text.trim();

      await _configuration.setPushNotificationsEnabled(
        _pushNotificationsEnabled,
      );
      await _configuration.setMentionNotificationsEnabled(
        _mentionNotificationsEnabled,
      );
      await _configuration.setShowTimeSeconds(_showTimeSeconds);
      await _configuration.setShowImagePreviews(_showImagePreviews);
      await _configuration.setShowMarkdown(_showMarkdown);
      await _configuration.setShowEmptyChannels(_showEmptyChannels);
      await _configuration.setGroupMessages(_groupMessages);
      await _configuration.setImgbbApiKey(newImgbbApiKey);

      await _chatProvider.updateConfiguration(newNickname, newServerUrl);

      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<bool?> _confirmDiscardChanges() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
          'You have unsaved changes. What would you like to do?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final shouldShowNotificationsArea =
        kIsWeb || platform == TargetPlatform.macOS;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (!_isDirty) {
          Navigator.of(context).pop();
          return;
        }

        final result = await _confirmDiscardChanges();
        if (result != null && context.mounted) {
          if (result) {
            _saveAndPop();
          } else {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Configuration'),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 8.0),
          actions: [
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: 'Save',
              onPressed: _saveAndPop,
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _nicknameController,
                              decoration: const InputDecoration(
                                labelText: 'Nickname',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a nickname';
                                }
                                return null;
                              },
                              textInputAction: TextInputAction.next,
                            ),
                            const Gap(16.0),
                            TextFormField(
                              controller: _serverUrlController,
                              decoration: const InputDecoration(
                                labelText: 'Server URL',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.link),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a server URL';
                                }
                                if (!value.startsWith('ws://') &&
                                    !value.startsWith('wss://')) {
                                  return 'URL must start with ws:// or wss://';
                                }
                                return null;
                              },
                              textInputAction: TextInputAction.next,
                            ),
                            const Gap(16.0),
                            TextFormField(
                              controller: _imgbbApiKeyController,
                              decoration: InputDecoration(
                                labelText: 'ImgBB API Key',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.key),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.info_outline),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) {
                                        return AlertDialog(
                                          title: const Text('ImgBB API Key'),
                                          content: const Text(
                                            'Image uploading requires an ImgBB API key. '
                                            'You can get one for free at the ImgBB website. '
                                            'If you don\'t provide a key, image uploading will be disabled.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () {
                                                launchUrlString(
                                                  'https://api.imgbb.com/',
                                                );
                                              },
                                              child: const Text('Get API Key'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                              child: const Text('OK'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                  tooltip: 'Learn about ImgBB API key',
                                ),
                              ),
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (value) => _saveAndPop(),
                            ),
                            if (shouldShowNotificationsArea) ...[
                              const Gap(16.0),
                              _ConfigurationSection(
                                title: Text('Push Notifications'),
                                children: [
                                  SwitchListTile(
                                    title: const Text('Server Messages'),
                                    subtitle: const Text(
                                      'Receive generic notifications pushed by the server',
                                    ),
                                    value: _pushNotificationsEnabled,
                                    onChanged: (value) async {
                                      if (value) {
                                        final granted = await _chatProvider
                                            .requestPermissions();
                                        if (granted) {
                                          setState(() {
                                            _pushNotificationsEnabled = true;
                                          });
                                        } else if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Notification permissions disabled or denied.',
                                              ),
                                            ),
                                          );
                                        }
                                      } else {
                                        setState(() {
                                          _pushNotificationsEnabled = false;
                                        });
                                      }
                                    },
                                  ),
                                  const Divider(),
                                  SwitchListTile(
                                    title: const Text('Mentions (@nickname)'),
                                    subtitle: const Text(
                                      'Targeted notifications when someone tags you',
                                    ),
                                    value: _mentionNotificationsEnabled,
                                    onChanged: (value) async {
                                      if (value) {
                                        final granted = await _chatProvider
                                            .requestPermissions();
                                        if (granted) {
                                          setState(() {
                                            _mentionNotificationsEnabled = true;
                                          });
                                        } else if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Notification permissions disabled or denied.',
                                              ),
                                            ),
                                          );
                                        }
                                      } else {
                                        setState(() {
                                          _mentionNotificationsEnabled = false;
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                            const Gap(16.0),
                            _ConfigurationSection(
                              title: const Text('Messages appearance'),
                              children: [
                                _MessagePreview(
                                  showTimeSeconds: _showTimeSeconds,
                                  showImagePreviews: _showImagePreviews,
                                  showMarkdown: _showMarkdown,
                                  groupMessages: _groupMessages,
                                ),
                                const Divider(),
                                SwitchListTile(
                                  title: const Text('Show time seconds'),
                                  subtitle: const Text(
                                    'Show seconds in message timestamps',
                                  ),
                                  value: _showTimeSeconds,
                                  onChanged: (value) {
                                    setState(() {
                                      _showTimeSeconds = value;
                                    });
                                  },
                                ),
                                const Divider(),
                                SwitchListTile(
                                  title: const Text('In-line Image Previews'),
                                  subtitle: const Text(
                                    'Automatically render images from URLs',
                                  ),
                                  value: _showImagePreviews,
                                  onChanged: (value) {
                                    setState(() {
                                      _showImagePreviews = value;
                                    });
                                  },
                                ),
                                const Divider(),
                                SwitchListTile(
                                  title: const Text('Enable Markdown'),
                                  subtitle: const Text(
                                    'Support bold, italic, strike and code formatting',
                                  ),
                                  value: _showMarkdown,
                                  onChanged: (value) {
                                    setState(() {
                                      _showMarkdown = value;
                                    });
                                  },
                                ),
                                const Divider(),
                                SwitchListTile(
                                  title: const Text(
                                    'Group sequential messages',
                                  ),
                                  subtitle: const Text(
                                    'Join multiple messages from the same user at the same time',
                                  ),
                                  value: _groupMessages,
                                  onChanged: (value) {
                                    setState(() {
                                      _groupMessages = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                            const Gap(16.0),
                            _ConfigurationSection(
                              title: const Text('Channels'),
                              children: [
                                SwitchListTile(
                                  title: const Text('Show empty channels'),
                                  subtitle: const Text(
                                    'Include channels with no active users in the list',
                                  ),
                                  value: _showEmptyChannels,
                                  onChanged: (value) {
                                    setState(() {
                                      _showEmptyChannels = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                            const Gap(16.0),
                            _ConfigurationSection(
                              title: const Text('About'),
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.privacy_tip),
                                  title: const Text('Privacy Policy'),
                                  onTap: () {
                                    const PrivacyPolicyRoute().push(context);
                                  },
                                ),
                                const Divider(),
                                ListTile(
                                  leading: const Icon(Icons.description),
                                  title: const Text('Licenses'),
                                  onTap: () {
                                    const LicensesRoute().push(context);
                                  },
                                ),
                                const Divider(),
                                ListTile(
                                  leading: const Icon(Icons.info),
                                  title: const Text('Version'),
                                  trailing: Text(
                                    locator<PackageInfo>().version,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                            const Gap(16.0),
                            ElevatedButton(
                              onPressed: _saveAndPop,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16.0,
                                ),
                              ),
                              child: const Text(
                                'Save',
                                style: TextStyle(fontSize: 16.0),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

final class _ConfigurationSection extends StatelessWidget {
  const _ConfigurationSection({required this.title, required this.children});

  final Widget title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: DefaultTextStyle(
                style: const TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                ),
                child: title,
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

final class _MessagePreview extends StatelessWidget {
  const _MessagePreview({
    required this.showTimeSeconds,
    required this.showImagePreviews,
    required this.showMarkdown,
    required this.groupMessages,
  });

  final bool showTimeSeconds;
  final bool showImagePreviews;
  final bool showMarkdown;
  final bool groupMessages;

  @override
  Widget build(BuildContext context) {
    final messageGrouper = locator<MessageGrouper>();
    final messageTime = DateTime.now();
    final messages = [
      ChatMessage(
        from: 'User1',
        content: '**Markdown** is `cool`! _Italic_ and ~~strike~~ work too.',
        date: messageTime,
      ),
      ChatMessage(
        from: 'User1',
        content: 'Hey, @User2 ! What do you think about grouping message',
        date: messageTime,
      ),
      ChatMessage(
        from: 'User2',
        content:
            'Check this image, @User1 : https://picsum.photos/seed/lispinto/200',
        date: DateTime.now().add(const Duration(seconds: 14)),
      ),
    ];
    return ServiceLocatorScope(
      key: ValueKey((
        showTimeSeconds,
        showImagePreviews,
        showMarkdown,
        groupMessages,
      )),
      overrides: (locator) {
        locator.registerSingleton<UserConfiguration>(
          InMemoryUserConfiguration(
            showTimeSeconds: showTimeSeconds,
            showImagePreviews: showImagePreviews,
            showMarkdown: showMarkdown,
            groupMessages: groupMessages,
            nickname: 'User1',
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            for (final message
                in groupMessages ? messageGrouper.group(messages) : messages)
              MessageBubble(message: message, searchQuery: ''),
          ],
        ),
      ),
    );
  }
}
