import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:vidviz/l10n/generated/app_localizations.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/model/text_asset.dart';
import 'package:vidviz/core/theme.dart' as app_theme;
import 'text_effect_player.dart';

class TextEffectForm extends StatefulWidget {
  final TextAsset asset;
  TextEffectForm(this.asset, {Key? key}) : super(key: key);

  @override
  State<TextEffectForm> createState() => _TextEffectFormState();
}

class _TextEffectFormState extends State<TextEffectForm>
    with SingleTickerProviderStateMixin {
  final directorService = locator.get<DirectorService>();
  late final Ticker _ticker;
  double _time = 0.0;
  // 0: Grid, 1: Carousel
  int _mode = 1; // default to carousel

  void _update(void Function(TextAsset a) f) {
    final a = TextAsset.clone(widget.asset);
    f(a);
    directorService.editingTextAsset = a;
  }

  // Apply preset values to an asset
  void _applyPreset(TextAsset a, String key) {
    switch (key) {
      case 'neon':
        a.effectType = 'neon_glow';
        a.effectIntensity = 0.7;
        a.effectSpeed = 1.0;
        a.effectAngle = 0.0;
        a.effectThickness = 0.8;
        a.effectColorA = 0xFFFF005E;
        a.effectColorB = 0xFF00D4FF;
        a.glowRadius = 12.0;
        a.glowColor = 0xFF00D4FF;
        break;
      case 'rainbow':
        a.effectType = 'rainbow_fill';
        a.effectSpeed = 0.8;
        a.effectThickness = 0.4;
        a.effectAngle = 15.0;
        a.effectIntensity = 0.8;
        a.glowRadius = 8.0;
        a.glowColor = 0xFFFFFFFF;
        break;
      case 'metal':
        a.effectType = 'metallic_fill';
        a.effectIntensity = 0.6;
        a.effectSpeed = 0.6;
        a.effectThickness = 0.6;
        a.effectAngle = 0.0;
        a.effectColorA = 0xFFB0B0B0;
        a.effectColorB = 0xFFE0E0E0;
        a.glowRadius = 6.0;
        a.glowColor = 0xFFFFFFFF;
        break;
      case 'wave':
        a.effectType = 'wave_fill';
        a.effectIntensity = 0.7;
        a.effectSpeed = 0.9;
        a.effectThickness = 1.1;
        a.effectAngle = 30.0;
        a.effectColorA = 0xFF00C2FF;
        a.effectColorB = 0xFFE54CFF;
        a.glowRadius = 10.0;
        a.glowColor = 0xFF00C2FF;
        break;
      case 'glitch':
        a.effectType = 'glitch_fill';
        a.effectIntensity = 0.9;
        a.effectSpeed = 1.2;
        a.effectThickness = 0.8;
        a.effectAngle = 0.0;
        a.effectColorA = 0xFF00FF8C;
        a.effectColorB = 0xFFFFC640;
        a.glowRadius = 0.0;
        break;
    }
  }

  Widget _buildPresetCarousel(BuildContext context, TextAsset base, bool isDark) {
    final loc = AppLocalizations.of(context);
    final presets = [
      {'key': 'neon', 'label': loc.textEffectPresetNeon},
      {'key': 'rainbow', 'label': loc.textEffectPresetRainbow},
      {'key': 'metal', 'label': loc.textEffectPresetMetal},
      {'key': 'wave', 'label': loc.textEffectPresetWave},
      {'key': 'glitch', 'label': loc.textEffectPresetGlitch},
    ];
    const double itemW = 110.0;
    const double itemH = 40.0;
    final double previewW = itemW - 20;
    
    return SizedBox(
      height: itemH,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: presets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final key = presets[i]['key']!;
          final label = presets[i]['label']!;
          final clone = TextAsset.clone(base);
          clone.box = false;
          clone.alpha = 1.0;
          clone.glowRadius = 0;
          clone.shadowBlur = 0;
          clone.shadowx = 0;
          clone.shadowy = 0;
          clone.borderw = 0;
          _applyPreset(clone, key);
          clone.title = label;
          clone.fontSize = 0.22;
          
          return GestureDetector(
            onTap: () => _update((a) => _applyPreset(a, key)),
            child: Container(
              width: itemW,
              decoration: BoxDecoration(
                color: isDark ? app_theme.projectListCardBg : app_theme.surface,
                border: Border.all(color: isDark ? app_theme.projectListCardBorder : app_theme.border),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  )
                ],
              ),
              clipBehavior: Clip.hardEdge,
              padding: const EdgeInsets.all(6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: TextEffectPlayer(
                    clone,
                    playerWidth: previewW,
                    timeSecOverride: _time,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Pretty label for effect keys (e.g., 'neon_glow' -> localized preset name)
  String _prettyEffect(String key) {
    final loc = AppLocalizations.of(context);
    final map = {
      'gradient_fill': loc.textEffectNameGradient,
      'wave_fill': loc.textEffectNameWave,
      'glitch_fill': loc.textEffectNameGlitch,
      'neon_glow': loc.textEffectNameNeon,
      'metallic_fill': loc.textEffectNameMetal,
      'rainbow_fill': loc.textEffectNameRainbow,
      'chrome_bevel': loc.textEffectNameChrome,
      'scanlines': loc.textEffectNameScanlines,
      'rgb_shift': loc.textEffectNameRgbShift,
      'duotone_map': loc.textEffectNameDuotone,
      'holo_scan': loc.textEffectNameHolo,
      'noise_flow': loc.textEffectNameNoiseFlow,
      'sparkle_glint': loc.textEffectNameSparkle,
      'liquid_distort': loc.textEffectNameLiquid,
      'inner_glow': loc.textEffectNameInnerGlow,
      'inner_shadow': loc.textEffectNameInnerShadow,
      'none': loc.textEffectNameNone,
    };
    if (map.containsKey(key)) return map[key]!;
    return key.replaceAll('_', ' ').toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if (!mounted) return;
      setState(() => _time = elapsed.inMicroseconds / 1e6);
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    
    final effectTypes = const <String>[
      'none',
      'gradient_fill',
      'wave_fill',
      'glitch_fill',
      'neon_glow',
      'metallic_fill',
      'rainbow_fill',
      'chrome_bevel',
      'scanlines',
      'rgb_shift',
      'duotone_map',
      'holo_scan',
      'noise_flow',
      'sparkle_glint',
      'liquid_distort',
      'inner_glow',
      'inner_shadow',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [


        // Header with toggle
        Row(
          children: [
            Text(
              loc.textEffectHeader,
              style: TextStyle(
                fontSize: 16, 
                fontWeight: FontWeight.w600,
                color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary
              ),
            ),
            const Spacer(),
            Container(
              decoration: BoxDecoration(
                color: isDark ? app_theme.projectListCardBg : app_theme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? app_theme.projectListCardBorder : app_theme.border),
              ),
              padding: const EdgeInsets.all(2),
              child: Row(
                children: [
                  _buildViewModeButton(Icons.grid_view_rounded, 0, isDark),
                  _buildViewModeButton(Icons.view_carousel_rounded, 1, isDark),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Presets as live preview carousel
        Padding(
          padding: const EdgeInsets.only(bottom: 0.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  loc.textEffectPresetHeader,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary
                  ),
                ),
              ),
              _buildPresetCarousel(context, asset, isDark),
            ],
          ),
        ),
        const Divider(height: 32),

        if (_mode == 0)
          _buildEffectGrid(context, asset, effectTypes, isDark)

        else
          _buildEffectCarousel(context, asset, effectTypes, isDark),

        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _ColorChip(
              label: 'A',
              color: asset.effectColorA,
              isDark: isDark,
              onTap: () {
                directorService.editingColor = 'effectColorA';
              },
            ),
            _ColorChip(
              label: 'B',
              color: asset.effectColorB,
              isDark: isDark,
              onTap: () {
                directorService.editingColor = 'effectColorB';
              },
            ),
          ],
        ),

        const SizedBox(height: 16),
        _buildSliderControl(loc.textEffectStrengthLabel, asset.effectIntensity, 0.0, 1.0, (v) => _update((a) => a.effectIntensity = v), isDark),
        _buildSliderControl(loc.textEffectSpeedLabel, asset.effectSpeed, 0.2, 2.0, (v) => _update((a) => a.effectSpeed = v), isDark),
        _buildSliderControl(loc.textEffectAngleLabel, asset.effectAngle, 0.0, 360.0, (v) => _update((a) => a.effectAngle = v), isDark),
        _buildSliderControl(loc.textEffectThicknessLabel, asset.effectThickness, 0.0, 3.0, (v) => _update((a) => a.effectThickness = v), isDark),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildViewModeButton(IconData icon, int modeIndex, bool isDark) {
    final isSelected = _mode == modeIndex;
    return InkWell(
      onTap: () => setState(() => _mode = modeIndex),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? app_theme.accent.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isSelected ? app_theme.accent : (isDark ? app_theme.darkTextSecondary : app_theme.textSecondary),
        ),
      ),
    );
  }

  Widget _buildSliderControl(String label, double value, double min, double max, Function(double) onChanged, bool isDark) {
    final double safeValue = (value.isFinite ? value : min).clamp(min, max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 0),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14, 
              fontWeight: FontWeight.w600,
              color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 30,
                child: Slider(
                  min: min,
                  max: max,
                  value: safeValue,
                  activeColor: app_theme.accent,
                  inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
                  onChanged: (v) => onChanged(v),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEffectGrid(
    BuildContext context,
    TextAsset base,
    List<String> effects,
    bool isDark,
  ) {
    final width = MediaQuery.of(context).size.width - 180; 
    final itemW = 110.0;
    final cross = width ~/ itemW;
    
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: cross.clamp(2, 6),
      childAspectRatio: 3.5,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: effects.map((name) => _buildEffectCard(name, base, itemW - 20, isDark)).toList(),
    );
  }

  Widget _buildEffectCarousel(
    BuildContext context,
    TextAsset base,
    List<String> effects,
    bool isDark,
  ) {
    const double itemW = 110.0;
    const double itemH = 40.0;
    final double previewW = itemW - 20;
    
    return SizedBox(
      height: itemH,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: effects.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => _buildEffectCard(effects[i], base, previewW, isDark, width: itemW),
      ),
    );
  }

  Widget _buildEffectCard(String name, TextAsset base, double playerWidth, bool isDark, {double? width}) {
    final isSelected = name == base.effectType;
    final clone = TextAsset.clone(base);
    clone.effectType = name;
    clone.box = false;
    clone.alpha = 1.0;
    clone.shadowBlur = 0;
    clone.shadowx = 0;
    clone.shadowy = 0;
    clone.borderw = 0;
    clone.glowRadius = 0;
    clone.glowColor = base.glowColor;
    
    // Preview defaults
    if (name == 'neon_glow') {
      clone.effectIntensity = 0.8;
      clone.effectColorA = 0xFFFF0066;
      clone.effectColorB = 0xFF00D4FF;
    } else if (name == 'rainbow_fill') {
      clone.effectSpeed = 0.8;
      clone.effectThickness = 0.6;
    } else if (name == 'metallic_fill') {
      clone.effectColorA = 0xFFB0B0B0;
      clone.effectColorB = 0xFFE0E0E0;
      clone.effectIntensity = 0.6;
    } else if (name == 'glitch_fill') {
      clone.effectIntensity = 0.9;
    } else if (name == 'chrome_bevel') {
      clone.effectIntensity = 0.7;
      clone.effectThickness = 1.0;
      clone.effectAngle = 20.0;
      clone.effectColorA = 0xFFB8E1FF;
      clone.effectColorB = 0xFF5B7DB1;
    } else if (name == 'scanlines') {
      clone.effectIntensity = 0.6;
      clone.effectSpeed = 0.8;
      clone.effectThickness = 0.5;
      clone.effectColorA = 0xFFFFFFFF;
      clone.effectColorB = 0xFFAAAAAA;
    } else if (name == 'rgb_shift') {
      clone.effectIntensity = 0.8;
      clone.effectSpeed = 1.0;
      clone.effectAngle = 0.0;
      clone.effectColorA = 0xFFFFFFFF;
      clone.effectColorB = 0xFFFFFFFF;
    } else if (name == 'duotone_map') {
      clone.effectIntensity = 0.8;
      clone.effectSpeed = 1.0;
      clone.effectAngle = 30.0;
      clone.effectThickness = 0.3;
      clone.effectColorA = 0xFF00C2FF;
      clone.effectColorB = 0xFFFF8A00;
    } else if (name == 'holo_scan') {
      clone.effectIntensity = 0.8;
      clone.effectSpeed = 1.0;
      clone.effectColorA = 0xFF00D4FF;
      clone.effectColorB = 0xFF7A7AFF;
    } else if (name == 'noise_flow') {
      clone.effectIntensity = 0.6;
      clone.effectSpeed = 0.9;
      clone.effectThickness = 0.6;
      clone.effectColorA = 0xFFFFFFFF;
      clone.effectColorB = 0xFFDDDDDD;
    } else if (name == 'sparkle_glint') {
      clone.effectIntensity = 0.7;
      clone.effectSpeed = 1.2;
      clone.effectThickness = 0.6;
      clone.effectColorA = 0xFFFFFFFF;
      clone.effectColorB = 0xFFB0B0B0;
    } else if (name == 'liquid_distort') {
      clone.effectIntensity = 0.7;
      clone.effectSpeed = 0.9;
      clone.effectThickness = 0.8;
      clone.effectColorA = 0xFF4CD9FF;
      clone.effectColorB = 0xFF9B6BFF;
    } else if (name == 'inner_glow') {
      clone.glowRadius = 6.0;
      clone.glowColor = base.glowColor;
    } else if (name == 'inner_shadow') {
      clone.shadowBlur = 6.0;
      clone.shadowx = 2.0;
      clone.shadowy = 2.0;
      clone.shadowcolor = 0x99000000;
    }
    
    final pretty = _prettyEffect(name);
    clone.title = pretty;
    clone.fontSize = 0.22;

    return GestureDetector(
      onTap: () => _update((a) => a.effectType = name),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: isSelected 
              ? app_theme.accent.withOpacity(0.2) 
              : (isDark ? app_theme.projectListCardBg : app_theme.surface),
          border: Border.all(
            color: isSelected ? app_theme.accent : (isDark ? app_theme.projectListCardBorder : app_theme.border),
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected ? [] : [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            )
          ],
        ),
        clipBehavior: Clip.hardEdge,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: TextEffectPlayer(
              clone,
              playerWidth: playerWidth,
              timeSecOverride: _time,
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  final String label;
  final int color;
  final VoidCallback onTap;
  final bool isDark;
  
  const _ColorChip({
    required this.label,
    required this.color,
    required this.onTap,
    required this.isDark,
  });
  
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${loc.textColorLabel} $label:',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
          )
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Color(color),
              border: Border.all(color: isDark ? app_theme.projectListCardBorder : app_theme.border, width: 1),
              borderRadius: BorderRadius.circular(6), // Yuvarlak renk seçici
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2)
              ],
            ),
          ),
        ),
      ],
    );
  }
}
