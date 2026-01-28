import 'package:flutter/material.dart';
import 'package:vidviz/core/theme.dart' as app_theme;
import 'package:vidviz/model/visualizer.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/service/visualizer_service.dart';
import 'counter_param_utils.dart';

class CounterLabelColorField extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset asset;
  final String selected;

  CounterLabelColorField(this.asset, {required this.selected, super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final key = selected == 'start' ? 'counterStartColor' : 'counterEndColor';
    final int? colorValue = asset.shaderParams != null && asset.shaderParams![key] is int
        ? asset.shaderParams![key] as int
        : null;

    return Container(
      width: 290,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              width: 120,
              child: Text(
                'Label Color',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              directorService.editingColor = key;
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Color(colorValue ?? 0xFFFFFFFF),
                border: Border.all(
                  color: isDark ? app_theme.projectListCardBorder : app_theme.border,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 2),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              updateCounterAsset(visualizerService, asset, (_, params) {
                params.remove(key);
              });
            },
            borderRadius: BorderRadius.circular(6),
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
          )
        ],
      ),
    );
  }
}
