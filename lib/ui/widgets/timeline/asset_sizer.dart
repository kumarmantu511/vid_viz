import 'dart:core';
import 'package:flutter/material.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/model/layer.dart';
import 'package:vidviz/core/params.dart';
import 'package:vidviz/core/theme.dart' as app_theme;

class AssetSizer extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final int layerIndex;
  final bool sizerEnd;

  AssetSizer(this.layerIndex, this.sizerEnd, {super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: directorService.selected$,
        initialData: Selected(-1, -1),
        builder: (BuildContext context, AsyncSnapshot<Selected> selected) {

          // Başlangıç değerleri (Görünmez olması için ekran dışı)
          double left = -5000;
          Color statusColor = Colors.pinkAccent; // Varsayılan renk (Orijinal koddaki gibi)
          bool isVisible = false;

          // --- ORİJİNAL MANTIK BLOĞU BAŞLANGICI ---
          if (selected.data!.layerIndex == layerIndex && selected.data!.assetIndex != -1 && !directorService.isDragging) {
            Asset asset = directorService.layers![layerIndex].assets[selected.data!.assetIndex];

            // Trimmer tipleri kontrolü (Orijinal koddaki gibi)
            if (asset.type == AssetType.text ||
                asset.type == AssetType.image ||
                asset.type == AssetType.visualizer ||
                asset.type == AssetType.shader ||
                asset.type == AssetType.video ||
                asset.type == AssetType.audio) {

              isVisible = true;

              // 1. Ham Pozisyon Hesabı (Orijinal mantık)
              // left değişkenini burada 'raw position' olarak kullanıyoruz
              left = asset.begin * directorService.pixelsPerSecond / 1000.0;

              if (sizerEnd) {
                // --- SAĞ TARA (BITIŞ) ---
                left += asset.duration * directorService.pixelsPerSecond / 1000.0;

                if (directorService.isSizerDraggingEnd) left += directorService.dxSizerDrag;

                // Min süre clamp (1000ms)
                if (left < (asset.begin + 1000) * directorService.pixelsPerSecond / 1000.0) {
                  left = (asset.begin + 1000) * directorService.pixelsPerSecond / 1000.0;
                }
              } else {
                // --- SOL TARAF (BAŞLANGIÇ) ---
                if (!directorService.isSizerDraggingEnd) left += directorService.dxSizerDrag;

                // Max süre clamp
                if (left > (asset.begin + asset.duration - 1000) * directorService.pixelsPerSecond / 1000.0) {
                  left = (asset.begin + asset.duration - 1000) * directorService.pixelsPerSecond / 1000.0;
                }
                // Min pozisyon clamp
                if (left < 0) {
                  left = 0;
                }
              }

              // Scroll kaydırmasını ekle (Orijinal mantık)
              final double scrollIncr = selected.data!.incrScrollOffset;
              left = left + scrollIncr;

              // Renk mantığı (Drag durumuna göre Yeşil veya Pembe)
              statusColor = directorService.isSizerDragging ?  app_theme.assetGreen : app_theme.assetRed;
            }
          }
          // --- ORİJİNAL MANTIK BLOĞU SONU ---

          if (!isVisible) return const SizedBox();

          // --- GÖRSEL HİZALAMA AYARLARI (YENİ TASARIM İÇİN) ---
          // Orijinal kodda 'handleHalf = 15.0' vardı.
          // Yeni tasarımda (30px kutu, 14px görsel) kolların içe oturması için:

          if (sizerEnd) {
            // Sağ Tutamaç: Sol kenarı çizgiye değmeli -> 8px geri çek
            left -= 8.0;
          } else {
            // Sol Tutamaç: Sağ kenarı çizgiye değmeli -> 22px geri çek
            left -= 22.0;
          }

          // İstenen 1px düzeltme
          left += 1.0;

          // Final Ekran Pozisyonu (Orijinal koddaki MediaQuery hesabı)
          double finalScreenPos = MediaQuery.of(context).size.width / 2 + left - Params.TIMELINE_HEADER_W - 1;

          return Positioned(
            left: finalScreenPos,
            top: 1, // Yükseklik hizası
            child: GestureDetector(
              onHorizontalDragStart: (detail) => directorService.sizerDragStart(sizerEnd),
              onHorizontalDragUpdate: (detail) => directorService.sizerDragUpdate(sizerEnd, detail.delta.dx),
              onHorizontalDragEnd: (detail) => directorService.sizerDragEnd(sizerEnd),
              child: Container(
                height: Params.getLayerHeight(context, directorService.layers![layerIndex].type),
                width: 30, // Tıklama alanı (Orijinal ile aynı genişlik)
                alignment: Alignment.center,
                color: Colors.transparent, // Arka plan şeffaf
                // NEON GÖRSEL
                child: SizedBox(
                  width: 14,
                  child: _buildNeonHandle(sizerEnd, statusColor),
                ),
              ),
            ),
          );
        });
  }

  // Neon Tutamaç Tasarımı
  // statusColor: Drag durumuna göre Yeşil veya Pembe gelir
  Widget _buildNeonHandle(bool isRight, Color statusColor) {
    return Container(
      width: 14,
      height: double.infinity,
      decoration: BoxDecoration(
        // Ana Gradient (Mavi tonları sabit kalır, şıklık için)
        color: statusColor,
       //gradient: const LinearGradient(
       //  colors: [Color(0xFF00E5FF), Color(0xFF2979FF)],
       //  begin: Alignment.topCenter,
       //  end: Alignment.bottomCenter,
       //),
        // Köşeler (Kapsayıcı şekil için)
        borderRadius: BorderRadius.horizontal(
          left: isRight ? Radius.zero : const Radius.circular(6),
          right: isRight ? const Radius.circular(6) : Radius.zero,
        ),
        // boxShadow: [
        //   // 1. Gölge: Duruma göre renk değiştirir (Yeşil/Pembe/Mavi)
        //   BoxShadow(
        //     color: statusColor.withOpacity(0.6), // Drag yaparken Yeşil parlar
        //     blurRadius: 8,
        //     spreadRadius: 1,
        //     offset: const Offset(0, 0),
        //   ),
        //   // 2. Gölge: Derinlik (Siyah)
        //   BoxShadow(
        //     color: Colors.black.withOpacity(0.3),
        //     blurRadius: 3,
        //     offset: const Offset(0, 2),
        //   ),
        // ],
      ),
      // İçindeki Beyaz Çizgi (Grip)
      child: Center(
        child: Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class AssetSizerold extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final int layerIndex;
  final bool sizerEnd;

  AssetSizerold(this.layerIndex, this.sizerEnd, {super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: directorService.selected$,
        initialData: Selected(-1, -1),
        builder: (BuildContext context, AsyncSnapshot<Selected> selected) {
          Color color = Colors.transparent;
          double left = -50;
          const double handleHalf = 15.0; // center 30px handle on edge
          final double scrollIncr = selected.data!.incrScrollOffset;
          IconData? iconData;
          if (selected.data!.layerIndex == layerIndex && selected.data!.assetIndex != -1 && !directorService.isDragging) {
            Asset asset = directorService.layers![layerIndex].assets[selected.data!.assetIndex];
            // Trimmer: text, image, visualizer, shader, video, audio için aktif
            if (asset.type == AssetType.text ||
                asset.type == AssetType.image ||
                asset.type == AssetType.visualizer ||
                asset.type == AssetType.shader ||
                asset.type == AssetType.video ||
                asset.type == AssetType.audio) {
              left = asset.begin * directorService.pixelsPerSecond / 1000.0;
              if (sizerEnd) {
                left += asset.duration * directorService.pixelsPerSecond / 1000.0;
                if (directorService.isSizerDraggingEnd) left += directorService.dxSizerDrag;
                if (left < (asset.begin + 1000) * directorService.pixelsPerSecond / 1000.0) {
                  left = (asset.begin + 1000) * directorService.pixelsPerSecond / 1000.0;
                }
                // Center handle on edge
                left = left + scrollIncr - handleHalf;
                iconData = Icons.arrow_right;
              } else {
                // Left handle: move with dx for ALL types (video/audio included)
                if (!directorService.isSizerDraggingEnd) left += directorService.dxSizerDrag;
                // Clamp universally
                if (left > (asset.begin + asset.duration - 1000) * directorService.pixelsPerSecond / 1000.0) {
                  left = (asset.begin + asset.duration - 1000) * directorService.pixelsPerSecond / 1000.0;
                }
                if (left < 0) {
                  left = 0;
                }
                // Center handle on edge
                left = left + scrollIncr - handleHalf;
                iconData = Icons.arrow_left;
              }

              color = directorService.isSizerDragging ? Colors.greenAccent : Colors.pinkAccent;
            }
          }

          return Positioned(
            left: MediaQuery.of(context).size.width / 2 + left,
            child: GestureDetector(
              child: Container(
                height: Params.getLayerHeight(context, directorService.layers![layerIndex].type),
                width: 30,
                color: color,
                child: iconData != null ? Icon(iconData, size: 30, color: Colors.white) : const SizedBox(),
              ),
              onHorizontalDragStart: (detail) => directorService.sizerDragStart(sizerEnd),
              onHorizontalDragUpdate: (detail) => directorService.sizerDragUpdate(sizerEnd, detail.delta.dx),
              onHorizontalDragEnd: (detail) => directorService.sizerDragEnd(sizerEnd),
            ),
          );
        });
  }
}
