import 'package:flutter/services.dart';

class NativeAudioPlayer {
  static const _channel = MethodChannel('piraeus_banter/audio');

  Future<void> play(String path) =>
      _channel.invokeMethod('play', {'path': path});

  Future<void> stop() => _channel.invokeMethod('stop');
}
