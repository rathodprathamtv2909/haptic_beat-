import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:haptic_beat/core/theme/app_theme.dart';
import 'package:haptic_beat/features/player/player_view_model.dart';
import 'package:haptic_beat/shared/widgets/glass_card.dart';

/// High-performance visualizer card rendered with CustomPainter.
class PlayerVisualizer extends StatelessWidget {
  /// Creates a player visualizer from normalized audio samples.
  const PlayerVisualizer({
    super.key,
    required this.mode,
    required this.waveform,
    required this.spectrum,
    required this.isPlaying,
    required this.beatPhase,
    this.height = 176,
  });

  /// Active visualizer mode.
  final VisualizerMode mode;

  /// Waveform samples normalized to 0..1.
  final List<double> waveform;

  /// Spectrum bins normalized to 0..1.
  final List<double> spectrum;

  /// Whether playback is active.
  final bool isPlaying;

  /// Animation phase supplied by the player view model.
  final double beatPhase;

  /// Height of the visualizer canvas.
  final double height;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: RepaintBoundary(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _VisualizerPainter(
              mode: mode,
              waveform: waveform,
              spectrum: spectrum,
              isPlaying: isPlaying,
              beatPhase: beatPhase,
            ),
          ),
        ),
      ),
    );
  }
}

/// Painter for waveform, circular spectrum, bars, and particle visualizations.
class _VisualizerPainter extends CustomPainter {
  _VisualizerPainter({
    required this.mode,
    required this.waveform,
    required this.spectrum,
    required this.isPlaying,
    required this.beatPhase,
  });

  final VisualizerMode mode;
  final List<double> waveform;
  final List<double> spectrum;
  final bool isPlaying;
  final double beatPhase;

  @override
  void paint(Canvas canvas, Size size) {
    _paintGrid(canvas, size);

    switch (mode) {
      case VisualizerMode.waveform:
        _paintWaveform(canvas, size);
      case VisualizerMode.circular:
        _paintCircularSpectrum(canvas, size);
      case VisualizerMode.spectrum:
        _paintLinearSpectrum(canvas, size);
      case VisualizerMode.particles:
        _paintParticles(canvas, size);
    }
  }

  void _paintGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;

    for (var i = 1; i < 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _paintWaveform(Canvas canvas, Size size) {
    final path = Path();
    final glowPath = Path();
    final baseline = size.height / 2;

    for (var i = 0; i < waveform.length; i++) {
      final x = size.width * i / (waveform.length - 1);
      final sample = waveform[i];
      final y = baseline - (sample - 0.5) * size.height * 0.86;
      if (i == 0) {
        path.moveTo(x, y);
        glowPath.moveTo(x, y);
      } else {
        path.lineTo(x, y);
        glowPath.lineTo(x, y);
      }
    }

    canvas
      ..drawPath(
        glowPath,
        Paint()
          ..color = AppTheme.glow.withValues(alpha: isPlaying ? 0.2 : 0.1)
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      )
      ..drawPath(
        path,
        Paint()
          ..shader = const LinearGradient(
            colors: [AppTheme.accent, Colors.white, AppTheme.secondary],
          ).createShader(Offset.zero & size)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
  }

  void _paintLinearSpectrum(Canvas canvas, Size size) {
    final barWidth = size.width / (spectrum.length * 1.7);
    final gap = barWidth * 0.7;
    final baseY = size.height - 12;
    final paint = Paint()..strokeCap = StrokeCap.round;

    for (var i = 0; i < spectrum.length; i++) {
      final value = spectrum[i];
      final left = i * (barWidth + gap) + gap;
      final height = value * (size.height - 28);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, baseY - height, barWidth, height),
        Radius.circular(barWidth / 2),
      );
      paint.shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          AppTheme.secondary.withValues(alpha: 0.42),
          AppTheme.accent,
          Colors.white.withValues(alpha: 0.95),
        ],
      ).createShader(rect.outerRect);
      canvas.drawRRect(rect, paint);
    }
  }

  void _paintCircularSpectrum(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.26;
    final pulseRadius = radius * (1 + (isPlaying ? 0.04 : 0));

    canvas.drawCircle(
      center,
      pulseRadius,
      Paint()
        ..color = AppTheme.accent.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill,
    );

    for (var i = 0; i < spectrum.length; i++) {
      final value = spectrum[i];
      final angle = (math.pi * 2 * i / spectrum.length) + beatPhase * math.pi;
      final inner = radius;
      final outer = radius + value * math.min(size.width, size.height) * 0.18;
      final start = Offset(
        center.dx + math.cos(angle) * inner,
        center.dy + math.sin(angle) * inner,
      );
      final end = Offset(
        center.dx + math.cos(angle) * outer,
        center.dy + math.sin(angle) * outer,
      );
      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = Color.lerp(
            AppTheme.accent,
            AppTheme.secondary,
            value,
          )!.withValues(alpha: 0.86)
          ..strokeWidth = 3.4
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.drawCircle(
      center,
      radius * 0.64,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.42)
        ..style = PaintingStyle.fill,
    );
  }

  void _paintParticles(Canvas canvas, Size size) {
    for (var i = 0; i < spectrum.length; i++) {
      final value = spectrum[i];
      final x =
          size.width *
          ((i + beatPhase * 3) % spectrum.length) /
          spectrum.length;
      final y = size.height * (0.18 + (1 - value) * 0.64);
      final radius = 3 + value * 10;
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..color = Color.lerp(
            AppTheme.accent,
            AppTheme.secondary,
            i / 22,
          )!.withValues(alpha: 0.38 + value * 0.42)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VisualizerPainter oldDelegate) {
    return oldDelegate.mode != mode ||
        oldDelegate.waveform != waveform ||
        oldDelegate.spectrum != spectrum ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.beatPhase != beatPhase;
  }
}
