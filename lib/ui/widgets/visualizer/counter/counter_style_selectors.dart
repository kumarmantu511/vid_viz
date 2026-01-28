import 'package:flutter/material.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/visualizer_service.dart';
import 'package:vidviz/model/visualizer.dart';
import 'package:vidviz/core/theme.dart' as app_theme;
import 'counter_param_utils.dart';

class CounterPositionSelector extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset asset;

  CounterPositionSelector(this.asset, {super.key});

  static const _options = [
    {'id': 'side', 'label': 'Side'},
    {'id': 'top', 'label': 'Top'},
    {'id': 'center', 'label': 'Center'},
    {'id': 'bottom', 'label': 'Bottom'},
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String current = readCounterString(asset, 'counterPos', 'side');

    return _CounterChipRow(
      title: 'Position',
      isDark: isDark,
      current: current,
      options: _options,
      onSelect: (id) {
        updateCounterAsset(visualizerService, asset, (_, params) {
          params['counterPos'] = id;
        });
      },
    );
  }
}

class CounterLabelSizeSelector extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset asset;

  CounterLabelSizeSelector(this.asset, {super.key});

  static const _options = [
    {'id': 'small', 'label': 'Small'},
    {'id': 'normal', 'label': 'Normal'},
    {'id': 'large', 'label': 'Large'},
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String current = readCounterString(asset, 'counterLabelSize', 'normal');

    return _CounterChipRow(
      title: 'Label Size',
      isDark: isDark,
      current: current,
      options: _options,
      onSelect: (id) {
        updateCounterAsset(visualizerService, asset, (_, params) {
          params['counterLabelSize'] = id;
        });
      },
    );
  }
}

class CounterAnimSelector extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset asset;

  CounterAnimSelector(this.asset, {super.key});

  static const _options = [
    {'id': 'none', 'label': 'None'},
    {'id': 'pulse', 'label': 'Pulse'},
    {'id': 'flip', 'label': 'Flip'},
    {'id': 'leaf', 'label': 'Leaf'},
    {'id': 'bounce', 'label': 'Bounce'},
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String current = readCounterString(asset, 'counterAnim', 'none');

    return _CounterChipRow(
      title: 'Animation',
      isDark: isDark,
      current: current,
      options: _options,
      onSelect: (id) {
        updateCounterAsset(visualizerService, asset, (_, params) {
          params['counterAnim'] = id;
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
