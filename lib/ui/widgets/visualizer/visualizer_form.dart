import 'package:flutter/material.dart';
import 'package:vidviz/l10n/generated/app_localizations.dart';
import 'package:vidviz/core/theme.dart' as app_theme;
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/visualizer_service.dart';
import 'package:vidviz/model/visualizer.dart';
import 'package:vidviz/ui/widgets/visualizer/shader_form.dart';
import 'package:vidviz/ui/widgets/visualizer/settings_form.dart';
import 'package:vidviz/ui/widgets/visualizer/visual_form.dart';
import 'package:vidviz/ui/widgets/visualizer/progress/progress_form.dart';
import 'package:vidviz/ui/widgets/visualizer/counter/counter_form.dart';
import 'package:vidviz/ui/widgets/visualizer/visualizer_shader_registry.dart';

/// VisualizerForm - TextForm'un kopyası
/// Visualizer ayarları: efekt tipi, renk, ölçek vb.
class VisualizerForm extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset _asset;

  VisualizerForm(this._asset) : super();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Stream ile dinle (Text gibi)
    return StreamBuilder<VisualizerAsset?>(
      stream: visualizerService.editingVisualizerAsset$,
      initialData: _asset,
      builder: (context, snapshot) {
        VisualizerAsset currentAsset = snapshot.data ?? _asset;
        String renderMode = currentAsset.renderMode;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView( scrollDirection: Axis.vertical,child: _SubMenu(currentAsset, renderMode)),
            Expanded(
              child: Container(
                color: isDark ? app_theme.projectListBg : app_theme.background,
                padding: const EdgeInsets.only(left: 16, top: 8, right: 16),
                child:
                      renderMode == 'progress'
                    ? ProgressForm(currentAsset) // Progress bar mode
                    : renderMode == 'counter'
                    ? CounterForm(currentAsset) // Counter mode
                    : renderMode == 'visual'
                    ? VisualForm(currentAsset) // Visual mode (stage-sampling shaders)
                    : renderMode == 'settings'
                    ? SettingsForm(currentAsset) // Settings mode
                    : ShaderForm(currentAsset), // Shader mode (fallback, includes legacy 'canvas')
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SubMenu extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset _asset;
  final String _renderMode;

  _SubMenu(this._asset, this._renderMode);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    bool isShaderMode = _renderMode == 'shader';
    bool isSettingsMode = _renderMode == 'settings';
    bool isVisualMode = _renderMode == 'visual';
    bool isProgressMode = _renderMode == 'progress';
    bool isCounterMode = _renderMode == 'counter';

    Color getColor(bool isSelected) => isSelected ? app_theme.accent : (isDark ? app_theme.darkTextSecondary : app_theme.textSecondary);

    return Container(
      decoration: BoxDecoration(
          color: isDark ? app_theme.projectListCardBg : app_theme.surface, // Daha belirgin arka plan
          border: Border(
              right: BorderSide(
                  color: isDark ? app_theme.projectListCardBorder : app_theme.border,
                  width: 1
              )
          )
      ),
      //margin: const EdgeInsets.only(right: 16),
      child: Column(
        children: [


          // Shader Mode Button
          IconButton(
            icon: Icon(
              Icons.bar_chart_rounded,
              color: getColor(isShaderMode),
            ),
            tooltip: loc.visualizerSubmenuShaderTooltip,
            onPressed: () {
              final shaderType = normalizeVisualizerShaderId(_asset.shaderType ?? 'bar');
              final updated = VisualizerAsset.clone(_asset)
                ..renderMode = 'shader'
                ..shaderType = shaderType;
              visualizerService.editingVisualizerAsset = updated;
            },
          ),

          // Visual Mode Button (Background Visuals)
          IconButton(
            icon: Icon(
              Icons.auto_awesome,
              color: getColor(isVisualMode),
            ),
            tooltip: loc.visualizerSubmenuVisualTooltip,
            onPressed: () {
              // Visual mode: ensure we start with a valid visual shader
              final shaderType = normalizeVisualShaderIdForUi(_asset.shaderType ?? 'pro_nation');
              final updated = VisualizerAsset.clone(_asset)
                ..renderMode = 'visual'
                ..shaderType = shaderType
                ..fullScreen = _asset.fullScreen; // mevcut seçimi koru
              visualizerService.editingVisualizerAsset = updated;
            },
          ),

          // Progress Mode Button (Music progress bars)
          IconButton(
            icon: Icon(
              Icons.linear_scale,
              color: getColor(isProgressMode),
            ),
            tooltip: loc.visualizerSubmenuProgressTooltip,
            onPressed: () {
              String style = _asset.effectStyle;
              if (style.isEmpty || style == 'default') {
                style = 'capsule';
              }
              final double strokeWidth = _asset.strokeWidth < 6.0
                  ? 6.0
                  : _asset.strokeWidth;
              final updated = VisualizerAsset.clone(_asset)
                ..renderMode = 'progress'
                ..effectStyle = style
                ..strokeWidth = strokeWidth;
              visualizerService.editingVisualizerAsset = updated;
            },
          ),

          // Counter Mode Button (Start/End timers)
          IconButton(
            icon: Icon(
              Icons.timer,
              color: getColor(isCounterMode),
            ),
            tooltip: 'Counter',
            onPressed: () {
              final updated = VisualizerAsset.clone(_asset)..renderMode = 'counter';
              visualizerService.editingVisualizerAsset = updated;
            },
          ),

          // Settings Button
          IconButton(
            icon: Icon(
              Icons.settings,
              color: getColor(isSettingsMode),
            ),
            tooltip: loc.visualizerSubmenuSettingsTooltip,
            onPressed: () {
              final updated = VisualizerAsset.clone(_asset)
                ..renderMode = 'settings';
              visualizerService.editingVisualizerAsset = updated;
            },
          ),
        ],
      ),
    );
  }
}
