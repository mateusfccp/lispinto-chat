import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lispinto_chat/core/constants.dart';
import 'package:lispinto_chat/core/in_memory_user_configuration.dart';
import 'package:lispinto_chat/core/message_grouper.dart';
import 'package:lispinto_chat/core/router.dart';
import 'package:lispinto_chat/core/service_locator.dart';
import 'package:lispinto_chat/core/user_configuration.dart';
import 'package:lispinto_chat/models/chat_message.dart';
import 'package:lispinto_chat/providers/chat_provider.dart';
import 'package:lispinto_chat/widgets/message_bubble.dart';
import 'package:lispinto_chat/widgets/scrollable_screen.dart';
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
  late final UserConfiguration _newConfiguration;
  late final ChatProvider _chatProvider;
  late final TextEditingController _nicknameController;
  late final TextEditingController _serverUrlController;
  late final TextEditingController _imgbbApiKeyController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _configuration = locator<UserConfiguration>();
    _newConfiguration = InMemoryUserConfiguration.fromConfiguration(
      _configuration,
    );
    _chatProvider = locator<ChatProvider>();
    _nicknameController = TextEditingController(text: _configuration.nickname);
    _nicknameController.addListener(() {
      _newConfiguration.nickname = _nicknameController.text;
    });
    _serverUrlController = TextEditingController(
      text: _configuration.serverUrl,
    );
    _serverUrlController.addListener(() {
      _newConfiguration.serverUrl = _serverUrlController.text;
    });
    _imgbbApiKeyController = TextEditingController(
      text: _configuration.imgbbApiKey,
    );
    _imgbbApiKeyController.addListener(() {
      _newConfiguration.imgbbApiKey = _imgbbApiKeyController.text;
    });
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _serverUrlController.dispose();
    _imgbbApiKeyController.dispose();
    super.dispose();
  }

  bool get _isDirty {
    return _newConfiguration.nickname != _configuration.nickname ||
        _newConfiguration.serverUrl != _configuration.serverUrl ||
        _newConfiguration.imgbbApiKey != _configuration.imgbbApiKey ||
        _newConfiguration.pushNotificationsEnabled !=
            _configuration.pushNotificationsEnabled ||
        _newConfiguration.mentionNotificationsEnabled !=
            _configuration.mentionNotificationsEnabled ||
        _newConfiguration.showTimeSeconds != _configuration.showTimeSeconds ||
        _newConfiguration.showImagePreviews !=
            _configuration.showImagePreviews ||
        _newConfiguration.showMarkdown != _configuration.showMarkdown ||
        _newConfiguration.showEmptyChannels !=
            _configuration.showEmptyChannels ||
        _newConfiguration.groupMessages != _configuration.groupMessages;
  }

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final shouldShowNotificationsArea =
        kIsWeb || platform == TargetPlatform.macOS;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, value) {
        if (didPop) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_isDirty) {
              _chatProvider.updateConfiguration(_newConfiguration);
            }
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Configuration')),
        body: ScrollableScreen(
          maxWidth: 600.0,
          mainChild: Form(
            key: _formKey,
            child: ListenableBuilder(
              listenable: _newConfiguration,
              builder: (context, child) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
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
                        if (!value.startsWith(httpUrlPattern)) {
                          return 'URL must start with http:// or httpss://';
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
                            value: _newConfiguration.pushNotificationsEnabled,
                            onChanged: (value) async {
                              if (value) {
                                final granted = await _chatProvider
                                    .requestPermissions();
                                if (granted) {
                                  _newConfiguration.pushNotificationsEnabled =
                                      true;
                                } else if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Notification permissions disabled or denied.',
                                      ),
                                    ),
                                  );
                                }
                              } else {
                                _newConfiguration.pushNotificationsEnabled =
                                    false;
                              }
                            },
                          ),
                          const Divider(),
                          SwitchListTile(
                            title: const Text('Mentions (@nickname)'),
                            subtitle: const Text(
                              'Targeted notifications when someone tags you',
                            ),
                            value:
                                _newConfiguration.mentionNotificationsEnabled,
                            onChanged: (value) async {
                              if (value) {
                                final granted = await _chatProvider
                                    .requestPermissions();
                                if (granted) {
                                  _newConfiguration
                                          .mentionNotificationsEnabled =
                                      true;
                                } else if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Notification permissions disabled or denied.',
                                      ),
                                    ),
                                  );
                                }
                              } else {
                                _newConfiguration.mentionNotificationsEnabled =
                                    false;
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
                        _MessagePreview(configuration: _newConfiguration),
                        const Divider(),
                        SwitchListTile(
                          title: const Text('Show time seconds'),
                          subtitle: const Text(
                            'Show seconds in message timestamps',
                          ),
                          value: _newConfiguration.showTimeSeconds,
                          onChanged: (value) {
                            _newConfiguration.showTimeSeconds = value;
                          },
                        ),
                        const Divider(),
                        SwitchListTile(
                          title: const Text('In-line Image Previews'),
                          subtitle: const Text(
                            'Automatically render images from URLs',
                          ),
                          value: _newConfiguration.showImagePreviews,
                          onChanged: (value) {
                            _newConfiguration.showImagePreviews = value;
                          },
                        ),
                        const Divider(),
                        SwitchListTile(
                          title: const Text('Enable Markdown'),
                          subtitle: const Text(
                            'Support bold, italic, strike and code formatting',
                          ),
                          value: _newConfiguration.showMarkdown,
                          onChanged: (value) {
                            _newConfiguration.showMarkdown = value;
                          },
                        ),
                        const Divider(),
                        SwitchListTile(
                          title: const Text('Group sequential messages'),
                          subtitle: const Text(
                            'Join multiple messages from the same user at the same time',
                          ),
                          value: _newConfiguration.groupMessages,
                          onChanged: (value) {
                            _newConfiguration.groupMessages = value;
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
                          value: _newConfiguration.showEmptyChannels,
                          onChanged: (value) {
                            _newConfiguration.showEmptyChannels = value;
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
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
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
  const _MessagePreview({required this.configuration});

  final UserConfiguration configuration;

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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          for (final message
              in configuration.groupMessages
                  ? messageGrouper.group(messages)
                  : messages)
            MessageBubble(
              message: message,
              searchQuery: '',
              configuration: configuration,
            ),
        ],
      ),
    );
  }
}
