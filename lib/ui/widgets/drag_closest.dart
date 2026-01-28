import 'dart:core';
import 'package:flutter/material.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/model/layer.dart';
import 'package:vidviz/core/params.dart';


class DragClosest extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final int layerIndex;

  DragClosest(this.layerIndex) : super();

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
          
          Color color;
          double left;
          final layer = directorService.layers![layerIndex];
          
          if (directorService.isDragging && 
              selected.data!.closestAsset != -1 && 
              selected.data!.layerIndex == layerIndex &&
              selected.data!.closestAsset < layer.assets.length) {
            color = Colors.pink;
            Asset closestAsset = layer.assets[selected.data!.closestAsset];
            if (selected.data!.closestAsset <= selected.data!.assetIndex) {
              left = closestAsset.begin * directorService.pixelsPerSecond / 1000.0;
            } else {
              left = (closestAsset.begin + closestAsset.duration) * directorService.pixelsPerSecond / 1000.0;
            }
          } else {
            color = Colors.transparent;
            left = -1;
          }

          return Positioned(
            left:  MediaQuery.of(context).size.width / 2 + left - 2,
            child: Container(
              height: Params.getLayerHeight(context, layer.type),
              width: 3,
              color: color,
            ),
          );
        });
  }
}

