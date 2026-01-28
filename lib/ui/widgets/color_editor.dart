import 'dart:core';
import 'package:flutter/material.dart';
import 'package:vidviz/l10n/generated/app_localizations.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/service/visualizer_service.dart';
import 'package:vidviz/core/params.dart';
import 'package:vidviz/model/text_asset.dart';
import 'package:vidviz/model/visualizer.dart';
import 'package:vidviz/core/theme.dart' as app_theme;

import '../../core/constants.dart';

class ColorEditor extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  ColorEditor({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder(
      stream: directorService.editingColor$,
      initialData: null,
      builder: (BuildContext context, AsyncSnapshot<String?> editingColor) {
        if (editingColor.data == null || editingColor.data == '') {
          return Container();
        }
        return Container(
          // bu sınırı kilitliyordu biz bunu özgür bıoraktık artık boşluk bununca yereleşecek kendisi sorna daha iyi bakarız
          // height: Params.getTimelineHeight(context),
          width: MediaQuery.of(context).size.width,

          decoration: BoxDecoration(
            color: isDark ? app_theme.projectListCardBg : app_theme.surface,
            border: Border(
              top: BorderSide(
                width: 2,
                color: app_theme.neonCyan,
              ),
            ),
          ),
          child: ColorForm(),
        );
      },
    );
  }
}

class ColorForm extends StatefulWidget {

  ColorForm({super.key});

  @override
  State<ColorForm> createState() => _ColorFormState();
}

class _ColorFormState extends State<ColorForm> {
  final directorService = locator.get<DirectorService>();

  final visualizerService = locator.get<VisualizerService>();

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    int pickColor = 0;
    bool isVisualizerColor = false;
    bool isVisualizerGradient = false;
    bool isVisualizerTrack = false;
    bool isVisualizerRingColor = false;
    bool isCounterLabelColor = false;
    String? counterLabelKey;

