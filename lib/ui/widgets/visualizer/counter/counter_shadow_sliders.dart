import 'package:flutter/material.dart';
import 'package:vidviz/core/theme.dart' as app_theme;
import 'package:vidviz/model/visualizer.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/visualizer_service.dart';
import 'counter_param_utils.dart';

class CounterShadowSliders extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset asset;
  final String selected;

  CounterShadowSliders(this.asset, {required this.selected, super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final opacityKey = selected == 'start' ? 'counterStartShadowOpacity' : 'counterEndShadowOpacity';
    final blurKey = selected == 'start' ? 'counterStartShadowBlur' : 'counterEndShadowBlur';
    final offsetXKey = selected == 'start' ? 'counterStartShadowOffsetX' : 'counterEndShadowOffsetX';
    final offsetYKey = selected == 'start' ? 'counterStartShadowOffsetY' : 'counterEndShadowOffsetY';

    final double curOpacity = readCounterDouble(asset, opacityKey, 0.75).clamp(0.0, 1.0);
    final double curBlur = readCounterDouble(asset, blurKey, 2.0).clamp(0.0, 20.0);
    final double curX = readCounterDouble(asset, offsetXKey, 0.0).clamp(-16.0, 16.0);
    final double curY = readCounterDouble(asset, offsetYKey, 1.0).clamp(-16.0, 16.0);

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
              'Shadow',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
              ),
            ),
          ),
          sliderRow(
            label: 'Shadow Opacity',
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
          sliderRow(
            label: 'Shadow Blur',
            min: 0.0,
            max: 20.0,
            divisions: 20,
            value: curBlur,
            onChanged: (v) {
              updateCounterAsset(visualizerService, asset, (_, params) {
                params[blurKey] = v;
              });
            },
          ),
          sliderRow(
            label: 'Shadow Offset X',
            min: -16.0,
            max: 16.0,
            divisions: 64,
            value: curX,
            onChanged: (v) {
              updateCounterAsset(visualizerService, asset, (_, params) {
                params[offsetXKey] = v;
              });
            },
          ),
          sliderRow(
            label: 'Shadow Offset Y',
            min: -16.0,
            max: 16.0,
            divisions: 64,
            value: curY,
            onChanged: (v) {
              updateCounterAsset(visualizerService, asset, (_, params) {
                params[offsetYKey] = v;
              });
            },
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: () {
                updateCounterAsset(visualizerService, asset, (_, params) {
                  params.remove(opacityKey);
                  params.remove(blurKey);
                  params.remove(offsetXKey);
                  params.remove(offsetYKey);
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
