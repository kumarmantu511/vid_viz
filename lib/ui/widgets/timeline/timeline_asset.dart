import 'dart:core';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/model/layer.dart';
import 'package:vidviz/core/params.dart';
import 'package:vidviz/core/theme.dart' as app_theme;

class TimelineAsset extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final int layerIndex;
  final int assetIndex;
  TimelineAsset(this.layerIndex, this.assetIndex, {super.key});
  @override
  Widget build(BuildContext context) {
    Asset asset = directorService.layers![layerIndex].assets[assetIndex];
    final String layerType = directorService.layers![layerIndex].type;
    Color backgroundColor = Colors.transparent;
    Color borderColor = Colors.transparent;
    Color textColor =  const Color(0xFFFFFFFF);
    Color backgroundTextColor = Colors.transparent;
    /// textColor =Colors.transparent;

    if (asset.deleted) {
      // Silinmiş öğe: Uyarıcı ama göz almayan mat kırmızı
      backgroundColor = app_theme.layerDeleted; // Red 100

    } else {
      switch (layerType) {
        case 'audio':
        // Müzik: Sıcak, enerjik Turuncu/Amber (Timeline'da öne çıkar)

          backgroundColor = app_theme.layerAudio;
          ///textColor = const Color(0xFFFFFFFF);       // Orange 900

          break;

        case 'visualizer':
        // Görselleştirici: Modern, teknolojik ve canlı Mor (Electric Purple)
          backgroundColor = app_theme.layerVisualizer;
          ///textColor = const Color(0xFFFFFFFF);

          break;

        case 'audio_reactive':
        // Müzik Reaktif: Visualizer ile uyumlu ama daha derin bir İndigo/DeepPurple
          backgroundColor = app_theme.layerAudioReactive;
          ///textColor = const Color(0xFFFFFFFF);

          break;

        case 'shader':
          backgroundColor = app_theme.layerShader;
          ///textColor = const Color(0xFFFFFFFF);
          // Shader: Kod ve efekt hissi veren Neon Cyan

          break;

        case 'overlay':
          backgroundColor = app_theme.layerOverlay;
          ///textColor = const Color(0xFFFFFFFF);
          // Overlay: Bindirme hissi için sakin Teal/Turkuaz

          break;

        case 'raster':
          backgroundColor = app_theme.layerRaster;
          ///textColor = const Color(0xFFFFFFFF);
          // Resim: Standart, güvenilir Mavi

          // backgroundTextColor özel durumu korunuyor
          backgroundTextColor = Colors.black.withValues(alpha: 0.5);
          break;

        default:
        // Vector ve diğer durumlar (Mavi-Gri tonları)
          if (layerType == 'vector' && asset.title != '') {
            // Vektör: Resimden ayrışması için daha koyu/ciddi İndigo mavisi
            backgroundColor = app_theme.layerVector;
            /// textColor = const Color(0xFFFFFFFF);

          } else {
           // Varsayılan (Fallback)
            backgroundColor = Colors.grey.shade200;
            borderColor = Colors.grey.shade600;
            textColor = Colors.black87;
          }
          break;
      }
    }

    return GestureDetector(
      child: Container(
        height: Params.getLayerHeight(
          context,
          directorService.layers![layerIndex].type,
        ),
        width: asset.duration * directorService.pixelsPerSecond / 1000.0,
        padding: const EdgeInsets.fromLTRB(4, 3, 4, 3),
        margin: EdgeInsets.only(left: assetIndex == 0 ? 0 : 1) ,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.all(Radius.circular(2)),
          // 4. GÖLGE VE GLOW EFEKTLERİ
          boxShadow: [
            // A) GLOW EFEKTİ (Renkli Işık)
            BoxShadow(
              color: backgroundColor.withValues(alpha: 0.1), // Kenar renginin ışığı
              blurRadius: 6,      // Işığın ne kadar yayılacağı (Yumuşaklık)
              spreadRadius: -2,    // Işığı biraz içten başlatır, boğmaz
              offset: const Offset(0, 0), // Her yöne eşit yayılır
            ),

            // B) DERİNLİK GÖLGESİ (Hafif siyahlık)
            BoxShadow(
              color: backgroundColor.withValues(alpha: 0.1), // Siyah gölge
              blurRadius: 6,
              offset: const Offset(0, 3), // Hafif aşağıya doğru
            ),
          ],

          image: (!asset.deleted && asset.thumbnailPath != null && !directorService.isGenerating) ?
          DecorationImage(
            image: FileImage(File(asset.thumbnailPath!)),
            fit: BoxFit.cover,
            alignment: Alignment.topLeft,
            //repeat: ImageRepeat.repeatX // Doesn't work with fitHeight
          )
              : null,
        ),
        child: Text(
          asset.title,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            backgroundColor: backgroundTextColor,
            shadows: <Shadow>[
              Shadow(
                color: borderColor,
                offset: (layerIndex == 0) ? Offset(1, 1) : Offset(0, 0),
              ),
            ],
          ),
        ),
      ),
      onTap: () => directorService.select(layerIndex, assetIndex),
      // Long press to drag (move) asset on timeline
      onLongPressStart: (LongPressStartDetails details) {
        directorService.dragStart(layerIndex, assetIndex);
      },
      onLongPressMoveUpdate: (LongPressMoveUpdateDetails details) {
        directorService.dragSelected(
          layerIndex,
          assetIndex,
          details.offsetFromOrigin.dx,
          MediaQuery.of(context).size.width,
        );
      },
      onLongPressEnd: (LongPressEndDetails details) {
        directorService.dragEnd();
      },
    );
  }
}