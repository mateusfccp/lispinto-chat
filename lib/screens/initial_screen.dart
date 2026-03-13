import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lispinto_chat/core/app_localizations.dart';
import 'package:lispinto_chat/core/constants.dart';
import 'package:lispinto_chat/core/in_memory_user_configuration.dart';
import 'package:lispinto_chat/core/router.dart';
import 'package:lispinto_chat/core/service_locator.dart';
import 'package:lispinto_chat/core/user_configuration.dart';
import 'package:lispinto_chat/providers/chat_provider.dart';
import 'package:lispinto_chat/services/chat_service.dart';
import 'package:lispinto_chat/widgets/scrollable_screen.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The initial screen shown when the app starts.
final class InitialScreen extends StatefulWidget {
  /// Creates an [InitialScreen].
  const InitialScreen({super.key});

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

final class _InitialScreenState extends State<InitialScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nicknameController;
  late final TextEditingController _serverUrlController;
  late final UserConfiguration _configuration;
  late final ChatProvider _chatProvider;
  late final Logger _logger;

  bool get _isConnecting =>
      _chatProvider.connectionState == ChatConnectionState.connecting;

  @override
  void initState() {
    super.initState();
    _configuration = locator<UserConfiguration>();
    _chatProvider = locator<ChatProvider>();
    _logger = locator<Logger>();

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
      _logger.info('Initiating explicit connection from InitialScreen...');
      await _chatProvider.connect();

      _configuration.autoConnect = true;

      if (mounted) {
        if (!_chatProvider.isConnected) {
          _logger.warning(
            'Failed to connect: Provider not connected after explicitly awaiting connection.',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).failedToConnect),
            ),
          );
        }
      }
    } catch (exception, stackTrace) {
      _logger.severe(
        'Explicit connection error: $exception',
        exception,
        stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              ).connectionError(exception.toString()),
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleConnectPressed() async {
    if (_formKey.currentState?.validate() ?? false) {
      final newNickname = _nicknameController.text.trim();
      final newServerUrl = _serverUrlController.text.trim();

      final newConfiguration = InMemoryUserConfiguration.fromConfiguration(
        _chatProvider.configuration,
      );
      newConfiguration.nickname = newNickname;
      newConfiguration.serverUrl = newServerUrl;

      await _chatProvider.updateConfiguration(newConfiguration);

      _connectAndNavigate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: _chatProvider,
        builder: (context, child) {
          return ScrollableScreen(
            maxWidth: 400.0,
            mainChild: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    enabled: !_isConnecting,
                    controller: _nicknameController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).nickname,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return AppLocalizations.of(context).pleaseEnterNickname;
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const Gap(16.0),
                  TextFormField(
                    enabled: !_isConnecting,
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
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (value) => _handleConnectPressed(),
                  ),
                  const Gap(32.0),
                  ElevatedButton(
                    onPressed: _isConnecting ? null : _handleConnectPressed,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                    ),
                    child: _isConnecting
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 20.0,
                                height: 20.0,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                ),
                              ),
                              const Gap(12.0),
                              Text(
                                AppLocalizations.of(context).connecting,
                                style: const TextStyle(fontSize: 16.0),
                              ),
                            ],
                          )
                        : Text(
                            AppLocalizations.of(context).connect,
                            style: const TextStyle(fontSize: 16.0),
                          ),
                  ),
                ],
              ),
            ),
            bottomChild: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      const InitialPrivacyPolicyRoute().go(context);
                    },
                    icon: const Icon(Icons.privacy_tip_outlined),
                    label: Text(AppLocalizations.of(context).privacyPolicy),
                  ),
                ),
                const Gap(4.0),
                Center(
                  child: Text(
                    AppLocalizations.of(
                      context,
                    ).version(locator<PackageInfo>().version),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
