import 'package:flutter/material.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/core/params.dart';
import 'package:vidviz/core/theme.dart' as app_theme;

import '../svg_icon.dart';

/// Timeline sol tarafındaki layer ikonları
class TimelineLayer extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  TimelineLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: directorService.layersChanged$,
      initialData: false,
      builder: (BuildContext context, AsyncSnapshot<bool?> snapshot) {
        final layers = directorService.layers;
        
        return Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ruler boşluğu
            /// Container(
            ///   height: Params.RULER_HEIGHT - 4,
            ///   width: 33,
            ///   margin: const EdgeInsets.fromLTRB(0, 2, 0, 2),
            /// ),
            // Layer header'ları
            if (layers != null)...layers.map((layer) => _LayerHeader(type: layer.type)),
          ],
        );
      },
    );
  }
}

/// Tek layer header widget'ı
class _LayerHeader extends StatelessWidget {
  final String type;
  
  const _LayerHeader({required this.type});

  /// Layer tipine göre ikon ve renk döndür
  (String, Color) _getIconAndColor() {
    switch (type) {
      case 'raster':
        return ('image', app_theme.layerRaster);
      case 'vector':
        return ('text', app_theme.layerVector);
      case 'visualizer':
        return ('visualizer', app_theme.layerVisualizer);
      case 'shader':
        return ('effects', app_theme.layerShader);
      case 'overlay':
        return ('overlay', app_theme.layerOverlay);
      case 'audio_reactive':
        return ('reactive', app_theme.layerAudioReactive);
      default: // audio
        return ('audio', app_theme.layerAudio);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (asset, color) = _getIconAndColor();
    final bgColor = isDark ? app_theme.projectListCardBg : app_theme.surface;

    return Container(
      height: Params.getLayerHeight(context, type),
      width: Params.TIMELINE_HEADER_W,
      margin: const EdgeInsets.fromLTRB(0, 1, 1, 1),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          right: BorderSide(color: color.withValues(alpha: 0.6), width: 2),
        ),
      ),
      child: Center(
        child: SvgIcon(
          asset: asset,
          color: color,
          size: 16,
        ),
      ),
    );
  }
}
