import 'package:flutter/material.dart';
import 'package:vidviz/core/theme.dart' as app_theme;
import 'package:vidviz/model/visualizer.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/visualizer_service.dart';
import 'counter_param_utils.dart';

class CounterAlignControls extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset asset;
  final String selected;

  CounterAlignControls(this.asset, {required this.selected, super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    void setXY({double? x, double? y}) {
      updateCounterAsset(visualizerService, asset, (_, params) {
        final xKey = selected == 'start' ? 'counterStartPosX' : 'counterEndPosX';
        final yKey = selected == 'start' ? 'counterStartPosY' : 'counterEndPosY';
        if (x != null) params[xKey] = x.clamp(0.0, 1.0);
        if (y != null) params[yKey] = y.clamp(0.0, 1.0);
      });
    }

    Widget btn(String label, VoidCallback onTap) {
      return Padding(
        padding: const EdgeInsets.only(right: 8, bottom: 8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? app_theme.projectListCardBg : app_theme.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDark ? app_theme.projectListCardBorder : app_theme.border,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 290,
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Align',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Wrap(
              children: [
                btn('Left', () => setXY(x: 0.10)),
                btn('Center', () => setXY(x: 0.50)),
                btn('Right', () => setXY(x: 0.90)),
                btn('Top', () => setXY(y: 0.10)),
                btn('Middle', () => setXY(y: 0.50)),
                btn('Bottom', () => setXY(y: 0.90)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
