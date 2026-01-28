import 'package:vidviz/model/visualizer.dart';
import 'package:vidviz/service/visualizer_service.dart';

bool readCounterBool(
  VisualizerAsset asset,
  String key,
  bool defaultValue,
) {
  final v = asset.shaderParams != null ? asset.shaderParams![key] : null;
  return v is bool ? v : defaultValue;
}

String readCounterString(
  VisualizerAsset asset,
  String key,
  String defaultValue,
) {
  final v = asset.shaderParams != null ? asset.shaderParams![key] : null;
  return v is String ? v : defaultValue;
}

double readCounterDouble(
  VisualizerAsset asset,
  String key,
  double defaultValue,
) {
  final v = asset.shaderParams != null ? asset.shaderParams![key] : null;
  return v is num ? v.toDouble() : defaultValue;
}

String readCounterSelected(VisualizerAsset asset, {String defaultValue = 'start'}) {
  final v = asset.shaderParams != null ? asset.shaderParams!['counterSelected'] : null;
  if (v is String && (v == 'start' || v == 'end')) return v;
  return defaultValue;
}

double readCounterPos01(VisualizerAsset asset, String key, double defaultValue) {
  final v = asset.shaderParams != null ? asset.shaderParams![key] : null;
  if (v is num) {
    return v.toDouble().clamp(0.0, 1.0);
  }
  return defaultValue.clamp(0.0, 1.0);
}

void updateCounterAsset(
  VisualizerService visualizerService,
  VisualizerAsset base,
  void Function(VisualizerAsset updated, Map<String, dynamic> params) updater,
) {
  final updated = VisualizerAsset.clone(base)..renderMode = 'counter';
  final params = Map<String, dynamic>.from(updated.shaderParams ?? {});
  updater(updated, params);
  updated.shaderParams = params;
  visualizerService.editingVisualizerAsset = updated;
}
