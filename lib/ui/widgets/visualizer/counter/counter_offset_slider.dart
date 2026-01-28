import 'package:flutter/material.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/visualizer_service.dart';
import 'package:vidviz/model/visualizer.dart';
import 'package:vidviz/core/theme.dart' as app_theme;
import 'counter_param_utils.dart';

class CounterOffsetYSlider extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset asset;

  CounterOffsetYSlider(this.asset, {super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final double current = readCounterDouble(asset, 'counterOffsetY', 0.0);
    final value = current.clamp(-120.0, 120.0);

    return Container(
      width: 290,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              'Offset Y',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Slider(
              min: -120.0,
              max: 120.0,
              divisions: 60,
              value: value,
              activeColor: app_theme.accent,
              inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
              onChanged: (v) {
                updateCounterAsset(visualizerService, asset, (_, params) {
                  params['counterOffsetY'] = v;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
