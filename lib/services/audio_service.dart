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
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  final _eventController = StreamController<AudioPlaybackState>.broadcast();

  Stream<AudioPlaybackState> get playbackState => _eventController.stream;

  AudioPlayer? get player => _player;

  /// Whether a playable source has been loaded into the engine.
  bool get hasSource => _player?.audioSource != null;

  /// Whether the audio engine is currently playing.
  bool get isPlaying => _player?.playing ?? false;

  /// Duration reported by the audio engine, when available.
  Duration? get duration => _player?.duration;

  void _init() {
    _player ??= AudioPlayer();
    _playbackSubscription ??= _player!.playbackEventStream.listen((event) {
      _emitState(position: event.updatePosition, duration: event.duration);
    });
    _positionSubscription ??= _player!.positionStream.listen((position) {
      _emitState(position: position);
    });
    _durationSubscription ??= _player!.durationStream.listen((duration) {
      _emitState(duration: duration);
    });
    _playerStateSubscription ??= _player!.playerStateStream.listen((_) {
      _emitState();
    });
  }

  /// Prepares a local file for playback without starting the audio clock.
  Future<void> prepareFromFile(String path) async {
    _player ??= AudioPlayer();
    _init();
    await _player!.setFilePath(path);
    _emitState(position: Duration.zero);
  }

  Future<void> loadFromFile(String path) async {
    await prepareFromFile(path);
    await play();
  }

  /// Starts or resumes the prepared source.
  Future<void> play() async {
    final player = _player;
    if (player == null) {
      return;
    }

    unawaited(
      player.play().catchError((Object error, StackTrace stackTrace) {
        if (!_eventController.isClosed) {
          _eventController.addError(error, stackTrace);
        }
      }),
    );
    _emitState();
  }

  /// Pauses the current source.
  Future<void> pause() async {
    await _player?.pause();
    _emitState();
  }

  Future<bool> playPause() async {
    if (_player == null) {
      return false;
    }
    if (_player!.playing) {
      await pause();
      return false;
    } else {
      await play();
      return true;
    }
  }

  Future<void> seekTo(Duration position) async {
    await _player?.seek(position);
  }

  Future<void> dispose() async {
    await _playbackSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _playerStateSubscription?.cancel();
    await _eventController.close();
    await _player?.dispose();
  }

  void _emitState({Duration? position, Duration? duration}) {
    if (_eventController.isClosed) {
      return;
    }

    final player = _player;
    _eventController.add(
      AudioPlaybackState(
        isPlaying: player?.playing ?? false,
        position: position ?? player?.position ?? Duration.zero,
        duration: duration ?? player?.duration ?? Duration.zero,
      ),
    );
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
