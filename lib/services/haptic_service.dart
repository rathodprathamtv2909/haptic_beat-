import 'package:flutter/services.dart';

/// A bridge for triggering lightweight haptic feedback from Flutter.
class HapticService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.haptic_beat/haptics',
  );

  /// Warms the native haptic engine before playback starts.
  static Future<void> prepare() async {
    await _invoke('prepare', intensity: 0);
  }

  /// Starts a native scheduled haptic waveform and returns whether it was accepted.
  static Future<bool> startPattern({
    required List<int> offsetsMs,
    required List<double> intensities,
    required double strength,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('startPattern', {
        'offsetsMs': offsetsMs,
        'intensities': intensities,
        'strength': strength.clamp(0.0, 1.0),
      });
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Cancels any native scheduled haptic waveform.
  static Future<void> cancelPattern() async {
    try {
      await _channel.invokeMethod<void>('cancelPattern');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  /// Triggers a kick-style haptic transient.
  static Future<void> triggerKick({double intensity = 1}) async {
    await _invoke('triggerKick', intensity: intensity);
  }

  /// Triggers a rounded bass haptic pulse.
  static Future<void> triggerBass({double intensity = 1}) async {
    await _invoke('triggerBass', intensity: intensity);
  }

  /// Triggers a sharper snare-style haptic transient.
  static Future<void> triggerSnare({double intensity = 1}) async {
    await _invoke('triggerSnare', intensity: intensity);
  }

  /// Triggers a strong confirmation haptic.
  static Future<void> triggerImpact({double intensity = 1}) async {
    await _invoke('triggerImpact', intensity: intensity);
  }

  static Future<void> _invoke(
    String method, {
    required double intensity,
  }) async {
    try {
      final normalizedIntensity = intensity.clamp(0.0, 1.0).toDouble();
      await _channel.invokeMethod<void>(method, {
        'intensity': normalizedIntensity,
      });
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}
