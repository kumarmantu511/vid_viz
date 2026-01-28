import 'package:flutter/material.dart';
import 'package:vidviz/l10n/generated/app_localizations.dart';
import 'package:vidviz/core/theme.dart' as app_theme;
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/service/shader_effect_service.dart';
import 'package:vidviz/model/shader_effect.dart';

/// ShaderEffectForm - Shader effect parametrelerini düzenleme formu
class ShaderEffectForm extends StatefulWidget {
  final ShaderEffectAsset asset;

  ShaderEffectForm(this.asset);

  @override
  _ShaderEffectFormState createState() => _ShaderEffectFormState();
}

class _ShaderEffectFormState extends State<ShaderEffectForm> {
  final directorService = locator.get<DirectorService>();
  final shaderEffectService = locator.get<ShaderEffectService>();

  String _selectedShaderType = ShaderEffectType.rain;
  bool _isFilterMode = false; // false: Effects, true: Filters

  String _shaderTypeDisplayName(AppLocalizations loc, String type) {
    switch (type) {
      case ShaderEffectType.rain:
        return loc.shaderEffectTypeRainName;
      case ShaderEffectType.rainGlass:
        return loc.shaderEffectTypeRainGlassName;
      case ShaderEffectType.snow:
        return loc.shaderEffectTypeSnowName;
      case ShaderEffectType.water:
        return loc.shaderEffectTypeWaterName;
      case ShaderEffectType.halfTone:
        return loc.shaderEffectTypeHalftoneName;
      case ShaderEffectType.tiles:
        return loc.shaderEffectTypeTilesName;
      case ShaderEffectType.circleRadius:
        return loc.shaderEffectTypeCircleRadiusName;
      case ShaderEffectType.dunes:
        return loc.shaderEffectTypeDunesName;
      case ShaderEffectType.heatVision:
        return loc.shaderEffectTypeHeatVisionName;
      case ShaderEffectType.spectrum:
        return loc.shaderEffectTypeSpectrumName;
      case ShaderEffectType.waveWater:
        return loc.shaderEffectTypeWaveWaterName;
      case ShaderEffectType.water2d:
        return loc.shaderEffectTypeWater2dName;
      case ShaderEffectType.sphere:
        return loc.shaderEffectTypeSphereName;
      case ShaderEffectType.fishe:
        return loc.shaderEffectTypeFisheName;
      case ShaderEffectType.hdBoost:
        return loc.shaderEffectTypeHdBoostName;
      case ShaderEffectType.sharpenFx:
        return loc.shaderEffectTypeSharpenName;
      case ShaderEffectType.edgeDetect:
        return loc.shaderEffectTypeEdgeDetectName;
      case ShaderEffectType.pixelate:
        return loc.shaderEffectTypePixelateName;
      case ShaderEffectType.posterize:
        return loc.shaderEffectTypePosterizeName;
      case ShaderEffectType.chromAberration:
        return loc.shaderEffectTypeChromAberrationName;
      case ShaderEffectType.crt:
        return loc.shaderEffectTypeCrtName;
      case ShaderEffectType.swirl:
        return loc.shaderEffectTypeSwirlName;
      case ShaderEffectType.fisheye:
        return loc.shaderEffectTypeFisheyeName;
      case ShaderEffectType.zoomBlur:
        return loc.shaderEffectTypeZoomBlurName;
      case ShaderEffectType.filmGrain:
        return loc.shaderEffectTypeFilmGrainName;
      case ShaderEffectType.blur:
        return loc.shaderEffectTypeBlurName;
      case ShaderEffectType.vignette:
        return loc.shaderEffectTypeVignetteName;
      default:
        return ShaderEffectType.getDisplayName(type);
    }
  }

