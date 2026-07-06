import 'dart:async';

import 'package:just_audio/just_audio.dart';

/// Concrete audio playback service backed by just_audio.
class AudioService {
  AudioService() {
    _player = AudioPlayer();
    _init();
  }

  AudioPlayer? _player;
  StreamSubscription<PlaybackEvent>? _playbackSubscription;
  final _eventController = StreamController<AudioPlaybackState>.broadcast();

  Stream<AudioPlaybackState> get playbackState => _eventController.stream;

  AudioPlayer? get player => _player;

  /// Whether a playable source has been loaded into the engine.
  bool get hasSource => _player?.audioSource != null;

  /// Duration reported by the audio engine, when available.
  Duration? get duration => _player?.duration;

  void _init() {
    _player ??= AudioPlayer();
    _playbackSubscription ??= _player!.playbackEventStream.listen((event) {
      final state = AudioPlaybackState(
        isPlaying: _player?.playing ?? false,
        position: event.updatePosition,
        duration: event.duration ?? const Duration(seconds: 0),
      );
      _eventController.add(state);
    });
  }

  Future<void> loadFromFile(String path) async {
    _player ??= AudioPlayer();
    _init();
    await _player!.setFilePath(path);
    await _player!.play();
    _eventController.add(
      AudioPlaybackState(
        isPlaying: true,
        position: Duration.zero,
        duration: _player!.duration ?? const Duration(seconds: 0),
      ),
    );
  }

  Future<void> playPause() async {
    if (_player == null) {
      return;
    }
    if (_player!.playing) {
      await _player!.pause();
    } else {
      await _player!.play();
    }
  }

  Future<void> seekTo(Duration position) async {
    await _player?.seek(position);
  }

  Future<void> dispose() async {
    await _playbackSubscription?.cancel();
    await _eventController.close();
    await _player?.dispose();
  }
}

/// Stream model for playback progress.
class AudioPlaybackState {
  const AudioPlaybackState({
    required this.isPlaying,
    required this.position,
    required this.duration,
  });

  final bool isPlaying;
  final Duration position;
  final Duration duration;
}
