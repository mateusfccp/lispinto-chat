import '../models/channel_name.dart';
import '../models/username.dart';
import 'user_configuration.dart';

/// In-memory implementation of [UserConfiguration] for preview and testing.
final class InMemoryUserConfiguration extends UserConfiguration {
  /// Creates an [InMemoryUserConfiguration] with optional initial values.
  InMemoryUserConfiguration({
    String nickname = '',
    this._serverUrl = 'https://chat.manoel.dev',
    this._pushNotificationsEnabled = false,
    this._mentionNotificationsEnabled = false,
    this._autoConnect = false,
    this._showTimeSeconds = false,
    this._showImagePreviews = true,
    this._showLinkPreviews = true,
    this._showEmptyChannels = false,
    this._showMarkdown = true,
    this._groupMessages = true,
    this._lastChannel = const ChannelName.general(),
    this._imgbbApiKey = '',
  }) : _nickname = UserName.normalize(nickname);

  /// Creates an [InMemoryUserConfiguration] from another [UserConfiguration].
  InMemoryUserConfiguration.fromConfiguration(UserConfiguration config)
    : _nickname = UserName.normalize(config.nickname),
      _serverUrl = config.serverUrl,
      _pushNotificationsEnabled = config.pushNotificationsEnabled,
      _mentionNotificationsEnabled = config.mentionNotificationsEnabled,
      _autoConnect = config.autoConnect,
      _showTimeSeconds = config.showTimeSeconds,
      _showImagePreviews = config.showImagePreviews,
      _showLinkPreviews = config.showLinkPreviews,
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
  bool _showLinkPreviews;
  bool _showEmptyChannels;
  bool _showMarkdown;
  bool _groupMessages;
  ChannelName _lastChannel;
  String _imgbbApiKey;

  @override
  String get nickname => _nickname;

  @override
  set nickname(String value) {
    _nickname = UserName.normalize(value);
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
  bool get showLinkPreviews => _showLinkPreviews;

  @override
  set showLinkPreviews(bool value) {
    _showLinkPreviews = value;
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
  ChannelName get lastChannel => _lastChannel;

  @override
  set lastChannel(ChannelName value) {
    _lastChannel = value;
    notifyListeners();
  }

  @override
  void updateWith(UserConfiguration other) {
    _nickname = UserName.normalize(other.nickname);
    _serverUrl = other.serverUrl;
    _imgbbApiKey = other.imgbbApiKey;
    _pushNotificationsEnabled = other.pushNotificationsEnabled;
    _mentionNotificationsEnabled = other.mentionNotificationsEnabled;
    _autoConnect = other.autoConnect;
    _showTimeSeconds = other.showTimeSeconds;
    _showImagePreviews = other.showImagePreviews;
    _showLinkPreviews = other.showLinkPreviews;
    _showEmptyChannels = other.showEmptyChannels;
    _showMarkdown = other.showMarkdown;
    _groupMessages = other.groupMessages;
    _lastChannel = other.lastChannel;
    notifyListeners();
  }
}
