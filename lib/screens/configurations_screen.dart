import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lispinto_chat/core/user_configuration.dart';
import 'package:lispinto_chat/providers/chat_provider.dart';

/// A screen that allows the user to configure their settings.
final class ConfigurationsScreen extends StatefulWidget {
  /// Creates a [ConfigurationsScreen].
  const ConfigurationsScreen({
    super.key,
    required this.configuration,
    required this.chatProvider,
  });

  /// The user configuration to edit.
  final UserConfiguration configuration;

  /// The chat provider to use for connecting after saving the configuration.
  final ChatProvider chatProvider;

  @override
  State<ConfigurationsScreen> createState() => _ConfigurationsScreenState();
}

final class _ConfigurationsScreenState extends State<ConfigurationsScreen> {
  late final TextEditingController _nicknameController;
  late final TextEditingController _serverUrlController;
  late bool _pushNotificationsEnabled;
  late bool _mentionNotificationsEnabled;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(
      text: widget.configuration.nickname,
    );
    _serverUrlController = TextEditingController(
      text: widget.configuration.serverUrl,
    );
    _pushNotificationsEnabled = widget.configuration.pushNotificationsEnabled;
    _mentionNotificationsEnabled =
        widget.configuration.mentionNotificationsEnabled;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveAndPop() async {
    if (_formKey.currentState?.validate() ?? false) {
      final newNickname = _nicknameController.text.trim();
      final newServerUrl = _serverUrlController.text.trim();

      await widget.configuration.setPushNotificationsEnabled(
        _pushNotificationsEnabled,
      );
      await widget.configuration.setMentionNotificationsEnabled(
        _mentionNotificationsEnabled,
      );
      await widget.chatProvider.updateConfiguration(newNickname, newServerUrl);

      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final shouldShowNotificationsArea =
        kIsWeb || platform == TargetPlatform.macOS;

    return Scaffold(
      appBar: AppBar(title: const Text('Configuration')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400.0),
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
                          const SizedBox(height: 16),
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
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (value) => _saveAndPop(),
                          ),
                          if (shouldShowNotificationsArea) ...[
                            const SizedBox(height: 16.0),
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16.0,
                                        vertical: 8.0,
                                      ),
                                      child: Text(
                                        'Push Notifications',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    SwitchListTile(
                                      title: const Text('Server Messages'),
                                      subtitle: const Text(
                                        'Receive generic notifications pushed by the server',
                                      ),
                                      value: _pushNotificationsEnabled,
                                      onChanged: (value) async {
                                        if (value) {
                                          final granted = await widget
                                              .chatProvider
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
                                          final granted = await widget
                                              .chatProvider
                                              .requestPermissions();
                                          if (granted) {
                                            setState(() {
                                              _mentionNotificationsEnabled =
                                                  true;
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
                                            _mentionNotificationsEnabled =
                                                false;
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 32.0),
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
    );
  }
}
