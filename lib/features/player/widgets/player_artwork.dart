import 'package:flutter/material.dart';
import 'package:haptic_beat/core/theme/app_theme.dart';
import 'package:haptic_beat/features/player/player_view_model.dart';

/// Animated artwork surface that reacts to playback and beat pulse state.
class PlayerArtwork extends StatelessWidget {
  /// Creates a responsive animated artwork widget.
  const PlayerArtwork({
    super.key,
    required this.track,
    required this.isPlaying,
    required this.beatPulse,
    required this.beatPhase,
    this.size = 280,
  });

  /// Current track metadata.
  final PlayerTrack track;

  /// Whether playback is active.
  final bool isPlaying;

  /// Pulse scalar derived from the beat engine.
  final double beatPulse;

  /// Rotation phase derived from the beat engine.
  final double beatPhase;

  /// Diameter of the artwork.
  final double size;

  @override
  Widget build(BuildContext context) {
    final artworkSize = size.clamp(180.0, 320.0);

    return RepaintBoundary(
      child: AnimatedScale(
        scale: beatPulse,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        child: AnimatedRotation(
          turns: isPlaying ? beatPhase * 0.025 : 0,
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
          child: Container(
            width: artworkSize,
            height: artworkSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.35, -0.45),
                colors: [
                  Colors.white.withValues(alpha: 0.92),
                  track.accentColor,
                  AppTheme.secondary,
                  AppTheme.background,
                ],
                stops: const [0.0, 0.28, 0.68, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: track.accentColor.withValues(alpha: 0.28),
                  blurRadius: 64,
                  spreadRadius: 10,
                ),
                BoxShadow(
                  color: AppTheme.secondary.withValues(alpha: 0.18),
                  blurRadius: 90,
                  spreadRadius: 16,
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(artworkSize * 0.065),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.36),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: artworkSize * 0.44,
                      height: artworkSize * 0.44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.music_note_rounded,
                      size: artworkSize * 0.28,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
