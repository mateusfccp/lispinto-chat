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
import 'package:lispinto_chat/core/app_localizations.dart';

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
        appBar: AppBar(title: Text(AppLocalizations.of(context).configuration)),
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
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).nickname,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return AppLocalizations.of(
                            context,
                          ).pleaseEnterNickname;
                        }
                        return null;
                      },
                      textInputAction: TextInputAction.next,
                    ),
                    const Gap(16.0),
                    TextFormField(
                      controller: _serverUrlController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).serverUrl,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.link),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return AppLocalizations.of(
                            context,
                          ).pleaseEnterServerUrl;
                        }
                        if (!value.startsWith(httpUrlPattern)) {
                          return AppLocalizations.of(context).urlMustStart;
                        }
                        return null;
                      },
                      textInputAction: TextInputAction.next,
                    ),
                    const Gap(16.0),
                    TextFormField(
                      controller: _imgbbApiKeyController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).imgbbApiKey,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.key),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.info_outline),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: Text(
                                    AppLocalizations.of(context).imgbbApiKey,
                                  ),
                                  content: Text(
                                    AppLocalizations.of(
                                      context,
                                    ).imgbbApiKeyDescription,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        launchUrlString(
                                          'https://api.imgbb.com/',
                                        );
                                      },
                                      child: Text(
                                        AppLocalizations.of(context).getApiKey,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                      child: Text(
                                        AppLocalizations.of(context).ok,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          tooltip: AppLocalizations.of(context).learnAboutImgbb,
                        ),
                      ),
                    ),
                    if (shouldShowNotificationsArea) ...[
                      const Gap(16.0),
                      _ConfigurationSection(
                        title: Text(
                          AppLocalizations.of(context).pushNotifications,
                        ),
                        children: [
                          SwitchListTile(
                            title: Text(
                              AppLocalizations.of(context).serverMessages,
                            ),
                            subtitle: Text(
                              AppLocalizations.of(
                                context,
                              ).serverMessagesDescription,
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
                                    SnackBar(
                                      content: Text(
                                        AppLocalizations.of(
                                          context,
                                        ).notificationPermissionsDisabled,
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
                            title: Text(AppLocalizations.of(context).mentions),
                            subtitle: Text(
                              AppLocalizations.of(context).mentionsDescription,
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
                                    SnackBar(
                                      content: Text(
                                        AppLocalizations.of(
                                          context,
                                        ).notificationPermissionsDisabled,
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
                      title: Text(
                        AppLocalizations.of(context).messagesAppearance,
                      ),
                      children: [
                        _MessagePreview(configuration: _newConfiguration),
                        const Divider(),
                        SwitchListTile(
                          title: Text(
                            AppLocalizations.of(context).showTimeSeconds,
                          ),
                          subtitle: Text(
                            AppLocalizations.of(
                              context,
                            ).showTimeSecondsDescription,
                          ),
                          value: _newConfiguration.showTimeSeconds,
                          onChanged: (value) {
                            _newConfiguration.showTimeSeconds = value;
                          },
                        ),
                        const Divider(),
                        SwitchListTile(
                          title: Text(
                            AppLocalizations.of(context).inlineImagePreviews,
                          ),
                          subtitle: Text(
                            AppLocalizations.of(
                              context,
                            ).inlineImagePreviewsDescription,
                          ),
                          value: _newConfiguration.showImagePreviews,
                          onChanged: (value) {
                            _newConfiguration.showImagePreviews = value;
                          },
                        ),
                        const Divider(),
                        SwitchListTile(
                          title: Text(
                            AppLocalizations.of(context).enableMarkdown,
                          ),
                          subtitle: Text(
                            AppLocalizations.of(
                              context,
                            ).enableMarkdownDescription,
                          ),
                          value: _newConfiguration.showMarkdown,
                          onChanged: (value) {
                            _newConfiguration.showMarkdown = value;
                          },
                        ),
                        const Divider(),
                        SwitchListTile(
                          title: Text(
                            AppLocalizations.of(
                              context,
                            ).groupSequentialMessages,
                          ),
                          subtitle: Text(
                            AppLocalizations.of(
                              context,
                            ).groupSequentialMessagesDescription,
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
                      title: Text(AppLocalizations.of(context).channels),
                      children: [
                        SwitchListTile(
                          title: Text(
                            AppLocalizations.of(context).showEmptyChannels,
                          ),
                          subtitle: Text(
                            AppLocalizations.of(
                              context,
                            ).showEmptyChannelsDescription,
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
                      title: Text(AppLocalizations.of(context).about),
                      children: [
                        ListTile(
                          leading: const Icon(Icons.privacy_tip),
                          title: Text(
                            AppLocalizations.of(context).privacyPolicy,
                          ),
                          onTap: () {
                            const PrivacyPolicyRoute().push(context);
                          },
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.description),
                          title: Text(AppLocalizations.of(context).licenses),
                          onTap: () {
                            const LicensesRoute().push(context);
                          },
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.info),
                          title: Text(
                            AppLocalizations.of(
                              context,
                            ).version(locator<PackageInfo>().version),
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
