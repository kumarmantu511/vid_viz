import 'dart:core';
import 'package:flutter/material.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/model/layer.dart';
import 'package:vidviz/core/params.dart';
import 'package:vidviz/ui/widgets/timeline/asset_selection.dart';
import 'package:vidviz/ui/widgets/drag_closest.dart';
import 'package:vidviz/ui/widgets/timeline/asset_sizer.dart';
import 'package:vidviz/ui/widgets/timeline/timeline_asset.dart';
import 'package:vidviz/ui/widgets/timeline/timeline_layer.dart';
import 'package:vidviz/ui/widgets/timeline/timeline_ruler.dart';

class TimelineMain extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  TimelineMain({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: directorService.scrollController,
        child: GestureDetector(
          onScaleStart: (_) => directorService.scaleStart(),
          onScaleUpdate: (d) => directorService.scaleUpdate(d.horizontalScale),
          onScaleEnd: (_) => directorService.scaleEnd(),
          child: NotificationListener<ScrollNotification>(
            onNotification: (scrollState) {
              if (scrollState is ScrollEndNotification) {
                directorService.endScroll();
              }
              return false;
            },
            child: StreamBuilder(
              stream: directorService.layersChanged$,
              initialData: false,
              builder: (BuildContext context, AsyncSnapshot<bool?> layersChanged) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TimelineRuler(),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                               TimelineLayer(),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: (directorService.layers != null) ?
                                  directorService.layers!.asMap().map((index, layer) =>
                                  MapEntry(index, _LayerAssets(index)),).values.toList() : [],
                                ),
                              ],
                            ),
                            SizedBox(height: Params.getLayerBottom(context)),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ) ,
          ),
        ),
      );
  }
}

class _LayerAssets extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final int layerIndex;
  _LayerAssets(this.layerIndex) : super();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: const Alignment(0, 0),
      children: [
        Container(
          height: Params.getLayerHeight(
            context,
            directorService.layers![layerIndex].type,
          ),
          margin: EdgeInsets.all(1),
          child: Row(
            children: [
              // Half left screen in blank
              Container(width: MediaQuery.of(context).size.width / 2 - Params.TIMELINE_HEADER_W - 1),
              Builder(
                builder: (_) {
                  final assets = directorService.layers![layerIndex].assets;
                  final layerType = directorService.layers![layerIndex].type;
                  final double pix = directorService.pixelsPerSecond / 1000.0;
                  // Vector katmanda: eğer legacy placeholder (title == '') kullanılıyorsa boşlukları zaten placeholder kapatır
                  // Aksi halde (dinamik vector overlay), begin boşluklarını eklememiz gerekir
                  final bool hasPlaceholders = assets.any((a) => a.type == AssetType.text && (a.title == '' || a.title.isEmpty),);
                  if (layerType == 'vector' && hasPlaceholders) {
                    return Row(
                      children: assets.asMap().map((assetIndex, asset) => MapEntry(
                      assetIndex, TimelineAsset(layerIndex, assetIndex),),).values.toList(),
                    );
                  }
                  // Diğer katmanlarda (raster, audio, visualizer, shader, overlay, audio_reactive)
                  // begin boşluklarını piksel bazında ekle ki seçim/sizer ile hizalı olsun
                  double cursor = 0;
                  final List<Widget> items = [];
                  for (int i = 0; i < assets.length; i++) {
                    final a = assets[i];
                    final double target = a.begin * pix;
                    final double gap = target - cursor;
                    if (gap > 0) {
                      items.add(SizedBox(width: gap));
                      cursor += gap;
                    }
                    items.add(TimelineAsset(layerIndex, i));
                    cursor += a.duration * pix;
                  }
                  return Row(children: items);
                },
              ),
              Container(width: MediaQuery.of(context).size.width / 2 - 2),
            ],
          ),
        ),
        AssetSelection(layerIndex),
        AssetSizer(layerIndex, false),
        AssetSizer(layerIndex, true),
        (directorService.layers![layerIndex].type != 'vector') ? DragClosest(layerIndex) : Container(),
      ],
    );
  }
}
