import 'package:flutter/material.dart';
import 'package:vidviz/core/theme.dart' as app_theme;
import 'package:vidviz/model/visualizer.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/visualizer_service.dart';
import 'counter_param_utils.dart';

class CounterSelectedSelector extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset asset;

  CounterSelectedSelector(this.asset, {super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = readCounterSelected(asset);

    Widget chip(String id, String label) {
      final bool isSelected = selected == id;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          onTap: () {
            if (isSelected) return;
            updateCounterAsset(visualizerService, asset, (_, params) {
              params['counterSelected'] = id;
            });
          },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? app_theme.accent.withOpacity(0.2)
                  : (isDark ? app_theme.projectListCardBg : app_theme.surface),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected
                    ? app_theme.accent
                    : (isDark ? app_theme.projectListCardBorder : app_theme.border),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? app_theme.accent
                    : (isDark ? app_theme.darkTextSecondary : app_theme.textSecondary),
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
              'Selected Counter',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
              ),
            ),
          ),
          Row(
            children: [
              chip('start', 'Start'),
              chip('end', 'End'),
            ],
          ),
        ],
      ),
    );
  }
}
