import 'dart:core';
import 'package:flutter/material.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/model/text_asset.dart';
import 'package:vidviz/core/params.dart';
import 'package:vidviz/core/constants.dart';
import 'package:vidviz/ui/widgets/text/text_effect_player.dart';
import 'package:vidviz/ui/widgets/timeline/player_metrics.dart';
import '../../../core/theme.dart';
import '../../../core/theme.dart' as app_theme;

class TextPlayerEditor extends StatefulWidget {
  final TextAsset _asset;
  TextPlayerEditor(this._asset, {super.key});

  @override
  State<TextPlayerEditor> createState() => _TextPlayerEditorState();
}

class _TextPlayerEditorState extends State<TextPlayerEditor> {
  final directorService = locator.get<DirectorService>();
  late TextEditingController _controller;
  //late ValueNotifier<TextAsset> assetNotifier;

  bool _isDragging = false;
  bool _isEditing = false;
  bool editMode = false;
  bool _showHint = true;


  static const double _dragSensitivity = 0.6;

  Color get _borderColor {
   // final asset = assetNotifier.value;
    if (_isEditing) return assetRed;
    if (_isDragging) return assetGreen;
    return Colors.white;
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget._asset.title);
    //assetNotifier = ValueNotifier(widget._asset);
  }
  @override
  void dispose() {
    _controller.dispose();
   // assetNotifier.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final playerW = PlayerLayout.width(context);
    final playerH = PlayerLayout.height(context);

    return StreamBuilder(
      stream: directorService.editingTextAsset$,
      initialData: null,
      builder: (BuildContext context, AsyncSnapshot<TextAsset?> editingTextAsset) {

        final asset = editingTextAsset.data ?? widget._asset;
        var font = Font.allFonts.first;
        try {
          font = Font.getByPath(asset.font);
        } catch (_) {
          // keep fallback
        }
        final double boxPad = (asset.box && asset.boxPad.isFinite) ? asset.boxPad.clamp(0.0, 30.0) : 0.0;
        final double boxBorderW = (asset.box && asset.boxborderw.isFinite) ? asset.boxborderw.clamp(0.0, 20.0) : 0.0;


        return Stack(
          clipBehavior: Clip.none,
          children: [
            if(editMode || asset.title.isEmpty)
            // 🔹 TEXT + DYNAMIC WIDTH
            Container(
              width: playerW * 0.8,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border.all(color: _borderColor, width: 1.5),
                borderRadius: BorderRadius.circular(1),
              ),
              child: Container(
                padding: EdgeInsets.all(boxPad),
                decoration: BoxDecoration(
                  color: asset.box ? Color(asset.boxcolor) : Colors.transparent,
                  borderRadius: BorderRadius.circular(asset.boxRadius),
                  border: boxBorderW > 0
                      ? Border.all(color: Color(asset.bordercolor), width: boxBorderW)
                      : null,
                ),
                child: Focus(
                  onFocusChange: (f) {
                    // O zaman kaydet ve edit modunu kapat
                    _isEditing = f;
                    if (!f) {
                      // ❗ SADECE focus kaybolunca
                      directorService.editingTextAsset = asset;
                      setState(() {
                        editMode = false;
                      });
                    }
                    setState(() {});
                  },
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 1,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Click to edit text',
                    ),
                    style: TextStyle(
                      height: 1,
                      fontSize: 30, // ❗ playerW YOK,
                      fontStyle: font.style,
                      fontFamily: font.family,
                      fontWeight: font.weight,
                      color: Color(asset.fontColor),
                    ),
                    onChanged: (v) {
                      asset.title = v;
                     // assetNotifier.value = asset;
                     /// eğer anlık güncelrsek ui tetikelnir sorun olur directorService.editingTextAsset = asset;
                    },
                  ),
                ),
              ),
            )
            else
            GestureDetector(
              onTap: (){
                setState(() {
                  editMode = true;
                  _showHint = false;
                  print(editMode);
                  print('tıkalndı');
                });
              },
              behavior: HitTestBehavior.translucent, // parmak yakınsa da yakalar
              onPanStart: (_) {
                _isDragging = true;
                _isEditing = false;
                setState(() {});
              },
              onPanUpdate: (details) {
                // Not create clone because it is too slow
                asset.x += details.delta.dx / playerW;
                asset.y += details.delta.dy / playerH;
                if (!asset.x.isFinite) asset.x = 0.1;
                if (!asset.y.isFinite) asset.y = 0.4;
                if (asset.x < 0) {
                  asset.x = 0;
                }
                if (asset.x > 0.85) {
                  asset.x = 0.85;
                }
                if (asset.y < 0) {
                  asset.y = 0;
                }
                if (asset.y > 0.85) {
                  asset.y = 0.85;
                }

                // assetNotifier.value = asset;
                directorService.editingTextAsset = asset;
              },
              onPanEnd: (_) {
                _isDragging = false;

                setState(() {});
              },
              child:  _EffectPreview(asset),
            ),

            if(editMode || asset.title.isEmpty)
            // 🔹 DRAG HANDLE
            Positioned(
                left: -16, // Direkt dışarıya konumlandır (Transform kullanma)
                top: -16,  // Y ekseninde de dışarı
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _handle(

                    icon: Icons.close,
                    onTap: () {
                      setState(() {
                        editMode = false;
                        print(editMode);
                        print('tıkalndı');
                      });
                    },
                  ),
                ),
              ),
            if(editMode == false && asset.title.isNotEmpty)
            // 🔹 DRAG HANDLE
            Positioned(
              left: -16, // Direkt dışarıya konumlandır (Transform kullanma)
              top: -16,  // Y ekseninde de dışarı
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _handle(

                  icon: Icons.open_with,
                  onPan: (d) {
                    _isDragging = true;
                    asset.x += (d.delta.dx * _dragSensitivity) / playerW;
                    asset.y += (d.delta.dy * _dragSensitivity) / playerH;
                    if (!asset.x.isFinite) asset.x = 0.1;
                    if (!asset.y.isFinite) asset.y = 0.4;
                    if (asset.x < 0) {
                      asset.x = 0;
                    }
                    if (asset.x > 0.85) {
                      asset.x = 0.85;
                    }
                    if (asset.y < 0) {
                      asset.y = 0;
                    }
                    if (asset.y > 0.85) {
                      asset.y = 0.85;
                    }
                  //  assetNotifier.value = asset;
                    directorService.editingTextAsset = asset;
                  },
                ),
              ),
            ),
            if(editMode == false && asset.title.isNotEmpty)
            // 🔹 SCALE HANDLE
            Positioned(
              right: -16, // Direkt dışarıya konumlandır (Transform kullanma)
              top: -16,  // Y ekseninde de dışarı
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: _handle(

                  icon: Icons.zoom_out_map,
                  onPan: (d) {
                    final dx = d.delta.dx.clamp(-6.0, 6.0); // ani hareketi sınırla

                    asset.fontSize += dx * 0.001; // slider hızı
                    asset.fontSize = asset.fontSize.clamp(0.03, 0.5);
                   // asset.fontSize += d.delta.dx * _scaleSensitivity;
                   // asset.fontSize = asset.fontSize.clamp(0.03, 0.5);
                    //assetNotifier.value = asset;
                    directorService.editingTextAsset = asset;
                  },
                ),
              ),
            ),
            if (!editMode && asset.title.isNotEmpty && _showHint)
            Positioned(
              bottom: -15,

              child: Container(
                decoration: BoxDecoration(
                  color: app_theme.warning.withOpacity(0.25),
                  border: Border.all(color: app_theme.warning.withOpacity(0.5), width: 1.5),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: ClipRect(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Tap to edit text',
                      style: TextStyle(
                        height: 1,
                        fontSize: 12,
                        fontStyle: font.style,
                        fontFamily: font.family,
                        fontWeight: font.weight,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _handle({required IconData icon, GestureDragUpdateCallback? onPan, GestureTapCallback? onTap,}) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent, // parmak yakınsa da yakalar
      onTap: onTap,
      onPanUpdate: onPan,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, size: 12, color: Colors.white),
      ),
    );
  }
}

