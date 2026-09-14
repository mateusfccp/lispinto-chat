extension type const ChannelName._(String value) implements String {
  /// Creates a [ChannelName].
  ///
  /// Throws an [ArgumentError] if the [value] does not start with a '#'.
  factory ChannelName(String value) {
    if (!value.startsWith('#')) {
      throw ArgumentError('Channel name must start with #, got: $value');
    }
    return ChannelName._(value);
  }

  /// A constant representing the general channel.
  const ChannelName.general() : this._('#general');
}
