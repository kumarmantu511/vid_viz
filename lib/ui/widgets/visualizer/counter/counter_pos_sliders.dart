import 'package:flutter/material.dart';
import 'package:vidviz/core/theme.dart' as app_theme;
import 'package:vidviz/model/visualizer.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/visualizer_service.dart';
import 'counter_param_utils.dart';

class CounterPosSliders extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset asset;
  final String selected;

  CounterPosSliders(this.asset, {required this.selected, super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final xKey = selected == 'start' ? 'counterStartPosX' : 'counterEndPosX';
    final yKey = selected == 'start' ? 'counterStartPosY' : 'counterEndPosY';

    final double curX = readCounterPos01(asset, xKey, selected == 'start' ? 0.10 : 0.90);
    final double curY = readCounterPos01(asset, yKey, 0.50);

    Widget sliderRow({
      required String label,
      required double value,
      required ValueChanged<double> onChanged,
    }) {
      return Container(
        width: 290,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 120,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: Slider(
                min: 0.0,
                max: 1.0,
                divisions: 100,
                value: value.clamp(0.0, 1.0),
                activeColor: app_theme.accent,
                inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        sliderRow(
          label: 'Pos X',
          value: curX,
          onChanged: (v) {
            updateCounterAsset(visualizerService, asset, (_, params) {
              params[xKey] = v.clamp(0.0, 1.0);
            });
          },
        ),
        sliderRow(
          label: 'Pos Y',
          value: curY,
          onChanged: (v) {
            updateCounterAsset(visualizerService, asset, (_, params) {
              params[yKey] = v.clamp(0.0, 1.0);
            });
          },
        ),
      ],
    );
  }
}
