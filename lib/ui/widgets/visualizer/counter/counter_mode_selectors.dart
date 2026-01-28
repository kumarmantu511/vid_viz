import 'package:flutter/material.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/visualizer_service.dart';
import 'package:vidviz/model/visualizer.dart';
import 'package:vidviz/core/theme.dart' as app_theme;
import 'counter_param_utils.dart';

class CounterStartModeSelector extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset asset;

  CounterStartModeSelector(this.asset, {super.key});

  static const _options = [
    {'id': 'elapsed', 'label': 'Elapsed'},
    {'id': 'remaining', 'label': 'Remaining'},
    {'id': 'total', 'label': 'Total'},
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String current = readCounterString(asset, 'counterStartMode', 'elapsed');

    return _CounterChipRow(
      title: 'Start Mode',
      isDark: isDark,
      current: current,
      options: _options,
      onSelect: (id) {
        updateCounterAsset(visualizerService, asset, (_, params) {
          params['counterStartMode'] = id;
        });
      },
    );
  }
}

class CounterEndModeSelector extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset asset;

  CounterEndModeSelector(this.asset, {super.key});

  static const _options = [
    {'id': 'remaining', 'label': 'Remaining'},
    {'id': 'elapsed', 'label': 'Elapsed'},
    {'id': 'total', 'label': 'Total'},
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String current = readCounterString(asset, 'counterEndMode', 'remaining');

    return _CounterChipRow(
      title: 'End Mode',
      isDark: isDark,
      current: current,
      options: _options,
      onSelect: (id) {
        updateCounterAsset(visualizerService, asset, (_, params) {
          params['counterEndMode'] = id;
        });
      },
    );
  }
}

class _CounterChipRow extends StatelessWidget {
  final String title;
  final bool isDark;
  final String current;
  final List<Map<String, String>> options;
  final ValueChanged<String> onSelect;

  const _CounterChipRow({
    required this.title,
    required this.isDark,
    required this.current,
    required this.options,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 290,
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              title,
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
              children: options.map((opt) {
                final id = opt['id'] ?? '';
                final label = opt['label'] ?? id;
                final bool selected = id == current;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      if (!selected) onSelect(id);
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? app_theme.accent.withOpacity(0.2)
                            : (isDark ? app_theme.projectListCardBg : app_theme.surface),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: selected
                              ? app_theme.accent
                              : (isDark ? app_theme.projectListCardBorder : app_theme.border),
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          color: selected
                              ? app_theme.accent
                              : (isDark ? app_theme.darkTextSecondary : app_theme.textSecondary),
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
