import 'package:vidviz/model/layer.dart';
import 'package:vidviz/model/text_asset.dart';
import 'package:vidviz_engine/vidviz_engine.dart';
import 'package:logger/logger.dart';
import 'native_shader_loader.dart';

class NativeExportShaderBuilder {
  final Logger logger;
  final NativeExportShaderLoader loader;

  NativeExportShaderBuilder({
    required this.logger,
    required this.loader,
  });

  Future<List<ExportShader>> buildShadersForLayers(List<Layer> layers) async {
    final shaderTypes = <String>{};

    for (final layer in layers) {
      for (final asset in layer.assets) {
        try {
          final t = asset.type.toString().split('.').last;
          final data = asset.data;
          if (data is! Map<String, dynamic>) continue;

          if (t == 'shader') {
            final shader = data['shader'];
            if (shader is Map<String, dynamic>) {
              final type = shader['type'];
              if (type is String && type.isNotEmpty) {
                shaderTypes.add(type);
              }
            }
            continue;
          }

          if (t == 'visualizer') {
            final visualizer = data['visualizer'];
            if (visualizer is Map<String, dynamic>) {
              final shaderType = visualizer['shaderType'];
              final renderMode = visualizer['renderMode'];
              final type = visualizer['type'];

              String? id;
              if (renderMode is String && renderMode == 'progress') {
                id = 'progress';
              }
              if ((renderMode is String) && (renderMode == 'shader' || renderMode == 'visual')) {
                if (shaderType is String && shaderType.isNotEmpty) {
                  id = shaderType;
                }
              }
              if (id == null && type is String && type.isNotEmpty) {
                if (type == 'bars') id = 'bar';
                else if (type == 'wave') id = 'wav';
                else if (type == 'circle') id = 'circle';
                else if (type == 'spectrum') id = 'bar_circle';
                else if (type == 'particle') id = 'particle';
              }
              id ??= 'bar';
              shaderTypes.add(id);
            }
          }

          if (t == 'text') {
            final text = data['text'];
            if (text is Map<String, dynamic>) {
              final String effectType = (text['effectType'] as String?)?.toString() ?? '';
              final bool hasShaderEffect =
                  effectType.isNotEmpty && effectType != 'none' && effectType != 'inner_glow' && effectType != 'inner_shadow';
              if (hasShaderEffect) {
                shaderTypes.add(effectType);
              }
            } else {
              try {
                final ta = TextAsset.fromAsset(asset);
                final effectType = ta.effectType;
                final bool hasShaderEffect =
                    effectType.isNotEmpty && effectType != 'none' && effectType != 'inner_glow' && effectType != 'inner_shadow';
                if (hasShaderEffect) {
                  shaderTypes.add(effectType);
                }
              } catch (_) {}
            }
          }
        } catch (_) {}
      }
    }

    final out = <ExportShader>[];
    for (final type in shaderTypes) {
      final src = await loader.tryLoadShaderSource(type);
      if (src == null || src.isEmpty) {
        logger.w('Shader source missing for type=$type');
        continue;
      }
      out.add(ExportShader(id: type, name: type, source: src, uniforms: const {}));
    }
    return out;
  }
}
