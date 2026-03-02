import 'package:shared_preferences/shared_preferences.dart';

/// Manages user configuration such as nickname and server URL.
abstract interface class UserConfiguration {
  /// Gets the nickname from shared preferences.
  String get nickname;

  /// Saves the nickname to shared preferences.
  Future<void> setNickname(String value);

  /// Gets the server URL from shared preferences.
  String get serverUrl;

  /// Saves the server URL to shared preferences.
  Future<void> setServerUrl(String value);

  /// Returns true if the user has set a non-empty nickname.
  bool get hasNickname;

  /// Whether push notifications are enabled.
  bool get pushNotificationsEnabled;

  /// Saves the push notifications preference.
  Future<void> setPushNotificationsEnabled(bool value);

  /// Whether mention notifications are enabled.
  bool get mentionNotificationsEnabled;

  /// Saves the mention notifications preference.
  Future<void> setMentionNotificationsEnabled(bool value);

  /// Whether the user wants to automatically skip the initial screen on startup.
  bool get autoConnect;

  /// Saves the auto-connect preference.
  Future<void> setAutoConnect(bool value);

  /// Whether to show seconds in message timestamps.
  bool get showTimeSeconds;

  /// Saves the show-time-seconds preference.
  Future<void> setShowTimeSeconds(bool value);

  /// Whether to show image previews for URLs.
  bool get showImagePreviews;

  /// Saves the show-image-previews preference.
  Future<void> setShowImagePreviews(bool value);

  /// Whether to show empty channels in the channel list.
  bool get showEmptyChannels;

  /// Saves the show-empty-channels preference.
  Future<void> setShowEmptyChannels(bool value);

  /// Gets the last joined channel.
  String get lastChannel;

  /// Saves the last joined channel.
  Future<void> setLastChannel(String value);

  /// Loads the persistent user configuration.
  static Future<UserConfiguration> load() => PersistentUserConfiguration.load();
}

/// Persistent implementation of [UserConfiguration] using [SharedPreferences].
final class PersistentUserConfiguration implements UserConfiguration {
  /// Creates a [PersistentUserConfiguration].
  const PersistentUserConfiguration({required SharedPreferences preferences})
    : _preferences = preferences;

  static const String _keyNickname = 'nickname';
  static const String _keyServerUrl = 'server_url';
  static const String _keyPushNotifications = 'push_notifications';
  static const String _keyMentionNotifications = 'mention_notifications';
  static const String _keyAutoConnect = 'auto_connect';
  static const String _keyShowTimeSeconds = 'show_time_seconds';
  static const String _keyShowImagePreviews = 'show_image_previews';
  static const String _keyShowEmptyChannels = 'show_empty_channels';
  static const String _keyLastChannel = 'last_channel';
  static const String _defaultServerUrl = 'wss://chat.manoel.dev/ws';

  final SharedPreferences _preferences;

  /// Loads the user configuration from shared preferences.
  static Future<PersistentUserConfiguration> load() async {
    final preferences = await SharedPreferences.getInstance();
    return PersistentUserConfiguration(preferences: preferences);
  }

  @override
  String get nickname => _preferences.getString(_keyNickname) ?? '';

  @override
  Future<void> setNickname(String value) async {
    await _preferences.setString(_keyNickname, value);
  }

  @override
  String get serverUrl {
    return _preferences.getString(_keyServerUrl) ?? _defaultServerUrl;
  }

  @override
  Future<void> setServerUrl(String value) async {
    await _preferences.setString(_keyServerUrl, value);
  }

  @override
  bool get hasNickname => nickname.trim().isNotEmpty;

  @override
  bool get pushNotificationsEnabled {
    return _preferences.getBool(_keyPushNotifications) ?? false;
  }

  @override
  Future<void> setPushNotificationsEnabled(bool value) async {
    await _preferences.setBool(_keyPushNotifications, value);
  }

  @override
  bool get mentionNotificationsEnabled {
    return _preferences.getBool(_keyMentionNotifications) ?? false;
  }

  @override
  Future<void> setMentionNotificationsEnabled(bool value) async {
    await _preferences.setBool(_keyMentionNotifications, value);
  }

  @override
  bool get autoConnect {
    return _preferences.getBool(_keyAutoConnect) ?? false;
  }

  @override
  Future<void> setAutoConnect(bool value) async {
    await _preferences.setBool(_keyAutoConnect, value);
  }

  @override
  bool get showTimeSeconds {
    return _preferences.getBool(_keyShowTimeSeconds) ?? false;
  }

  @override
  Future<void> setShowTimeSeconds(bool value) async {
    await _preferences.setBool(_keyShowTimeSeconds, value);
  }

  @override
  bool get showImagePreviews {
    return _preferences.getBool(_keyShowImagePreviews) ?? true;
  }

  @override
  Future<void> setShowImagePreviews(bool value) async {
    await _preferences.setBool(_keyShowImagePreviews, value);
  }

  @override
  bool get showEmptyChannels {
    return _preferences.getBool(_keyShowEmptyChannels) ?? false;
  }

  @override
  Future<void> setShowEmptyChannels(bool value) async {
    await _preferences.setBool(_keyShowEmptyChannels, value);
  }

  @override
  String get lastChannel =>
      _preferences.getString(_keyLastChannel) ?? '#general';

  @override
  Future<void> setLastChannel(String value) async {
    await _preferences.setString(_keyLastChannel, value);
  }
}
