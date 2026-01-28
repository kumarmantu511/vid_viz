import 'package:flutter/material.dart';
import 'package:vidviz/l10n/generated/app_localizations.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/service/visualizer_service.dart';
import 'package:vidviz/model/visualizer.dart';
import 'package:vidviz/core/theme.dart' as app_theme;

/// SettingsForm - Gelişmiş Visualizer ayarları
/// FFT parametreleri, bant sayısı, smoothing gibi sistem seviyesi kontroller
class SettingsForm extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final directorService = locator.get<DirectorService>();
  final VisualizerAsset _asset;

  SettingsForm(this._asset) : super();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              loc.visualizerSettingsAdvancedTitle,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
              ),
            ),
            Text(
              loc.visualizerSettingsAdvancedSubtitle,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),

            // FFT Band Count (adjustable)
            _FFTBandsSlider(_asset),
            const SizedBox(height: 16),

            // Smoothing Alpha (adjustable)
            _SmoothingSlider(_asset),
            const SizedBox(height: 16),

            // Animation Smoothness (band smoothing)

            // Reactivity (curve shaping)

            // Frequency Range (adjustable)
            _FrequencyRangeSliders(_asset),
            const SizedBox(height: 24),

            // Apply Changes Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  visualizerService.recomputeFFT();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(loc.visualizerSettingsApplyFftSnack),
                    ),
                  );
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(loc.visualizerSettingsApplyFftButton),
                style: ElevatedButton.styleFrom(
                  backgroundColor: app_theme.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Divider(
                color: isDark ? app_theme.projectListCardBorder : app_theme.border,
                height: 1
              ),
            ),

            // Static Info
            Text(
              loc.visualizerSettingsStaticTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            _InfoRow(
              label: loc.visualizerSettingsStaticFftSizeLabel,
              value: loc.visualizerSettingsStaticFftSizeValue,
              tooltip: loc.visualizerSettingsStaticFftSizeTooltip,
            ),
            const SizedBox(height: 12),

            _InfoRow(
              label: loc.visualizerSettingsStaticHopSizeLabel,
              value: loc.visualizerSettingsStaticHopSizeValue,
              tooltip: loc.visualizerSettingsStaticHopSizeTooltip,
            ),
            const SizedBox(height: 12),

            _InfoRow(
              label: loc.visualizerSettingsStaticSampleRateLabel,
              value: loc.visualizerSettingsStaticSampleRateValue,
              tooltip: loc.visualizerSettingsStaticSampleRateTooltip,
            ),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Divider(
                color: isDark ? app_theme.projectListCardBorder : app_theme.border,
                height: 1
              ),
            ),

            // Cache Status
            Text(
              loc.visualizerSettingsCacheTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            _CacheStatusWidget(_asset),
            const SizedBox(height: 12),

            // Clear Cache Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  visualizerService.clearCache();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(loc.visualizerSettingsClearCacheSnack))
                  );
                },
                icon: const Icon(Icons.delete_sweep, size: 18),
                label: Text(loc.visualizerSettingsClearCacheButton),
                style: ElevatedButton.styleFrom(
                  backgroundColor: app_theme.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Divider(
                color: isDark ? app_theme.projectListCardBorder : app_theme.border,
                height: 1
              ),
            ),

            // Performance Info
            Text(
              loc.visualizerSettingsPerformanceTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            _InfoRow(
              label: loc.visualizerSettingsRenderPipelineLabel,
              value: loc.visualizerSettingsRenderPipelineShader,
              tooltip: loc.visualizerSettingsRenderPipelineTooltip,
            ),

            const SizedBox(height: 24),

            // Info Footer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? app_theme.projectListCardBg : app_theme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? app_theme.projectListCardBorder : app_theme.border
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.visualizerSettingsFftAboutTitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    loc.visualizerSettingsFftAboutBody,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Dynamics Preset Row (horizontal scroll)
class DynamicsPresetRow extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset _asset;

  DynamicsPresetRow(this._asset);

  void _applyPreset(BuildContext context, String id) {
    final updated = VisualizerAsset.clone(_asset);

    switch (id) {
      case 'cinematic':
        updated.fftBands = 64;
        updated.smoothingAlpha = 0.6;
        updated.smoothness = 0.5;
        updated.reactivity = 0.9;
        updated.minFrequency = 40.0;
        updated.maxFrequency = 16000.0;
        break;
      case 'aggressive':
        updated.fftBands = 128;
        updated.smoothingAlpha = 0.5;
        updated.smoothness = 0.15;
        updated.reactivity = 1.4;
        updated.minFrequency = 50.0;
        updated.maxFrequency = 18000.0;
        break;
      case 'lofi':
        updated.fftBands = 48;
        updated.smoothingAlpha = 0.75;
        updated.smoothness = 0.7;
        updated.reactivity = 0.8;
        updated.minFrequency = 60.0;
        updated.maxFrequency = 12000.0;
        break;
      case 'bass':
        updated.fftBands = 64;
        updated.smoothingAlpha = 0.65;
        updated.smoothness = 0.4;
        updated.reactivity = 1.2;
        updated.minFrequency = 30.0;
        updated.maxFrequency = 9000.0;
        break;
      case 'vocal':
        updated.fftBands = 64;
        updated.smoothingAlpha = 0.6;
        updated.smoothness = 0.3;
        updated.reactivity = 1.1;
        updated.minFrequency = 180.0;
        updated.maxFrequency = 14000.0;
        break;
      default:
        return;
    }

    visualizerService.editingVisualizerAsset = updated;

    final loc = AppLocalizations.of(context);
    final presetLabel = id == 'cinematic'
        ? loc.visualizerSettingsPresetCinematic
        : id == 'aggressive'
            ? loc.visualizerSettingsPresetAggressive
            : id == 'lofi'
                ? loc.visualizerSettingsPresetLofi
                : id == 'bass'
                    ? loc.visualizerSettingsPresetBassHeavy
                    : loc.visualizerSettingsPresetVocalFocus;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          loc.visualizerSettingsPresetAppliedSnack(presetLabel),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              loc.visualizerSettingsPresetsTitle,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: loc.visualizerSettingsPresetsTooltip,
              child: Icon(
                Icons.info_outline,
                size: 14,
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildPresetButton(context, loc.visualizerSettingsPresetCinematic, 'cinematic'),
              const SizedBox(width: 8),
              _buildPresetButton(context, loc.visualizerSettingsPresetAggressive, 'aggressive'),
              const SizedBox(width: 8),
              _buildPresetButton(context, loc.visualizerSettingsPresetLofi, 'lofi'),
              const SizedBox(width: 8),
              _buildPresetButton(context, loc.visualizerSettingsPresetBassHeavy, 'bass'),
              const SizedBox(width: 8),
              _buildPresetButton(context, loc.visualizerSettingsPresetVocalFocus, 'vocal'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPresetButton(BuildContext context, String label, String id) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return OutlinedButton(
      onPressed: () => _applyPreset(context, id),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        side: BorderSide(
          color: isDark ? app_theme.projectListCardBorder : app_theme.border
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
        )
      ),
    );
  }
}

// Info Row Widget
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final String tooltip;

  _InfoRow({required this.label, required this.value, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: tooltip,
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Animation Smoothness Slider (spatial band smoothing)
class AnimationSmoothnessSlider extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset _asset;

  AnimationSmoothnessSlider(this._asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    double smooth = _asset.smoothness;
    // Eski projeler için default 0.6 değerini "kapalı" (0.0) gibi göster
    if ((smooth - 0.6).abs() < 0.001) smooth = 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              loc.visualizerSettingsAnimSmoothnessLabel,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: loc.visualizerSettingsAnimSmoothnessTooltip,
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: smooth.clamp(0.0, 1.0),
                min: 0.0,
                max: 1.0,
                divisions: 20,
                label: smooth.toStringAsFixed(2),
                activeColor: app_theme.accent,
                inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
                onChanged: (value) {
                  final updated = VisualizerAsset.clone(_asset)
                    ..smoothness = value;
                  visualizerService.editingVisualizerAsset = updated;
                },
              ),
            ),
            Text(
              smooth.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 14,
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Reactivity Slider (curve shaping)
class ReactivitySlider extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset _asset;

  ReactivitySlider(this._asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    double reactivity = _asset.reactivity.clamp(0.5, 2.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              loc.visualizerSettingsReactivityLabel,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: loc.visualizerSettingsReactivityTooltip,
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: reactivity,
                min: 0.5,
                max: 2.0,
                divisions: 15,
                label: reactivity.toStringAsFixed(2) + 'x',
                activeColor: app_theme.accent,
                inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
                onChanged: (value) {
                  final updated = VisualizerAsset.clone(_asset)
                    ..reactivity = value;
                  visualizerService.editingVisualizerAsset = updated;
                },
              ),
            ),
            Text(
              reactivity.toStringAsFixed(2) + 'x',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Cache Status Widget
class _CacheStatusWidget extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset _asset;

  _CacheStatusWidget(this._asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    bool hasCached =
        _asset.srcPath.isNotEmpty && visualizerService.hasCachedFFT(
          _asset.srcPath,
          asset: _asset,
        );
    final Color bgColor = hasCached ? app_theme.accent.withOpacity(0.15) : app_theme.error.withOpacity(0.15);
    final Color borderColor = hasCached ? app_theme.accent : app_theme.error;
    final Color iconColor = hasCached ? app_theme.accent : app_theme.error;
    final Color subtitleColor = isDark ? app_theme.darkTextSecondary : app_theme.textSecondary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        children: [
          Icon(
            hasCached ? Icons.check_circle : Icons.pending,
            color: iconColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasCached ? loc.visualizerSettingsCacheCachedTitle : loc.visualizerSettingsCacheProcessingTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasCached ? loc.visualizerSettingsCacheCachedSubtitle : loc.visualizerSettingsCacheProcessingSubtitle,
                  style: TextStyle(fontSize: 12, color: subtitleColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// FFT Bands Slider
class _FFTBandsSlider extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset _asset;

  _FFTBandsSlider(this._asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    int bands = _asset.fftBands;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              loc.visualizerSettingsFftBandsLabel,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: loc.visualizerSettingsFftBandsTooltip,
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: bands.toDouble(),
                min: 32,
                max: 128,
                divisions: 2,
                label: bands.toString(),
                activeColor: app_theme.accent,
                inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
                onChanged: (value) {
                  final updated = VisualizerAsset.clone(_asset)
                    ..fftBands = value.toInt();
                  visualizerService.editingVisualizerAsset = updated;
                },
              ),
            ),
            Text(
              loc.visualizerSettingsFftBandsValue(bands),
              style: TextStyle(
                fontSize: 14,
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Smoothing Slider
class _SmoothingSlider extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset _asset;

  _SmoothingSlider(this._asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    double alpha = _asset.smoothingAlpha;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              loc.visualizerSettingsSmoothingLabel,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: loc.visualizerSettingsSmoothingTooltip,
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: alpha,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                label: alpha.toStringAsFixed(2),
                activeColor: app_theme.accent,
                inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
                onChanged: (value) {
                  final updated = VisualizerAsset.clone(_asset)
                    ..smoothingAlpha = value;
                  visualizerService.editingVisualizerAsset = updated;
                },
              ),
            ),
            Text(
              'α = ${alpha.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Frequency Range Sliders
class _FrequencyRangeSliders extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset _asset;

  _FrequencyRangeSliders(this._asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    double minHz = _asset.minFrequency;
    double maxHz = _asset.maxFrequency;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              loc.visualizerSettingsFrequencyRangeLabel,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: loc.visualizerSettingsFrequencyRangeTooltip,
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Min Frequency
        Text(
          loc.visualizerSettingsFrequencyMinLabel(minHz.toInt()),
          style: TextStyle(
            fontSize: 14,
            color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
          ),
        ),
        Slider(
          value: minHz,
          min: 20,
          max: 500,
          divisions: 48,
          label: '${minHz.toInt()} Hz',
          activeColor: app_theme.accent,
          inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
          onChanged: (value) {
            if (value < maxHz) {
              final updated = VisualizerAsset.clone(_asset)
                ..minFrequency = value;
              visualizerService.editingVisualizerAsset = updated;
            }
          },
        ),

        const SizedBox(height: 8),

        // Max Frequency
        Text(
          loc.visualizerSettingsFrequencyMaxLabel(maxHz.toInt()),
          style: TextStyle(
            fontSize: 14,
            color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
          ),
        ),
        Slider(
          value: maxHz,
          min: 1000,
          max: 22000,
          divisions: 42,
          label: '${maxHz.toInt()} Hz',
          activeColor: app_theme.accent,
          inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
          onChanged: (value) {
            if (value > minHz) {
              final updated = VisualizerAsset.clone(_asset)
                ..maxFrequency = value;
              visualizerService.editingVisualizerAsset = updated;
            }
          },
        ),
      ],
    );
  }
}
