import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'package:vidviz/model/layer.dart';
import 'package:vidviz/model/shader_effect.dart';

/// ShaderEffectService - Text pattern'i (basit ve temiz)
class ShaderEffectService {
  // Düzenlenen shader effect asset (Text'teki editingTextAsset gibi)
  BehaviorSubject<ShaderEffectAsset?> _editingShaderEffectAsset = BehaviorSubject.seeded(null);
  Stream<ShaderEffectAsset?> get editingShaderEffectAsset$ => _editingShaderEffectAsset.stream;
  ShaderEffectAsset? get editingShaderEffectAsset => _editingShaderEffectAsset.value;
  set editingShaderEffectAsset(ShaderEffectAsset? value) {
    _editingShaderEffectAsset.add(value);
    if (value != null) {
      _updateShaderParams(value);
    }
  }

  // Shader preview için gerçek zamanlı parametreler
  BehaviorSubject<Map<String, dynamic>> _shaderParams = BehaviorSubject.seeded({});
  Stream<Map<String, dynamic>> get shaderParams$ => _shaderParams.stream;

  dispose() {
    _editingShaderEffectAsset.close();
    _shaderParams.close();
  }

  /// Shader effect eklemeye başla (Text pattern'i - basit)
  Future<void> startAddingShaderEffect(List<Asset> availableMediaSources) async {
    // İlk media kaynağını kullan (varsa)
    String mediaPath = '';
    int duration = 5000;
    
    if (availableMediaSources.isNotEmpty) {
      Asset firstMediaSource = availableMediaSources.first;
      mediaPath = firstMediaSource.srcPath;
      duration = firstMediaSource.duration;
    }

    // Yeni shader effect asset oluştur
    editingShaderEffectAsset = ShaderEffectAsset(
      type: ShaderEffectType.rain,
      srcPath: mediaPath,
      title: 'Rain Effect',
      duration: duration,
      begin: 0,
      intensity: 0.7,
      speed: 1.5,
      size: 1.0,
      density: 0.6,
      angle: 15.0,
      color: 0xFFCCCCFF,
    );
  }
  
  /// Shader type değiştir (basit)
  void changeShaderType(String shaderType) {
    if (editingShaderEffectAsset == null) return;
    
    ShaderEffectAsset newAsset = ShaderEffectAsset.clone(editingShaderEffectAsset!);
    newAsset.type = shaderType;
    newAsset.title = ShaderEffectType.getDisplayName(shaderType);
    
    // Shader type'a göre varsayılan parametreleri ayarla
    _setDefaultParamsForShaderType(newAsset, shaderType);
    
    editingShaderEffectAsset = newAsset;
  }

  /// Media kaynağını değiştir (basit)
  void changeMediaSource(String mediaPath, int duration) {
    if (editingShaderEffectAsset == null) return;
    
    ShaderEffectAsset newAsset = ShaderEffectAsset.clone(editingShaderEffectAsset!);
    newAsset.srcPath = mediaPath;
    newAsset.duration = duration;
    editingShaderEffectAsset = newAsset;
  }

  /// Shader parametrelerini güncelle
  void updateShaderParam(String paramName, dynamic value) {
    if (editingShaderEffectAsset == null) return;
    
    ShaderEffectAsset newAsset = ShaderEffectAsset.clone(editingShaderEffectAsset!);
    
    // Parametreleri direkt ShaderEffectAsset field'larına ata
    switch (paramName) {
      case 'intensity':
        newAsset.intensity = value;
        break;
      case 'speed':
        newAsset.speed = value;
        break;
      case 'size':
        newAsset.size = value;
        break;
      case 'density':
        newAsset.density = value;
        break;
      case 'angle':
        newAsset.angle = value;
        break;
      case 'frequency':
        newAsset.frequency = value;
        break;
      case 'amplitude':
        newAsset.amplitude = value;
        break;
      case 'blurRadius':
        newAsset.blurRadius = value;
        break;
      case 'vignetteSize':
        newAsset.vignetteSize = value;
        break;
      case 'color':
        newAsset.color = value;
        break;
    }
    
    editingShaderEffectAsset = newAsset;
  }

  /// Shader parametrelerini stream'e gönder (preview için)
  void _updateShaderParams(ShaderEffectAsset asset) {
    Map<String, dynamic> params = {
      'type': asset.type,
      'intensity': asset.intensity,
      'speed': asset.speed,
      'size': asset.size,
      'density': asset.density,
      'angle': asset.angle,
      'frequency': asset.frequency,
      'amplitude': asset.amplitude,
      'blurRadius': asset.blurRadius,
      'vignetteSize': asset.vignetteSize,
      'color': asset.color,
      'alpha': asset.alpha,
    };
    _shaderParams.add(params);
  }

  /// Shader type'a göre varsayılan parametreleri ayarla
  void _setDefaultParamsForShaderType(ShaderEffectAsset asset, String shaderType) {
    switch (shaderType) {
      case ShaderEffectType.rain:
        asset.intensity = 0.7;
        asset.speed = 1.5;
        asset.size = 1.0;
        asset.density = 0.6;
        asset.angle = 15.0;
        asset.color = 0xFFCCCCFF;
        break;
      case ShaderEffectType.snow:
        asset.intensity = 0.5;
        asset.speed = 0.8;
        asset.size = 1.2;
        asset.density = 0.5;
        asset.color = 0xFFFFFFFF;
        break;
      case ShaderEffectType.water:
        asset.intensity = 0.6;
        asset.speed = 1.0;
        asset.frequency = 2.0;
        asset.amplitude = 0.3;
        break;
      case ShaderEffectType.blur:
        asset.intensity = 0.5;
        asset.blurRadius = 8.0;
        break;
      case ShaderEffectType.vignette:
        asset.intensity = 0.6;
        asset.vignetteSize = 0.5;
        asset.color = 0xFF000000;
        break;
    }
  }

  /// ShaderEffectAsset'ten Asset'e dönüştür (timeline/database için)
  Asset shaderEffectToAsset(ShaderEffectAsset shaderEffect) {
    return Asset(
      type: AssetType.shader,
      srcPath: shaderEffect.srcPath,
      title: shaderEffect.title,
      duration: shaderEffect.duration,
      begin: shaderEffect.begin,
      data: {
        'shader': shaderEffect.toJson(),
      },
    );
  }

  /// Asset'ten ShaderEffectAsset'e dönüştür (timeline'dan yükleme için)
  ShaderEffectAsset assetToShaderEffect(Asset asset) {
    if (asset.data != null && asset.data!['shader'] != null) {
      final Map<String, dynamic> m = Map<String, dynamic>.from(asset.data!['shader']);
      return ShaderEffectAsset.fromJson(m);
    }
    // Fallback default (new assets before saved)
    return ShaderEffectAsset(
      type: ShaderEffectType.rain,
      srcPath: asset.srcPath,
      title: asset.title,
      duration: asset.duration,
      begin: asset.begin,
    );
  }
}
