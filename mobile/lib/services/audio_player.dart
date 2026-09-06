import 'package:flutter/services.dart';

class NativeAudioPlayer {
  static const _channel = MethodChannel('piraeus_banter/audio');

  Future<void> play(String path, {double speed = 1.0}) =>
      _channel.invokeMethod('play', {'path': path, 'speed': speed});

  Future<void> stop() => _channel.invokeMethod('stop');

  Future<void> pause() => _channel.invokeMethod('pause');

  Future<void> resume() => _channel.invokeMethod('resume');

  Future<void> merge(
    List<String> paths,
    String outputPath, {
    double speed = 1.0,
  }) => _channel.invokeMethod('merge', {
    'paths': paths,
    'outputPath': outputPath,
    'speed': speed,
  });

  Future<Duration> duration(String path) async {
    final milliseconds = await _channel.invokeMethod<int>('duration', {
      'path': path,
    });
    return Duration(milliseconds: milliseconds ?? 0);
  }
}
