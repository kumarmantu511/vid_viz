import 'dart:core';
import 'package:flutter/material.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/model/layer.dart';
import 'package:vidviz/core/params.dart';
import 'package:vidviz/core/theme.dart' as app_theme;

class AssetSelection extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final int layerIndex;

  AssetSelection(this.layerIndex, {super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: directorService.selected$,
        initialData: Selected(-1, -1),
        builder: (BuildContext context, AsyncSnapshot<Selected> selected) {
          // Null safety checks
          if (selected.data == null ||
              directorService.layers == null ||
              layerIndex < 0 ||
              layerIndex >= directorService.layers!.length) {
            return const SizedBox.shrink();
          }
          
          final layer = directorService.layers![layerIndex];
          
          Color borderColor = Colors.pinkAccent;
          double left, width;
          
          // Asset index bounds check
          if (selected.data!.layerIndex == layerIndex &&
              selected.data!.assetIndex != -1 &&
              selected.data!.assetIndex < layer.assets.length) {
            Asset asset = layer.assets[selected.data!.assetIndex];
            
            // Shader için cyan, diğerleri için pink
           /// kalsın sonra gerekirse kulanırız tirmmer için renkleri
           /// borderColor = (asset.type == AssetType.shader) ? Colors.cyan : Colors.pinkAccent;
            borderColor = app_theme.assetRed;

            if (directorService.isDragging || directorService.isSizerDragging) {
              borderColor = app_theme.assetGreen;
            }
            left = asset.begin * directorService.pixelsPerSecond / 1000.0 + selected.data!.dragX + selected.data!.incrScrollOffset;
            width = asset.duration * directorService.pixelsPerSecond / 1000.0;
            if (directorService.isSizerDragging && !directorService.isSizerDraggingEnd) {
              // Left handle dragging: move left edge with dx for ALL types (video/audio included)
              left += directorService.dxSizerDrag;
              if (left >
                  (asset.begin + asset.duration - 1000) * directorService.pixelsPerSecond / 1000) {
                left = (asset.begin + asset.duration - 1000) * directorService.pixelsPerSecond / 1000;
              }
              if (left < 0) {
                left = 0;
              }
              // Keep right edge fixed while dragging left handle
              width = (asset.begin + asset.duration) * directorService.pixelsPerSecond / 1000 - left;
            } else if (directorService.isSizerDragging) {
              width += directorService.dxSizerDrag;
              if (width < directorService.pixelsPerSecond) {
                width = directorService.pixelsPerSecond;
              }
            }
            if (left < 0) {
              left = 0;
            }
          } else {
            borderColor = Colors.transparent;
            left = -1;
            width = 0;
          }

          // İstenen 1px düzeltme pixel düzeltme  için ince ayarlar
          left += 1.0;

          // Final Ekran Pozisyonu (Orijinal koddaki MediaQuery hesabı)
          double finalScreenPos = MediaQuery.of(context).size.width / 2 + left - Params.TIMELINE_HEADER_W - 1;

          return Positioned(
            left: finalScreenPos,
            child: GestureDetector(
              child: Container(
                height: Params.getLayerHeight(context, layer.type),
                width: width,
                decoration: BoxDecoration(
                  color: borderColor.withValues(alpha: 0.30),
                  border: Border.all(width: 2, color: borderColor),

                ),
              ),
              onLongPressStart: (LongPressStartDetails details) {
                if (selected.data != null && selected.data!.assetIndex >= 0) {
                  directorService.dragStart(layerIndex, selected.data!.assetIndex);
                }
              },
              onLongPressMoveUpdate: (LongPressMoveUpdateDetails details) {
                if (selected.data != null && selected.data!.assetIndex >= 0) {
                  directorService.dragSelected(
                      layerIndex,
                      selected.data!.assetIndex,
                      details.offsetFromOrigin.dx,
                      MediaQuery.of(context).size.width);
                }
              },
              onLongPressEnd: (LongPressEndDetails details) {
                directorService.dragEnd();
              },
            ),
          );
        });
  }
}

