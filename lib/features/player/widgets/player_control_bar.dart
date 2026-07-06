import 'package:flutter/material.dart';
import 'package:haptic_beat/core/theme/app_theme.dart';

/// Playback transport controls for the player screen.
class PlayerControlBar extends StatelessWidget {
  /// Creates a transport control row.
  const PlayerControlBar({
    super.key,
    required this.isPlaying,
    required this.shuffleEnabled,
    required this.repeatEnabled,
    required this.onPrevious,
    required this.onPlayPause,
    required this.onNext,
    required this.onShuffle,
    required this.onRepeat,
  });

  /// Whether the play button should show pause.
  final bool isPlaying;

  /// Whether shuffle is enabled.
  final bool shuffleEnabled;

  /// Whether repeat is enabled.
  final bool repeatEnabled;

  /// Previous-track callback.
  final VoidCallback onPrevious;

  /// Play/pause callback.
  final VoidCallback onPlayPause;

  /// Next-track callback.
  final VoidCallback onNext;

  /// Shuffle callback.
  final VoidCallback onShuffle;

  /// Repeat callback.
  final VoidCallback onRepeat;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ControlIconButton(
          icon: Icons.shuffle_rounded,
          isActive: shuffleEnabled,
          tooltip: 'Shuffle',
          onPressed: onShuffle,
        ),
        _ControlIconButton(
          icon: Icons.skip_previous_rounded,
          tooltip: 'Previous',
          onPressed: onPrevious,
        ),
        _PlayButton(isPlaying: isPlaying, onPressed: onPlayPause),
        _ControlIconButton(
          icon: Icons.skip_next_rounded,
          tooltip: 'Next',
          onPressed: onNext,
        ),
        _ControlIconButton(
          icon: Icons.repeat_rounded,
          isActive: repeatEnabled,
          tooltip: 'Repeat',
          onPressed: onRepeat,
        ),
      ],
    );
  }
}

/// Circular icon button for secondary playback controls.
class _ControlIconButton extends StatelessWidget {
  const _ControlIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isActive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        color: isActive ? AppTheme.accent : Colors.white70,
        iconSize: 26,
        style: IconButton.styleFrom(
          fixedSize: const Size.square(48),
          backgroundColor: Colors.white.withValues(
            alpha: isActive ? 0.12 : 0.06,
          ),
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}

/// Primary play/pause control.
class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.isPlaying, required this.onPressed});

  final bool isPlaying;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isPlaying ? 'Pause' : 'Play',
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.accent,
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withValues(
                  alpha: isPlaying ? 0.34 : 0.2,
                ),
                blurRadius: isPlaying ? 38 : 24,
                spreadRadius: isPlaying ? 6 : 2,
              ),
            ],
          ),
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: AppTheme.background,
            size: 38,
          ),
        ),
      ),
    );
  }
}
