import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lispinto_chat/core/router.dart';
import 'package:lispinto_chat/core/service_locator.dart';
import 'package:lispinto_chat/core/user_configuration.dart';
import 'package:lispinto_chat/providers/chat_provider.dart';

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
  bool _isConnecting = false;

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
    setState(() => _isConnecting = true);

    // Connect explicitly now
    _chatProvider.connect();

    if (mounted) {
      setState(() => _isConnecting = false);
      const ChatRoute().go(context);
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
                                ? const CircularProgressIndicator()
                                : const Text(
                                    'Connect',
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
