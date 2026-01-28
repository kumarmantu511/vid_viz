import 'package:flutter/material.dart';
import 'package:vidviz/core/theme.dart' as app_theme;
import 'package:vidviz/model/visualizer.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/visualizer_service.dart';
import 'counter_param_utils.dart';

class CounterGlowSliders extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset asset;
  final String selected;

  CounterGlowSliders(this.asset, {required this.selected, super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final radiusKey = selected == 'start' ? 'counterStartGlowRadius' : 'counterEndGlowRadius';
    final opacityKey = selected == 'start' ? 'counterStartGlowOpacity' : 'counterEndGlowOpacity';

    final double curRadius = readCounterDouble(asset, radiusKey, 0.0).clamp(0.0, 60.0);
    final double curOpacity = readCounterDouble(asset, opacityKey, 0.0).clamp(0.0, 1.0);

    Widget sliderRow({
      required String label,
      required double min,
      required double max,
      required int divisions,
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
                min: min,
                max: max,
                divisions: divisions,
                value: value.clamp(min, max),
                activeColor: app_theme.accent,
                inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
                onChanged: onChanged,
              ),
            ),
          ],
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
              'Glow',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
              ),
            ),
          ),
          sliderRow(
            label: 'Glow Radius',
            min: 0.0,
            max: 60.0,
            divisions: 60,
            value: curRadius,
            onChanged: (v) {
              updateCounterAsset(visualizerService, asset, (_, params) {
                params[radiusKey] = v;
              });
            },
          ),
          sliderRow(
            label: 'Glow Opacity',
            min: 0.0,
            max: 1.0,
            divisions: 20,
            value: curOpacity,
            onChanged: (v) {
              updateCounterAsset(visualizerService, asset, (_, params) {
                params[opacityKey] = v;
              });
            },
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: () {
                updateCounterAsset(visualizerService, asset, (_, params) {
                  params.remove(radiusKey);
                  params.remove(opacityKey);
                });
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? app_theme.projectListCardBg : app_theme.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? app_theme.projectListCardBorder : app_theme.border,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    'Reset',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
