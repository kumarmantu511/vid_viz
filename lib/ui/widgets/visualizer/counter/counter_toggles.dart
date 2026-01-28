import 'package:flutter/material.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/visualizer_service.dart';
import 'package:vidviz/model/visualizer.dart';
import 'package:vidviz/core/theme.dart' as app_theme;
import 'counter_param_utils.dart';

class CounterStartEnabledToggle extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset asset;

  CounterStartEnabledToggle(this.asset, {super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool current = readCounterBool(asset, 'counterStartEnabled', true);

    return Container(
      width: 290,
     // padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              width: 120,
              child: Text(
                'Start Counter',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                ),
              ),
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: current,
              activeColor: app_theme.accent,
              onChanged: (v) {
                updateCounterAsset(visualizerService, asset, (_, params) {
                  params['counterStartEnabled'] = v;

                  final selected = readCounterSelected(asset);
                  final endEnabled = readCounterBool(asset, 'counterEndEnabled', true);
                  if (!v && selected == 'start' && endEnabled) {
                    params['counterSelected'] = 'end';
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}

class CounterEndEnabledToggle extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset asset;

  CounterEndEnabledToggle(this.asset, {super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool current = readCounterBool(asset, 'counterEndEnabled', true);

    return Container(
      width: 290,
      //padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              width: 120,
              child: Text(
                'End Counter',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                ),
              ),
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: current,
              activeColor: app_theme.accent,
              onChanged: (v) {
                updateCounterAsset(visualizerService, asset, (_, params) {
                  params['counterEndEnabled'] = v;

                  final selected = readCounterSelected(asset);
                  final startEnabled = readCounterBool(asset, 'counterStartEnabled', true);
                  if (!v && selected == 'end' && startEnabled) {
                    params['counterSelected'] = 'start';
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
