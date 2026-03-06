import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lispinto_chat/core/router.dart';
import 'package:lispinto_chat/core/service_locator.dart';
import 'package:lispinto_chat/core/user_configuration.dart';
import 'package:lispinto_chat/providers/chat_provider.dart';
import 'package:lispinto_chat/services/chat_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The initial screen shown when the app starts.
final class InitialScreen extends StatefulWidget {
  /// Creates an [InitialScreen].
  const InitialScreen({super.key});

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

final class _InitialScreenState extends State<InitialScreen> {
  late final TextEditingController _nicknameController;
  late final TextEditingController _serverUrlController;
  final _formKey = GlobalKey<FormState>();

  bool get _isConnecting =>
      _chatProvider.connectionState == ChatConnectionState.connecting;

  late final UserConfiguration _configuration;
  late final ChatProvider _chatProvider;

  @override
  void initState() {
    super.initState();
    _configuration = locator<UserConfiguration>();
    _chatProvider = locator<ChatProvider>();

    _nicknameController = TextEditingController(text: _configuration.nickname);
    _serverUrlController = TextEditingController(
      text: _configuration.serverUrl,
    );
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _connectAndNavigate() async {
    try {
      // Connect explicitly now. This will wait for full login.
      await _chatProvider.connect();

      if (mounted) {
        if (!_chatProvider.isConnected) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to connect. Please check your settings.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection error: ${e.toString()}'),
          ),
        );
      }
    }
  }

  Future<void> _handleConnectPressed() async {
    if (_formKey.currentState?.validate() ?? false) {
      final newNickname = _nicknameController.text.trim();
      final newServerUrl = _serverUrlController.text.trim();

      await _configuration.setAutoConnect(true);
      await _chatProvider.updateConfiguration(newNickname, newServerUrl);

      _connectAndNavigate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: _chatProvider,
        builder: (context, child) {
          return LayoutBuilder(
            builder: (context, constraints) {
              return CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400.0),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Spacer(),
                                TextFormField(
                                  enabled: !_isConnecting,
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
                                  enabled: !_isConnecting,
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
                                  onFieldSubmitted: (value) =>
                                      _handleConnectPressed(),
                                ),
                                const Gap(32.0),
                                ElevatedButton(
                                  onPressed: _isConnecting
                                      ? null
                                      : _handleConnectPressed,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16.0,
                                    ),
                                  ),
                                  child: _isConnecting
                                      ? Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const SizedBox(
                                              width: 20.0,
                                              height: 20.0,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.0,
                                              ),
                                            ),
                                            const Gap(12.0),
                                            const Text(
                                              'Connecting',
                                              style: TextStyle(fontSize: 16.0),
                                            ),
                                          ],
                                        )
                                      : const Text(
                                          'Connect',
                                          style: TextStyle(fontSize: 16.0),
                                        ),
                                ),
                                const Spacer(),
                                const Gap(16.0),
                                Center(
                                  child: TextButton.icon(
                                    onPressed: () {
                                      const InitialPrivacyPolicyRoute().go(context);
                                    },
                                    icon: const Icon(Icons.privacy_tip_outlined),
                                    label: const Text('Privacy Policy'),
                                  ),
                                ),
                                const Gap(4.0),
                                Center(
                                  child: Text(
                                    'Version ${locator<PackageInfo>().version}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: Colors.grey),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