  String _shaderTypeDescription(AppLocalizations loc, String type) {
    switch (type) {
      case ShaderEffectType.rain:
        return loc.shaderEffectTypeRainDesc;
      case ShaderEffectType.rainGlass:
        return loc.shaderEffectTypeRainGlassDesc;
      case ShaderEffectType.snow:
        return loc.shaderEffectTypeSnowDesc;
      case ShaderEffectType.water:
        return loc.shaderEffectTypeWaterDesc;
      case ShaderEffectType.halfTone:
        return loc.shaderEffectTypeHalftoneDesc;
      case ShaderEffectType.tiles:
        return loc.shaderEffectTypeTilesDesc;
      case ShaderEffectType.circleRadius:
        return loc.shaderEffectTypeCircleRadiusDesc;
      case ShaderEffectType.dunes:
        return loc.shaderEffectTypeDunesDesc;
      case ShaderEffectType.heatVision:
        return loc.shaderEffectTypeHeatVisionDesc;
      case ShaderEffectType.spectrum:
        return loc.shaderEffectTypeSpectrumDesc;
      case ShaderEffectType.waveWater:
        return loc.shaderEffectTypeWaveWaterDesc;
      case ShaderEffectType.water2d:
        return loc.shaderEffectTypeWater2dDesc;
      case ShaderEffectType.sphere:
        return loc.shaderEffectTypeSphereDesc;
      case ShaderEffectType.fishe:
        return loc.shaderEffectTypeFisheDesc;
      case ShaderEffectType.hdBoost:
        return loc.shaderEffectTypeHdBoostDesc;
      case ShaderEffectType.sharpenFx:
        return loc.shaderEffectTypeSharpenDesc;
      case ShaderEffectType.edgeDetect:
        return loc.shaderEffectTypeEdgeDetectDesc;
      case ShaderEffectType.pixelate:
        return loc.shaderEffectTypePixelateDesc;
      case ShaderEffectType.posterize:
        return loc.shaderEffectTypePosterizeDesc;
      case ShaderEffectType.chromAberration:
        return loc.shaderEffectTypeChromAberrationDesc;
      case ShaderEffectType.crt:
        return loc.shaderEffectTypeCrtDesc;
      case ShaderEffectType.swirl:
        return loc.shaderEffectTypeSwirlDesc;
      case ShaderEffectType.fisheye:
        return loc.shaderEffectTypeFisheyeDesc;
      case ShaderEffectType.zoomBlur:
        return loc.shaderEffectTypeZoomBlurDesc;
      case ShaderEffectType.filmGrain:
        return loc.shaderEffectTypeFilmGrainDesc;
      case ShaderEffectType.blur:
        return loc.shaderEffectTypeBlurDesc;
      case ShaderEffectType.vignette:
        return loc.shaderEffectTypeVignetteDesc;
      default:
        return ShaderEffectType.getDescription(type);
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedShaderType = widget.asset.type;
    // Initialize mode based on incoming type
    if (ShaderEffectType.filterTypes.contains(_selectedShaderType)) {
      _isFilterMode = true;
    } else {
      _isFilterMode = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Text editor gibi tasarım: Sol SubMenu + Sağ Kontroller
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sol: SubMenu (Text editor'daki gibi)
        SingleChildScrollView( scrollDirection: Axis.vertical,child: _buildSubMenu()),
        // Sağ: Kontroller (Text editor gibi Wrap ile) - SingleChildScrollView eklendi
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
                  _buildShaderTypeSelector(),
                  ..._buildParameterControlsList(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

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
     // padding: const EdgeInsets.only(right: 8),
      child: Column(
        children: [
          // Effects toggle
          IconButton(
            icon: Icon(
              Icons.auto_awesome,
              color: !_isFilterMode ? app_theme.accent : (isDark ? app_theme.darkTextSecondary : app_theme.textSecondary),
            ),
            tooltip: loc.shaderSubmenuEffectsTooltip,
            onPressed: () {
              if (_isFilterMode) {
                setState(() {
                  _isFilterMode = false;
                  // Ensure selection is valid for effects list
                  final list = ShaderEffectType.effectTypes;
                  if (!list.contains(_selectedShaderType)) {
                    _selectedShaderType = list.first;
                    shaderEffectService.changeShaderType(_selectedShaderType);
                  }
                });
              }
            },
          ),
          const SizedBox(height: 8),
          // Filters toggle
          IconButton(
            icon: Icon(
              Icons.tune,
              color: _isFilterMode ? app_theme.accent : (isDark ? app_theme.darkTextSecondary : app_theme.textSecondary),
            ),
            tooltip: loc.shaderSubmenuFiltersTooltip,
            onPressed: () {
              if (!_isFilterMode) {
                setState(() {
                  _isFilterMode = true;
                  // Ensure selection is valid for filters list
                  final list = ShaderEffectType.filterTypes;
                  if (!list.contains(_selectedShaderType)) {
                    _selectedShaderType = list.first;
                    shaderEffectService.changeShaderType(_selectedShaderType);
                  }
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildShaderTypeSelector() {
    final loc = AppLocalizations.of(context);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
     /// iki defa verilince kesiyo width: MediaQuery.of(context).size.width - 120,
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isFilterMode ? loc.shaderTypeFilterLabel : loc.shaderTypeEffectLabel,
            style: TextStyle(
              color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          // Horizontal scroll için SingleChildScrollView
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount:
                  (_isFilterMode
                          ? ShaderEffectType.filterTypes
                          : ShaderEffectType.effectTypes)
                      .length,
              itemBuilder: (context, index) {
                final types = _isFilterMode
                    ? ShaderEffectType.filterTypes
                    : ShaderEffectType.effectTypes;
                String type = types[index];
                bool isSelected = _selectedShaderType == type;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      if (!isSelected) {
                        setState(() {
                          _selectedShaderType = type;
                          shaderEffectService.changeShaderType(type);
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? app_theme.accent.withOpacity(0.2) 
                            : (isDark ? app_theme.projectListCardBg : app_theme.surface),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected ? app_theme.accent : (isDark ? app_theme.projectListCardBorder : app_theme.border),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _shaderTypeDisplayName(loc, type),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? app_theme.accent : (isDark ? app_theme.darkTextSecondary : app_theme.textSecondary),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _shaderTypeDescription(loc, _selectedShaderType),
            style: TextStyle(
              color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  List<Widget> _buildParameterControlsList() {
    List<String> availableParams = ShaderEffectType.getAvailableParams(
      _selectedShaderType,
    );
    return availableParams.map((param) => _buildCompactSlider(param)).toList();
  }

  // Compact slider for Wrap layout (Text editor style)
  Widget _buildCompactSlider(String paramName) {
    double value = _getParamValue(paramName);
    double min = _getParamMin(paramName);
    double max = _getParamMax(paramName);

    final double safeValue = (value.isFinite ? value : min).clamp(min, max);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      /// iki defa verilince kesiyo width: 235, // Same as Text editor's FontSize
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _getParamShortName(paramName),
                style: TextStyle(
                  fontSize: 14, 
                  fontWeight: FontWeight.w500,
                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
                ),
              ),
              Text(
                safeValue.toStringAsFixed(2),
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
                ),
              ),
            ],
          ),
          SizedBox(
            height: 36,
            child: Slider(
              value: safeValue,
              min: min,
              max: max,
              activeColor: app_theme.accent,
              inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
              onChanged: (newValue) {
                setState(() {
                  shaderEffectService.updateShaderParam(paramName, newValue);
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  double _getParamValue(String paramName) {
    switch (paramName) {
      case 'intensity':
        return widget.asset.intensity;
      case 'speed':
        return widget.asset.speed;
      case 'size':
        return widget.asset.size;
      case 'density':
        return widget.asset.density;
      case 'angle':
        return widget.asset.angle;
      case 'frequency':
        return widget.asset.frequency;
      case 'amplitude':
        return widget.asset.amplitude;
      case 'blurRadius':
        return widget.asset.blurRadius;
      case 'vignetteSize':
        return widget.asset.vignetteSize;
      default:
        return 0.5;
    }
  }

  double _getParamMin(String paramName) {
    switch (paramName) {
      case 'intensity':
      case 'density':
      case 'amplitude':
      case 'vignetteSize':
        return 0.0;
      case 'speed':
      case 'size':
      case 'frequency':
        return 0.5;
      case 'angle':
        return -45.0;
      case 'blurRadius':
        return 1.0;
      default:
        return 0.0;
    }
  }

  double _getParamMax(String paramName) {
    switch (paramName) {
      case 'intensity':
      case 'density':
      case 'amplitude':
      case 'vignetteSize':
        return 1.0;
      case 'speed':
      case 'size':
        return 2.0;
      case 'angle':
        return 45.0;
      case 'frequency':
        return 5.0;
      case 'blurRadius':
        return 20.0;
      default:
        return 1.0;
    }
  }

  String _getParamShortName(String paramName) {
    // Compact names for horizontal layout
    switch (paramName) {
      case 'intensity':
        return AppLocalizations.of(context).shaderParamIntensityShort;
      case 'speed':
        return AppLocalizations.of(context).shaderParamSpeedShort;
      case 'size':
        return AppLocalizations.of(context).shaderParamSizeShort;
      case 'density':
        return AppLocalizations.of(context).shaderParamDensityShort;
      case 'angle':
        return AppLocalizations.of(context).shaderParamAngleShort;
      case 'frequency':
        return AppLocalizations.of(context).shaderParamFrequencyShort;
      case 'amplitude':
        return AppLocalizations.of(context).shaderParamAmplitudeShort;
      case 'blurRadius':
        return AppLocalizations.of(context).shaderParamBlurShort;
      case 'vignetteSize':
        return AppLocalizations.of(context).shaderParamVignetteShort;
      default:
        return paramName;
    }
  }

  String getParamDisplayName(String paramName) {
    final loc = AppLocalizations.of(context);

    // Fractal için özel isimler
    if (widget.asset.type == 'fractal') {
      if (paramName == 'size') return loc.shaderParamFractalSize;
      if (paramName == 'density') return loc.shaderParamFractalDensity;
    }

    // Psychedelic için özel isimler
    if (widget.asset.type == 'psychedelic') {
      if (paramName == 'size') return loc.shaderParamPsychedelicSize;
      if (paramName == 'density') return loc.shaderParamPsychedelicDensity;
    }

    switch (paramName) {
      case 'intensity':
        return loc.shaderParamIntensity;
      case 'speed':
        return loc.shaderParamSpeed;
      case 'size':
        return loc.shaderParamSize;
      case 'density':
        return loc.shaderParamDensity;
      case 'angle':
        return loc.shaderParamAngle;
      case 'frequency':
        return loc.shaderParamFrequency;
      case 'amplitude':
        return loc.shaderParamAmplitude;
      case 'blurRadius':
        return loc.shaderParamBlurRadius;
      case 'vignetteSize':
        return loc.shaderParamVignetteSize;
      case 'color':
        return loc.shaderParamColor;
      default:
        return paramName;
    }
  }
}