    if (visualizerService.editingVisualizerAsset != null) {
      if (directorService.editingColor == 'visualizerColor') {
        pickColor = visualizerService.editingVisualizerAsset!.color;
        isVisualizerColor = true;
      } else if (directorService.editingColor == 'visualizerGradient') {
        pickColor = visualizerService.editingVisualizerAsset!.gradientColor ?? 0xFFFFFFFF;
        isVisualizerGradient = true;
      } else if (directorService.editingColor == 'visualizerRingColor') {
        pickColor = visualizerService.editingVisualizerAsset!.ringColor ?? 0xFFFFFFFF;
        isVisualizerRingColor = true;
      } else if (directorService.editingColor == 'progressTrackColor') {
        final asset = visualizerService.editingVisualizerAsset!;
        if (asset.shaderParams != null && asset.shaderParams!['progressTrackColor'] is int) {
          pickColor = asset.shaderParams!['progressTrackColor'] as int;
        } else {
          pickColor = 0xFF444444;
        }
        isVisualizerTrack = true;
      } else if (directorService.editingColor == 'counterStartColor' || directorService.editingColor == 'counterEndColor') {
        final asset = visualizerService.editingVisualizerAsset!;
        counterLabelKey = directorService.editingColor;
        if (asset.shaderParams != null && counterLabelKey != null && asset.shaderParams![counterLabelKey] is int) {
          pickColor = asset.shaderParams![counterLabelKey] as int;
        } else {
          pickColor = 0xFFFFFFFF;
        }
        isCounterLabelColor = true;
      }
    } else if (directorService.editingTextAsset != null) {
      final a = directorService.editingTextAsset!;
      switch (directorService.editingColor) {
        case 'fontColor':
          pickColor = a.fontColor;
          break;
        case 'boxcolor':
          pickColor = a.boxcolor;
          break;
        case 'bordercolor':
          pickColor = a.bordercolor;
          break;
        case 'shadowcolor':
          pickColor = a.shadowcolor;
          break;
        case 'effectColorA':
          pickColor = a.effectColorA;
          break;
        case 'effectColorB':
          pickColor = a.effectColorB;
          break;
        case 'glowColor':
          pickColor = a.glowColor;
          break;
        default:
          pickColor = a.fontColor;
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      child: Column(
        children: [
          // colorList değişkeninizi olduğu gibi kullanın
          HorizontalColorPicker(
            colors: colorList,
            initialColor: Color(pickColor), // İsteğe bağlı başlangıç rengi
            onColorSelected: (color) {
              setState(() {}); // ana rengi güncelel
              final colorValue = color.toARGB32(); // ARGB formatına çevir
              pickColor = colorValue;
              // Mevcut renk güncelleme mantığını olduğu gibi kullan
              if (isVisualizerColor || isVisualizerGradient || isVisualizerRingColor || isVisualizerTrack || isCounterLabelColor) {
                final current = visualizerService.editingVisualizerAsset!;
                VisualizerAsset newAsset = VisualizerAsset.clone(current);
                if (isVisualizerColor) {
                  newAsset.color = colorValue;
                } else if (isVisualizerGradient) {
                  newAsset.gradientColor = colorValue;
                } else if (isVisualizerRingColor) {
                  newAsset.ringColor = colorValue;
                } else if (isVisualizerTrack) {
                  final params = Map<String, dynamic>.from(newAsset.shaderParams ?? {});
                  params['progressTrackColor'] = colorValue;
                  newAsset.shaderParams = params;
                } else if (isCounterLabelColor && counterLabelKey != null) {
                  final params = Map<String, dynamic>.from(newAsset.shaderParams ?? {});
                  params[counterLabelKey] = colorValue;
                  newAsset.shaderParams = params;
                }
                visualizerService.editingVisualizerAsset = newAsset;
              }
              else {
                final current = directorService.editingTextAsset!;
                TextAsset newAsset = TextAsset.clone(current);
                switch (directorService.editingColor) {
                  case 'fontColor':
                    newAsset.fontColor = colorValue;
                    break;
                  case 'boxcolor':
                    newAsset.boxcolor = colorValue;
                    break;
                  case 'bordercolor':
                    newAsset.bordercolor = colorValue;
                    break;
                  case 'shadowcolor':
                    newAsset.shadowcolor = colorValue;
                    break;
                  case 'effectColorA':
                    newAsset.effectColorA = colorValue;
                    break;
                  case 'effectColorB':
                    newAsset.effectColorB = colorValue;
                    break;
                  case 'glowColor':
                    newAsset.glowColor = colorValue;
                    break;
                }
                directorService.editingTextAsset = newAsset;
              }
            },
          ),
          SizedBox(height: 6,),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal:22),

                  child: ColorPicker(
                    pickerColor: Color(pickColor),
                    paletteType: PaletteType.hsv,
                    enableAlpha: true,
                    hexInputBar: true,
                    displayThumbColor: true,
                    pickerAreaBorderRadius: BorderRadius.circular(8),
                    colorPickerWidth: 180,
                    pickerAreaHeightPercent: 0.8,
                    onColorChanged: (changeColor) {
                      int color = changeColor.toARGB32();
                      setState(() {}); // ana rengi güncelel
                      pickColor = color;
                      if (isVisualizerColor || isVisualizerGradient || isVisualizerRingColor || isVisualizerTrack || isCounterLabelColor) {

                        final current = visualizerService.editingVisualizerAsset!;
                        VisualizerAsset newAsset = VisualizerAsset.clone(current,);
                        if (isVisualizerColor) {
                          newAsset.color = color;
                        } else if (isVisualizerGradient) {
                          newAsset.gradientColor = color;
                        } else if (isVisualizerRingColor) {
                          newAsset.ringColor = color;
                        } else if (isVisualizerTrack) {
                          final params = Map<String, dynamic>.from(newAsset.shaderParams ?? {},);
                          params['progressTrackColor'] = color;
                          newAsset.shaderParams = params;
                        } else if (isCounterLabelColor && counterLabelKey != null) {
                          final params = Map<String, dynamic>.from(newAsset.shaderParams ?? {},);
                          params[counterLabelKey] = color;
                          newAsset.shaderParams = params;
                        }
                        visualizerService.editingVisualizerAsset = newAsset;
                      }
                      else {
                        final current = directorService.editingTextAsset!;
                        TextAsset newAsset = TextAsset.clone(current);
                        switch (directorService.editingColor) {
                          case 'fontColor':
                            newAsset.fontColor = color;
                            break;
                          case 'boxcolor':
                            newAsset.boxcolor = color;
                            break;
                          case 'bordercolor':
                            newAsset.bordercolor = color;
                            break;
                          case 'shadowcolor':
                            newAsset.shadowcolor = color;
                            break;
                          case 'effectColorA':
                            newAsset.effectColorA = color;
                            break;
                          case 'effectColorB':
                            newAsset.effectColorB = color;
                            break;
                          case 'glowColor':
                            newAsset.glowColor = color;
                            break;
                        }
                        directorService.editingTextAsset = newAsset;
                      }
                    },
                  ),
                ),
              ),


              Container(
                  height: 100,
                  padding: const EdgeInsets.only(right: 24, top: 8),
                  child: _actionButtons(context, loc)
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _actionButtons(BuildContext context, AppLocalizations loc) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final directorService = locator.get<DirectorService>();
  return Column(
    children: [
      // İptal Butonu
      Expanded(
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
            side: BorderSide(
              color: isDark ? app_theme.projectListCardBorder : app_theme.border,
              width: 1.5,
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () => directorService.editingColor = null,
          child: Text(
            loc.commonCancel,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      // Onay Butonu (Gradient ile)
      Expanded(
        child: Container(
          decoration: BoxDecoration(
            gradient: app_theme.neonButtonGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: app_theme.neonCyan.withAlpha(60),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => directorService.editingColor = null,
            child: Text(
              loc.colorEditorSelect,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}



class HorizontalColorPicker extends StatefulWidget {
  final List<Color> colors;
  final ValueChanged<Color>? onColorSelected;
  final Color? initialColor;

  const HorizontalColorPicker({
    super.key,
    required this.colors,
    this.onColorSelected,
    this.initialColor,
  });

  @override
  State<HorizontalColorPicker> createState() => _HorizontalColorPickerState();
}

class _HorizontalColorPickerState extends State<HorizontalColorPicker> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialColor != null) {
      final index = widget.colors.indexOf(widget.initialColor!);
      if (index != -1) _selectedIndex = index;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24,vertical: 8),
        itemCount: widget.colors.length,
        itemBuilder: (context, index) {
          final color = widget.colors[index];
          final isSelected = index == _selectedIndex;

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() => _selectedIndex = index);
                  widget.onColorSelected?.call(color);
                },
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 40,
                  height: 60,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(color: Colors.white.withAlpha(240), width: 3,)
                        : Border.all(color: Colors.white.withAlpha(240), width: 2,),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(isSelected ? 60 : 30),
                        blurRadius: isSelected ? 12 : 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(
                    Icons.check,
                    size: 20,
                    color: Colors.white,
                  ) : null,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}