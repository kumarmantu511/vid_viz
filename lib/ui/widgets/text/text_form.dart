import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vidviz/l10n/generated/app_localizations.dart';
import 'package:vidviz/core/theme.dart' as app_theme;
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/model/text_asset.dart';
import 'package:vidviz/core/constants.dart';
import 'text_effect_form.dart';
import 'text_animation_form.dart';
import 'text_effect_player.dart';

class TextForm extends StatefulWidget {
  final TextAsset _asset;
  TextForm(this._asset, {Key? key}) : super(key: key);

  @override
  State<TextForm> createState() => _TextFormState();
}

class _TextFormState extends State<TextForm> {
  final directorService = locator.get<DirectorService>();
  int _tab = 0; // 0: Style, 1: Effects, 2: Animation

  @override
  Widget build(BuildContext context) {
    final asset = widget._asset;
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView( scrollDirection: Axis.vertical,child: _SubMenu(tabIndex: _tab, onChanged: (i) => setState(() => _tab = i))),

        Expanded(
          child: SingleChildScrollView(
            child: Container(
              color: isDark ? app_theme.projectListBg : app_theme.background,
              padding: const EdgeInsets.only(left: 16.0, top: 8.0,right: 16),
              width: MediaQuery.of(context).size.width - 120,
              child: Wrap(
                spacing: 0.0,
                runSpacing: 0.0,
                children: [
                  // Live preview (always visible) ön izlemye uygulandaı gerek yok
                 /// SizedBox(
                 ///   height: 70,
                 ///   child: _EffectPreview(asset)
                 /// ),

                  const SizedBox(height: 16),

                  // Style tab
                  if (_tab == 0) ...[
                    _FontFamily(asset),
                    const SizedBox(height: 12),
                    _buildSliderControl(loc.textStyleSizeLabel, math.sqrt(asset.fontSize), 0.3, 0.8, (v) {
                      TextAsset newAsset = TextAsset.clone(asset);
                      newAsset.fontSize = v * v;
                      directorService.editingTextAsset = newAsset;
                    }, isDark),
                    _buildSliderControl(loc.textStyleAlphaLabel, asset.alpha, 0.0, 1.0, (v) {
                      final a = TextAsset.clone(asset);
                      a.alpha = v;
                      directorService.editingTextAsset = a;
                    }, isDark),

                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _ColorField(
                          label: loc.textStyleTextColor,
                          field: 'fontColor',
                          color: asset.fontColor,
                          isDark: isDark,
                        ),
                        _ColorField(
                          label: loc.textStyleBoxColor,
                          field: 'boxcolor',
                          color: asset.boxcolor,
                          isDark: isDark,
                        ),
                      ],
                    ),

                    const Divider(height: 32),

                    _buildSectionTitle(loc.textStyleOutlineSection, isDark),
                    _buildSliderControl(loc.textStyleOutlineWidth, asset.borderw, 0.0, 8.0, (v) {
                      final a = TextAsset.clone(asset);
                      a.borderw = v;
                      directorService.editingTextAsset = a;
                    }, isDark),
                    _ColorField(
                      label: loc.textStyleOutlineColor,
                      field: 'bordercolor',
                      color: asset.bordercolor,
                      isDark: isDark,
                    ),

                    const Divider(height: 32),

                    _buildSectionTitle(loc.textStyleShadowGlowSection, isDark),
                    _buildSliderControl(loc.textStyleShadowBlur, asset.shadowBlur, 0.0, 20.0, (v) {
                      final a = TextAsset.clone(asset);
                      a.shadowBlur = v;
                      directorService.editingTextAsset = a;
                    }, isDark),

                    _buildSliderControl(loc.textStyleShadowOffsetX, asset.shadowx, -40.0, 40.0, (v) {
                      final a = TextAsset.clone(asset);
                      a.shadowx = v;
                      directorService.editingTextAsset = a;
                    }, isDark),

                    const SizedBox(width: 16),

                    _buildSliderControl(loc.textStyleShadowOffsetY, asset.shadowy, -40.0, 40.0, (v) {
                      final a = TextAsset.clone(asset);
                      a.shadowy = v;
                      directorService.editingTextAsset = a;
                    }, isDark),

                    _buildSliderControl(loc.textStyleGlowRadius, asset.glowRadius, 0.0, 30.0, (v) {
                      final a = TextAsset.clone(asset);
                      a.glowRadius = v;
                      directorService.editingTextAsset = a;
                    }, isDark),
                    Wrap(
                      spacing: 16,
                      children: [
                        _ColorField(
                          label: loc.textStyleShadowColor,
                          field: 'shadowcolor',
                          color: asset.shadowcolor,
                          isDark: isDark,
                        ),
                        _ColorField(
                          label: loc.textStyleGlowColor,
                          field: 'glowColor',
                          color: asset.glowColor,
                          isDark: isDark,
                        ),
                      ],
                    ),
                    const Divider(height: 32),

                    _buildSectionTitle(loc.textStyleBoxBackgroundSection, isDark),
                    _BoxToggle(asset, isDark),

                    _buildSliderControl('Box Padding', asset.boxPad, 0.0, 30.0, (v) {
                      final a = TextAsset.clone(asset);
                      a.boxPad = v;
                      directorService.editingTextAsset = a;
                    }, isDark),

                    _buildSliderControl(loc.textStyleBoxBorderWidth, asset.boxborderw, 0.0, 8.0, (v) {
                      final a = TextAsset.clone(asset);
                      a.boxborderw = v;
                      directorService.editingTextAsset = a;
                    }, isDark),

                    _buildSliderControl(loc.textStyleBoxCornerRadius, asset.boxRadius, 0.0, 50.0, (v) {
                      final a = TextAsset.clone(asset);
                      a.boxRadius = v;
                      directorService.editingTextAsset = a;
                    }, isDark),

                    const SizedBox(height: 20),
                  ],

                  // Effects tab
                  if (_tab == 1)
                    TextEffectForm(asset),

                  // Animation tab
                  if (_tab == 2)
                  //  Container(
                     // width: MediaQuery.of(context).size.width - 160,
                    Expanded(child: TextAnimationForm(asset)),
                   // ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title, 
        style: TextStyle(
          fontSize: 16, 
          fontWeight: FontWeight.w600,
          color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary
        )
      ),
    );
  }

  Widget _buildSliderControl(String label, double value, double min, double max, Function(double) onChanged, bool isDark) {
    final double safeValue = (value.isFinite ? value : min).clamp(min, max);
    return Row(
      children: [
        SizedBox(
          width: 90,
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
    );
  }
}

/// Text efekt önizleme widget'ı - Sabit boyut, accent renk
class EffectPreview extends StatelessWidget {
  final TextAsset asset;
  const EffectPreview(this.asset);

  // Sabit boyutlar
  static const double _height = 50.0;
  static const double _previewWidth = 280.0;
  static const double _padding = 12.0;
  static const double _radius = 4.0;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Container(
      height: _height,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: _padding),
      decoration: BoxDecoration(
        color: app_theme.accent.withOpacity(0.15),
        border: Border.all(color: app_theme.accent.withOpacity(0.3), width: 1),
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: Row(
        children: [
          // Label
          Text(
            loc.textStylePreviewLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: app_theme.accent,
            ),
          ),
          const SizedBox(width: 16),
          // Preview area
          Expanded(
            child: ClipRect(
              child: SizedBox(
                height: _height - _padding,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: TextEffectPlayer(
                    _buildPreviewAsset(),
                    playerWidth: _previewWidth,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextAsset _buildPreviewAsset() {
    final previewAsset = TextAsset.clone(asset);
    previewAsset.fontSize = 0.12;
    return previewAsset;
  }
}

class _SubMenu extends StatelessWidget {
  final int tabIndex;
  final ValueChanged<int> onChanged;
  _SubMenu({required this.tabIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    
    Color getColor(int i) => tabIndex == i
        ? app_theme.accent
        : (isDark ? app_theme.darkTextSecondary : app_theme.textSecondary);
        
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
          IconButton(
            tooltip: loc.textStyleSubmenuStyleTooltip,
            icon: Icon(Icons.text_format, color: getColor(0)),
            onPressed: () => onChanged(0),
          ),
          IconButton(
            tooltip: loc.textStyleSubmenuEffectsTooltip,
            icon: Icon(Icons.auto_awesome, color: getColor(1)),
            onPressed: () => onChanged(1),
          ),
          IconButton(
            tooltip: loc.textStyleSubmenuAnimationTooltip,
            icon: Icon(Icons.movie_filter, color: getColor(2)),
            onPressed: () => onChanged(2),
          ),
        ],
      ),
    );
  }
}

class _FontFamily extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final TextAsset _asset;

  _FontFamily(this._asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            loc.textStyleFontLabel,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
            )
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? app_theme.projectListCardBg : app_theme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? app_theme.projectListCardBorder : app_theme.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton(
                isExpanded: true,
                dropdownColor: isDark ? app_theme.projectListCardBg : app_theme.surface,
                value: (directorService.editingTextAsset != null) ? Font.getByPath(directorService.editingTextAsset!.font) : Font.allFonts[0],
                items: Font.allFonts.map((Font font) => DropdownMenuItem(
                  value: font,
                  child: Text(
                    font.title!,
                    style: TextStyle(
                      fontFamily: font.family,
                      fontSize: 14,
                      color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                      fontWeight: font.weight,
                    ),
                  ),
                )).toList(),
                onChanged: (font) {
                  TextAsset newAsset = TextAsset.clone(_asset);
                  newAsset.font = font!.path!;
                  directorService.editingTextAsset = newAsset;
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 16), // Sağ taraftan biraz boşluk
      ],
    );
  }
}

class _ColorField extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final String label;
  final String field;
  final int? color;
  final bool isDark;

  _ColorField({
    required this.label,
    required this.field,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            directorService.editingColor = field;
          },
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Color(color ?? 0),
              border: Border.all(
                color: isDark ? app_theme.projectListCardBorder : app_theme.border,
                width: 1,
              ),
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

class _BoxToggle extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final TextAsset _asset;
  final bool isDark;
  
  _BoxToggle(this._asset, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            AppLocalizations.of(context).textStyleEnableBoxLabel,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
            ),
          ),
        ),
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: _asset.box,
            activeColor: app_theme.accent,
            onChanged: (v) {
              final a = TextAsset.clone(_asset);
              a.box = v;
              directorService.editingTextAsset = a;
            },
          ),
        ),
      ],
    );
  }
}
