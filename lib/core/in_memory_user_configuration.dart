import 'user_configuration.dart';

/// In-memory implementation of [UserConfiguration] for preview and testing.
final class InMemoryUserConfiguration extends UserConfiguration {
  /// Creates an [InMemoryUserConfiguration] with optional initial values.
  InMemoryUserConfiguration({
    String nickname = '',
    String serverUrl = 'https://chat.manoel.dev',
    bool pushNotificationsEnabled = false,
    bool mentionNotificationsEnabled = false,
    bool autoConnect = false,
    bool showTimeSeconds = false,
    bool showImagePreviews = true,
    bool showEmptyChannels = false,
    bool showMarkdown = true,
    bool groupMessages = true,
    String lastChannel = 'general',
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

  /// Creates an [InMemoryUserConfiguration] from another [UserConfiguration].
  InMemoryUserConfiguration.fromConfiguration(UserConfiguration config)
    : _nickname = config.nickname,
      _serverUrl = config.serverUrl,
      _pushNotificationsEnabled = config.pushNotificationsEnabled,
      _mentionNotificationsEnabled = config.mentionNotificationsEnabled,
      _autoConnect = config.autoConnect,
      _showTimeSeconds = config.showTimeSeconds,
      _showImagePreviews = config.showImagePreviews,
      _showEmptyChannels = config.showEmptyChannels,
      _showMarkdown = config.showMarkdown,
      _groupMessages = config.groupMessages,
      _lastChannel = config.lastChannel,
      _imgbbApiKey = config.imgbbApiKey;

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
  set nickname(String value) {
    _nickname = value;
    notifyListeners();
  }

  @override
  String get serverUrl => _serverUrl;

  @override
  set serverUrl(String value) {
    _serverUrl = value;
    notifyListeners();
  }

  @override
  String get imgbbApiKey => _imgbbApiKey;

  @override
  set imgbbApiKey(String value) {
    _imgbbApiKey = value;
    notifyListeners();
  }

  @override
  bool get hasNickname => _nickname.trim().isNotEmpty;

  @override
  bool get pushNotificationsEnabled => _pushNotificationsEnabled;

  @override
  set pushNotificationsEnabled(bool value) {
    _pushNotificationsEnabled = value;
    notifyListeners();
  }

  @override
  bool get mentionNotificationsEnabled => _mentionNotificationsEnabled;

  @override
  set mentionNotificationsEnabled(bool value) {
    _mentionNotificationsEnabled = value;
    notifyListeners();
  }

  @override
  bool get autoConnect => _autoConnect;

  @override
  set autoConnect(bool value) {
    _autoConnect = value;
    notifyListeners();
  }

  @override
  bool get showTimeSeconds => _showTimeSeconds;

  @override
  set showTimeSeconds(bool value) {
    _showTimeSeconds = value;
    notifyListeners();
  }

  @override
  bool get showImagePreviews => _showImagePreviews;

  @override
  set showImagePreviews(bool value) {
    _showImagePreviews = value;
    notifyListeners();
  }

  @override
  bool get showEmptyChannels => _showEmptyChannels;

  @override
  set showEmptyChannels(bool value) {
    _showEmptyChannels = value;
    notifyListeners();
  }

  @override
  bool get showMarkdown => _showMarkdown;

  @override
  set showMarkdown(bool value) {
    _showMarkdown = value;
    notifyListeners();
  }

  @override
  bool get groupMessages => _groupMessages;

  @override
  set groupMessages(bool value) {
    _groupMessages = value;
    notifyListeners();
  }

  @override
  String get lastChannel => _lastChannel;

  @override
  set lastChannel(String value) {
    _lastChannel = value;
    notifyListeners();
  }

  @override
  void updateWith(UserConfiguration other) {
    _nickname = other.nickname;
    _serverUrl = other.serverUrl;
    _imgbbApiKey = other.imgbbApiKey;
    _pushNotificationsEnabled = other.pushNotificationsEnabled;
    _mentionNotificationsEnabled = other.mentionNotificationsEnabled;
    _autoConnect = other.autoConnect;
    _showTimeSeconds = other.showTimeSeconds;
    _showImagePreviews = other.showImagePreviews;
    _showEmptyChannels = other.showEmptyChannels;
    _showMarkdown = other.showMarkdown;
    _groupMessages = other.groupMessages;
    _lastChannel = other.lastChannel;
    notifyListeners();
  }
}
