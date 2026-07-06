import 'package:flutter/services.dart';

/// A single haptic cue aligned to an analyzed transient in the audio file.
class HapticCue {
  const HapticCue({required this.position, required this.intensity});

  final Duration position;
  final double intensity;
}

/// Beat and haptic timing metadata extracted from a local audio file.
class AudioAnalysis {
  const AudioAnalysis({
    required this.bpm,
    required this.confidence,
    required this.cues,
  });

  final int bpm;
  final double confidence;
  final List<HapticCue> cues;

  bool get hasCues => cues.isNotEmpty;
}

/// Platform-backed audio analysis service.
class AudioAnalysisService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.haptic_beat/audio_analysis',
  );

  /// Analyzes the local audio file and returns a beat/haptic cue map.
  Future<AudioAnalysis?> analyzeFile(String path) async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'analyzeFile',
        {'path': path},
      );
      if (result == null) {
        return null;
      }

      final bpm = (result['bpm'] as num?)?.round();
      final confidence = (result['confidence'] as num?)?.toDouble();
      final times = result['beatTimesMs'] as List<Object?>?;
      final intensities = result['beatIntensities'] as List<Object?>?;
      if (bpm == null || confidence == null || times == null) {
        return null;
      }

      final cues = <HapticCue>[];
      for (var i = 0; i < times.length; i++) {
        final timeMs = (times[i] as num?)?.round();
        if (timeMs == null) {
          continue;
        }

        final intensity = i < (intensities?.length ?? 0)
            ? ((intensities![i] as num?)?.toDouble() ?? confidence)
            : confidence;
        cues.add(
          HapticCue(
            position: Duration(milliseconds: timeMs),
            intensity: intensity.clamp(0.24, 1.0),
          ),
        );
      }

      cues.sort((a, b) => a.position.compareTo(b.position));

      return AudioAnalysis(
        bpm: bpm.clamp(40, 240),
        confidence: confidence.clamp(0.0, 1.0),
        cues: List.unmodifiable(cues),
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