/// Text efekt önizleme widget'ı - Anchor-safe
/// Text efekt önizleme widget'ı - Play-safe (top-left anchor)
class _EffectPreview extends StatelessWidget {
  final TextAsset asset;
  const _EffectPreview(this.asset);

  @override
  Widget build(BuildContext context) {
    final playerW = PlayerLayout.width(context);
    final double offsety  = asset.boxPad > 0.0 ? 0.0 : -8.0;

    return Align(
      alignment: Alignment.topLeft,

      child: CustomPaint(
        painter: _BorderPainter(
          color: app_theme.accent,
          backgroundColor: app_theme.accent.withOpacity(0.15),
          minSize: const Size(60, 40),
          asset: asset,
        ),
        child: Transform.translate(
            offset: Offset(0, offsety), // 🔑 zıplamayı öldürür
            child: TextEffectPlayer(asset, playerWidth: playerW)
        ),
      ),
    );
  }
}

class _BorderPainter extends CustomPainter {
  final Color color;
  final Color backgroundColor;
  final Size minSize;
  final TextAsset asset;

  _BorderPainter({
    required this.asset,
    required this.color,
    required this.backgroundColor,
    this.minSize = const Size(60, 40), // ✅ Default min size
  });

  static const double borderW = 1.5;
  //static final double margin =  asset.fontSize > 0.50 -10.0 ? asset.fontSize : 4.0;
  static const double yOffset = 0.0;
  static const double xOffset = 0.0;

  @override
  void paint(Canvas canvas, Size size) {
    final double margin = asset.fontSize > 0.50 ? -4 : 6.0;


    if (size.isEmpty) return;

    // ✅ Gerçek boyutu minimum ile karşılaştır
    final actualWidth = size.width < minSize.width ? minSize.width : size.width;
    final actualHeight = size.height < minSize.height ? minSize.height : size.height;

    final rect = Rect.fromLTWH(
      -margin + xOffset,
      -margin + yOffset,
      actualWidth + (margin * 2),
      actualHeight + (margin * 2),
    );

    final rrect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(4),
    );

    // Background
    canvas.drawRRect(
      rrect,
      Paint()..color = backgroundColor,
    );

    // Border
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderW,
    );
  }

  @override
  bool shouldRepaint(covariant _BorderPainter old) =>
      old.color != color ||
          old.backgroundColor != backgroundColor ||
          old.minSize != minSize;
}
