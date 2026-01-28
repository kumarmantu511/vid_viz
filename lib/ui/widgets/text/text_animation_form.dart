import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:vidviz/l10n/generated/app_localizations.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/model/text_asset.dart';
import 'package:vidviz/core/theme.dart' as app_theme;
import 'text_effect_player.dart';

class TextAnimationForm extends StatefulWidget {
  final TextAsset asset;
  TextAnimationForm(this.asset, {Key? key}) : super(key: key);

  @override
  State<TextAnimationForm> createState() => _TextAnimationFormState();
}

class _TextAnimationFormState extends State<TextAnimationForm> with SingleTickerProviderStateMixin {

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

  // Pretty label for animation keys (e.g., 'slide_lr' -> localized label)
  String _prettyAnim(String key) {
    final loc = AppLocalizations.of(context);
    final map = {
      'type_delete': loc.textAnimNameTypeDelete,
      'slide_lr': loc.textAnimNameSlideLr,
      'slide_rl': loc.textAnimNameSlideRl,
      'shake_h': loc.textAnimNameShakeH,
      'shake_v': loc.textAnimNameShakeV,
      'scan_rl': loc.textAnimNameScanRl,
      'sweep_lr_rl': loc.textAnimNameSweepLrRl,
      'glow_pulse': loc.textAnimNameGlowPulse,
      'outline_pulse': loc.textAnimNameOutlinePulse,
      'shadow_swing': loc.textAnimNameShadowSwing,
      'fade_in': loc.textAnimNameFadeIn,
      'zoom_in': loc.textAnimNameZoomIn,
      'slide_up': loc.textAnimNameSlideUp,
      'blur_in': loc.textAnimNameBlurIn,
      'scramble_letters': loc.textAnimNameScramble,
      'flip_x': loc.textAnimNameFlipX,
      'flip_y': loc.textAnimNameFlipY,
      'pop_in': loc.textAnimNamePopIn,
      'rubber_band': loc.textAnimNameRubberBand,
      'wobble': loc.textAnimNameWobble,
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
    
    final animTypes = const <String>[
      'none',
      'typing',
      'type_delete',
      'wave',
      'bounce',
      'jitter',
      'flicker',
      'scan',
      'scan_rl',
      'sweep_lr_rl',
      'marquee',
      'pulse',
      'slide_lr',
      'slide_rl',
      'shake_h',
      'shake_v',
      'rotate',
      'blink',
      'glow_pulse',
      'outline_pulse',
      'shadow_swing',
      'fade_in',
      'zoom_in',
      'slide_up',
      'blur_in',
      'scramble_letters',
      'flip_x',
      'flip_y',
      'pop_in',
      'rubber_band',
      'wobble',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              loc.textAnimHeader,
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
        if (_mode == 0)_buildAnimGrid(context, asset, animTypes, isDark)
        else _buildAnimCarousel(context, asset, animTypes, isDark),

        const SizedBox(height: 12),
        // Controls
        _buildSliderControl(loc.textAnimSpeedLabel, asset.animSpeed, 0.2, 2.0, (v) => _update((a) => a.animSpeed = v), isDark),
        _buildSliderControl(loc.textAnimAmplitudeLabel, asset.animAmplitude, 0.0, 40.0, (v) => _update((a) => a.animAmplitude = v), isDark),
        _buildSliderControl(loc.textAnimPhaseLabel, asset.animPhase, 0.0, 6.2831, (v) => _update((a) => a.animPhase = v), isDark),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label, 
              style: TextStyle(
                fontSize: 14,
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
              )
            ),
          ),
          Expanded(
            child: Slider(
              min: min,
              max: max,
              value: safeValue,
              activeColor: app_theme.accent,
              inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
              onChanged: (v) => onChanged(v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimGrid(BuildContext context, TextAsset base, List<String> anims, bool isDark,) {
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
      children: anims.map((name) => _buildAnimCard(name, base, itemW - 20, isDark)).toList(),
    );
  }

  Widget _buildAnimCarousel(BuildContext context, TextAsset base, List<String> anims, bool isDark,) {
    const double itemW = 100.0;
    const double itemH = 40.0; // Biraz yükseklik artırdım rahat görünsün diye
    final double previewW = itemW - 20;
    
    return SizedBox(
      height: itemH,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: anims.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => _buildAnimCard(anims[i], base, previewW, isDark, width: itemW),
      ),
    );
  }

  Widget _buildAnimCard(String name, TextAsset base, double playerWidth, bool isDark, {double? width}) {
    final isSelected = name == base.animType;
    
    final clone = TextAsset.clone(base);
    clone.animType = name;
    // Reset decorations to keep previews consistent per card
    clone.box = false;
    clone.alpha = 1.0;
    clone.glowRadius = 0;
    clone.glowColor = base.glowColor;
    clone.shadowBlur = 0;
    clone.shadowx = 0;
    clone.shadowy = 0;
    clone.borderw = 0;
    // preview tuning
    clone.animSpeed = 1.0;
    clone.animAmplitude =
    name.contains('shake') ? 6.0 : (name == 'bounce' ? 8.0 : (name == 'slide_up' ? 30.0 : (name == 'wobble' ? 10.0 : (name == 'rubber_band' ? 8.0 : base.animAmplitude))));

    final pretty = _prettyAnim(name);
    clone.title = pretty;
    clone.fontSize = 0.22;

    return GestureDetector(
      onTap: () => _update((a) => a.animType = name),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: isSelected ? app_theme.accent.withOpacity(0.2) : (isDark ? app_theme.projectListCardBg : app_theme.surface),
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
