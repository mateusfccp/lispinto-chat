import 'user_configuration.dart';

/// In-memory implementation of [UserConfiguration] for preview and testing.
final class InMemoryUserConfiguration implements UserConfiguration {
  /// Creates an [InMemoryUserConfiguration] with optional initial values.
  InMemoryUserConfiguration({
    String nickname = '',
    String serverUrl = 'wss://chat.manoel.dev/ws',
    bool pushNotificationsEnabled = false,
    bool mentionNotificationsEnabled = false,
    bool autoConnect = false,
    bool showTimeSeconds = false,
    bool showImagePreviews = true,
    bool showEmptyChannels = false,
    bool showMarkdown = true,
    bool groupMessages = true,
    String lastChannel = '#general',
    String imgbbApiKey = '',
  }) : _nickname = nickname,
       _serverUrl = serverUrl,
       _pushNotificationsEnabled = pushNotificationsEnabled,
       _mentionNotificationsEnabled = mentionNotificationsEnabled,
       _autoConnect = autoConnect,
       _showTimeSeconds = showTimeSeconds,
       _showImagePreviews = showImagePreviews,
       _showEmptyChannels = showEmptyChannels,
       _showMarkdown = showMarkdown,
       _groupMessages = groupMessages,
       _lastChannel = lastChannel,
       _imgbbApiKey = imgbbApiKey;

  String _nickname;
  String _serverUrl;
  bool _pushNotificationsEnabled;
  bool _mentionNotificationsEnabled;
  bool _autoConnect;
  bool _showTimeSeconds;
  bool _showImagePreviews;
  bool _showEmptyChannels;
  bool _showMarkdown;
  bool _groupMessages;
  String _lastChannel;
  String _imgbbApiKey;

  @override
  String get nickname => _nickname;

  @override
  Future<void> setNickname(String value) async => _nickname = value;

  @override
  String get serverUrl => _serverUrl;

  @override
  Future<void> setServerUrl(String value) async => _serverUrl = value;

  @override
  String get imgbbApiKey => _imgbbApiKey;

  @override
  Future<void> setImgbbApiKey(String value) async => _imgbbApiKey = value;

  @override
  bool get hasNickname => _nickname.trim().isNotEmpty;

  @override
  bool get pushNotificationsEnabled => _pushNotificationsEnabled;

  @override
  Future<void> setPushNotificationsEnabled(bool value) async =>
      _pushNotificationsEnabled = value;

  @override
  bool get mentionNotificationsEnabled => _mentionNotificationsEnabled;

  @override
  Future<void> setMentionNotificationsEnabled(bool value) async =>
      _mentionNotificationsEnabled = value;

  @override
  bool get autoConnect => _autoConnect;

  @override
  Future<void> setAutoConnect(bool value) async => _autoConnect = value;

  @override
  bool get showTimeSeconds => _showTimeSeconds;

  @override
  Future<void> setShowTimeSeconds(bool value) async => _showTimeSeconds = value;

  @override
  bool get showImagePreviews => _showImagePreviews;

  @override
  Future<void> setShowImagePreviews(bool value) async =>
      _showImagePreviews = value;

  @override
  bool get showEmptyChannels => _showEmptyChannels;

  @override
  Future<void> setShowEmptyChannels(bool value) async =>
      _showEmptyChannels = value;

  @override
  bool get showMarkdown => _showMarkdown;

  @override
  Future<void> setShowMarkdown(bool value) async => _showMarkdown = value;

  @override
  bool get groupMessages => _groupMessages;

  @override
  Future<void> setGroupMessages(bool value) async => _groupMessages = value;

  @override
  String get lastChannel => _lastChannel;

  @override
  Future<void> setLastChannel(String value) async => _lastChannel = value;
}
