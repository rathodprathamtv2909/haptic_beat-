import 'package:flutter/material.dart';
import 'package:haptic_beat/core/theme/app_theme.dart';
import 'package:haptic_beat/features/player/player_view_model.dart';
import 'package:haptic_beat/shared/widgets/glass_card.dart';

/// Dashboard panel for playback, beat, latency, battery, and haptic metrics.
class PlayerMetricsPanel extends StatelessWidget {
  /// Creates the metrics panel.
  const PlayerMetricsPanel({
    super.key,
    required this.metrics,
    required this.hapticStrength,
    required this.onHapticStrengthChanged,
  });

  /// Metrics rendered as compact dashboard tiles.
  final List<PlayerMetric> metrics;

  /// Current haptic strength normalized to 0..1.
  final double hapticStrength;

  /// Callback for haptic strength changes.
  final ValueChanged<double> onHapticStrengthChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Signal',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 420 ? 3 : 2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: metrics.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: columns == 3 ? 2.25 : 2.1,
                ),
                itemBuilder: (context, index) {
                  return _MetricTile(metric: metrics[index]);
                },
              );
            },
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(Icons.vibration_rounded, color: AppTheme.accent),
              const SizedBox(width: 10),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppTheme.accent,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
                    thumbColor: Colors.white,
                    overlayColor: AppTheme.accent.withValues(alpha: 0.12),
                    trackHeight: 5,
                  ),
                  child: Slider(
                    value: hapticStrength,
                    onChanged: onHapticStrengthChanged,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact metric tile.
class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});

  final PlayerMetric metric;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.055),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              metric.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                metric.value,
                style: TextStyle(
                  color: metric.accent,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
