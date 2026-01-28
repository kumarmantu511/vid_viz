import 'package:vidviz/model/layer.dart';

class ExportOverlayPreprocess {
  static void apply(List<Layer> layers, dynamic _ctx,) {
    for (final layer in layers) {
      for (final asset in layer.assets) {
        if (asset.deleted) continue;
        if (asset.type != AssetType.image) continue;

        final data = asset.data;
        if (data is! Map<String, dynamic>) continue;
        if (data['overlayType'] != 'media') continue;

        final double x0 = (data['x'] as num?)?.toDouble() ?? 0.5;
        final double y0 = (data['y'] as num?)?.toDouble() ?? 0.5;
        final double opacity0 = (data['opacity'] as num?)?.toDouble() ?? 1.0;
        final double rotation0 = (data['rotation'] as num?)?.toDouble() ?? 0.0;
        final double border0 = (data['borderRadius'] as num?)?.toDouble() ?? 0.0;
        final double cropZoom0 = (data['cropZoom'] as num?)?.toDouble() ?? 1.0;
        final double cropPanX0 = (data['cropPanX'] as num?)?.toDouble() ?? 0.0;
        final double cropPanY0 = (data['cropPanY'] as num?)?.toDouble() ?? 0.0;

        final double safeX = (x0.isFinite ? x0 : 0.5).clamp(0.0, 1.0);
        final double safeY = (y0.isFinite ? y0 : 0.5).clamp(0.0, 1.0);
        final double safeOpacity = (opacity0.isFinite ? opacity0 : 1.0).clamp(0.0, 1.0);
        double safeRotation = (rotation0.isFinite ? rotation0 : 0.0);
        safeRotation = safeRotation % 360.0;
        if (safeRotation < 0) safeRotation += 360.0;

        final double safeBorder = (border0.isFinite ? border0 : 0.0).clamp(0.0, 100.0);
        final double scale = (data['scale'] as num?)?.toDouble() ?? 1.0;
        final double safeScale = (scale.isFinite ? scale : 1.0).clamp(0.01, 10.0);

        String cropMode = (data['cropMode'] as String?) ?? 'none';
        if (cropMode.isEmpty) cropMode = 'none';

        String frameMode = (data['frameMode'] as String?) ?? 'square';
        if (frameMode.isEmpty) frameMode = 'square';
        String fitMode = (data['fitMode'] as String?) ?? 'cover';
        if (fitMode.isEmpty) fitMode = 'cover';

        final double safeCropZoom = (cropZoom0.isFinite ? cropZoom0 : 1.0).clamp(1.0, 4.0);
        final double safeCropPanX = (cropPanX0.isFinite ? cropPanX0 : 0.0).clamp(-1.0, 1.0);
        final double safeCropPanY = (cropPanY0.isFinite ? cropPanY0 : 0.0).clamp(-1.0, 1.0);

        data['x'] = safeX;
        data['y'] = safeY;
        data['scale'] = safeScale;
        data['opacity'] = safeOpacity;
        data['rotation'] = safeRotation;
        data['borderRadius'] = safeBorder;
        data['cropMode'] = cropMode;
        data['cropZoom'] = safeCropZoom;
        data['cropPanX'] = safeCropPanX;
        data['cropPanY'] = safeCropPanY;
        data['frameMode'] = frameMode;
        data['fitMode'] = fitMode;
      }
    }
  }
}
