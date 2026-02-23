import 'package:flutter/material.dart';
import 'package:lispinto_chat/core/user_configuration.dart';
import 'package:lispinto_chat/providers/chat_provider.dart';
import 'chat_screen.dart';

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
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    if (_formKey.currentState?.validate() ?? false) {
      final newNickname = _nicknameController.text.trim();
      final newServerUrl = _serverUrlController.text.trim();

      await widget.chatProvider.updateConfiguration(newNickname, newServerUrl);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ChatScreen(provider: widget.chatProvider),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuration')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    size: 64.0,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 32.0),
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
                    onFieldSubmitted: (value) => _saveAndContinue(),
                  ),
                  const SizedBox(height: 32.0),
                  ElevatedButton(
                    onPressed: _saveAndContinue,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                    ),
                    child: const Text(
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
    );
  }
}
