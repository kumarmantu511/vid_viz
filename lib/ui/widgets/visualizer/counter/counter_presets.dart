import 'package:flutter/material.dart';
import 'package:vidviz/core/theme.dart' as app_theme;
import 'package:vidviz/model/visualizer.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/visualizer_service.dart';
import 'counter_param_utils.dart';

typedef _CounterPresetApply = void Function(Map<String, dynamic> params);

class CounterPresetSelector extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset asset;

  CounterPresetSelector(this.asset, {super.key});

  static final List<Map<String, dynamic>> _presets = [

    {
      'id': 'top',
      'label': 'Top',
      'apply': (Map<String, dynamic> p) {
        p['counterStartPosX'] = 0.10;
        p['counterStartPosY'] = 0.10;
        p['counterEndPosX'] = 0.90;
        p['counterEndPosY'] = 0.10;
      },
    },
    {
      'id': 'center',
      'label': 'Center',
      'apply': (Map<String, dynamic> p) {
        p['counterStartPosX'] = 0.10;
        p['counterStartPosY'] = 0.50;
        p['counterEndPosX'] = 0.90;
        p['counterEndPosY'] = 0.50;
      },
    },
    {
      'id': 'bottom',
      'label': 'Bottom',
      'apply': (Map<String, dynamic> p) {
        p['counterStartPosX'] = 0.10;
        p['counterStartPosY'] = 0.90;
        p['counterEndPosX'] = 0.90;
        p['counterEndPosY'] = 0.90;
      },
    },
    /*{
      'id': 'corners',
      'label': 'Corners',
      'apply': (Map<String, dynamic> p) {
        p['counterStartPosX'] = 0.08;
        p['counterStartPosY'] = 0.06;
        p['counterEndPosX'] = 0.92;
        p['counterEndPosY'] = 0.94;
      },
    },*/
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 290,
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Presets',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _presets.map((preset) {
                final label = preset['label'] as String;
                final apply = preset['apply'] as _CounterPresetApply;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      updateCounterAsset(visualizerService, asset, (_, params) {
                        apply(params);
                      });
                    },
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
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
