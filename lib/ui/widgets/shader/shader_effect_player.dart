import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/service/shader_effect_service.dart';
import 'package:vidviz/model/shader_effect.dart';
import 'package:vidviz/model/layer.dart';
import 'package:vidviz/ui/widgets/timeline/player_metrics.dart';
import 'dart:io';

/// ShaderEffectPlayer - Shader preview widget
/// Real-time shader effect preview
class ShaderEffectPlayer extends StatefulWidget {
  final ShaderEffectAsset? asset;

  ShaderEffectPlayer({this.asset});

  @override
  _ShaderEffectPlayerState createState() => _ShaderEffectPlayerState();
}

class _ShaderEffectPlayerState extends State<ShaderEffectPlayer>
    with SingleTickerProviderStateMixin {
  final directorService = locator.get<DirectorService>();
  final shaderEffectService = locator.get<ShaderEffectService>();

  late AnimationController _animationController;
  ui.FragmentShader? _shader;
  ui.Image? _sourceImage;
  ShaderEffectAsset? _asset;
  bool _isLoading = true;
  StreamSubscription? _shaderParamsSubscription;
  Timer? _videoFrameTimer; // Video frame güncelleme timer'ı

  @override
  void initState() {
    super.initState();
    // Animation controller for timeline-based shader time (not wall-clock)
    // NOT started immediately - only when shader is loaded
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 10),
    );

    _loadShaderAndImage();

    // Listen to shader params changes (type, intensity, etc.)
    _shaderParamsSubscription = shaderEffectService.shaderParams$.listen((
      params,
    ) {
      // Shader type değişti mi?
      if (params['type'] != null && params['type'] != _asset?.type) {
        /// geçici devre dışı log  print('🔄 Shader type changed: ${_asset?.type} → ${params['type']}');
        setState(() {
          _isLoading = true;
        });
        _loadShaderAndImage();
      } else {
        // Sadece parametreler değişti, rebuild et
        if (mounted) {
          setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    // AnimationController'ı önce durdur, sonra dispose et
    _animationController.stop();
    _animationController.dispose();
    _shader?.dispose();
    _sourceImage?.dispose();
    _shaderParamsSubscription?.cancel();
    _videoFrameTimer?.cancel(); // Video frame timer'ı durdur
    super.dispose();
  }

  Future<void> _loadShaderAndImage() async {
    try {
      // Önce editing mode'u kontrol et
      if (shaderEffectService.editingShaderEffectAsset != null) {
        _asset = shaderEffectService.editingShaderEffectAsset;

        /// geçici devre dışı log   print('📝 Using editing asset: ${_asset!.type}');
      } else if (widget.asset != null) {
        _asset = widget.asset;

        /// geçici devre dışı log  print('📋 Using widget asset: ${_asset!.type}');
      } else {
        // Timeline'dan al
        Asset? timelineAsset = directorService.getAssetByPosition(
          4,
        ); // Layer 4 = shader
        if (timelineAsset != null && timelineAsset.type == AssetType.shader) {
          _asset = shaderEffectService.assetToShaderEffect(timelineAsset);

          /// geçici devre dışı log    print('⏱️ Using timeline asset: ${_asset!.type}');
        }
      }

      // Shader yoksa veya tip uyuşmuyorsa boş döndür
      if (_asset == null) {
        print('⚠️ No shader asset found');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      /// geçici devre dışı log    print('✅ Loading shader: ${_asset!.type}');

      // Load shader only from folder-structured paths (filters/, effects/)
      String shaderType = _asset!.type;
      if (shaderType == 'dispersion') shaderType = 'spectrum';
      final List<String> candidates = [
        'assets/shaders/filters/$shaderType.frag',
        'assets/shaders/effects/$shaderType.frag',
      ];

      ui.FragmentProgram? program;
      for (final path in candidates) {
        try {
          program = await ui.FragmentProgram.fromAsset(path);
          // print('✅ Loaded shader from: $path');
          break;
        } catch (_) {
          // try next
        }
      }
      if (program == null) {
        throw FlutterError(
          'Shader asset not found for type: $shaderType in candidates: ' +
              candidates.join(', '),
        );
      }
      _shader = program.fragmentShader();

      // Load source image/video thumbnail
      if (_asset!.srcPath.isNotEmpty && File(_asset!.srcPath).existsSync()) {
        String imagePath = _asset!.srcPath;

        try {
          // Image dosyası ise direkt yükle (yüksek kalite)
          if (imagePath.endsWith('.jpg') ||
              imagePath.endsWith('.png') ||
              imagePath.endsWith('.jpeg')) {
            /// geçici devre dışı log    print('📷 Loading image: $imagePath');
            final bytes = await File(imagePath).readAsBytes();
            // Yüksek kalite için tam çözünürlük kullan
            final codec = await ui.instantiateImageCodec(
              bytes,
              allowUpscaling: false, // Upscaling yapma
            );
            final frame = await codec.getNextFrame();
            _sourceImage = frame.image;

            /// geçici devre dışı log  print('✅ Image loaded: ${_sourceImage!.width}x${_sourceImage!.height}');
          }
          // Video dosyası ise - ŞEFFAFLIK İÇİN
          else if (imagePath.endsWith('.mp4') || imagePath.endsWith('.mov')) {
            print(
              '🎥 Video detected - using captured base stage as shader texture',
            );
            // Video/image sahnesini RepaintBoundary üzerinden yakalayarak shader'a texture veriyoruz
            final captured = await _captureStageToImage();
            if (captured != null) {
              _sourceImage?.dispose();
              _sourceImage = captured;

              /// geçici devre dışı log    print('✅ Captured stage: ${_sourceImage!.width}x${_sourceImage!.height}');
            } else {
              // Fallback: 1x1 transparent (ilk frame henüz hazır değilse)
              final recorder = ui.PictureRecorder();
              final canvas = Canvas(recorder);
              final paint = Paint()..color = Colors.transparent;
              canvas.drawRect(Rect.fromLTWH(0, 0, 1, 1), paint);
              final picture = recorder.endRecording();
              _sourceImage = await picture.toImage(1, 1);

              /// geçici devre dışı log    print('⚠️ Capture not ready, using transparent 1x1');
            }
          }
        } catch (e) {
          /// geçici devre dışı log   print('⚠️ Error loading media: $e');
        }
      }

      // If still no source image (e.g., no explicit srcPath or file missing),
      // capture the current base stage (background + video/image) via RepaintBoundary.
      // This ensures shader processes the visible media even when an image is selected
      // and no direct file texture was loaded.
      if (_sourceImage == null) {
        final captured = await _captureStageToImage();
        if (captured != null) {
          _sourceImage = captured;

          /// geçici devre dışı log    print('✅ Fallback captured stage as shader texture');
        }
      }

      // If no source image, create a ULTRA HIGH RESOLUTION test pattern
      if (_sourceImage == null) {
        /// geçici devre dışı log   print('⚠️ No source image, creating ULTRA HIGH-RES test pattern...');
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);

        // ULTRA yüksek çözünürlük: 2560x1440 (2K)
        const width = 2560.0;
        const height = 1440.0;

        // Daha detaylı gradient background
        final paint = Paint()
          ..shader = ui.Gradient.radial(
            Offset(width / 2, height / 2),
            width / 2,
            [
              Color(0xFF1E3A8A), // Dark blue
              Color(0xFF3B82F6), // Blue
              Color(0xFF8B5CF6), // Purple
              Color(0xFFEC4899), // Pink
            ],
            [0.0, 0.3, 0.6, 1.0],
          )
          ..filterQuality = FilterQuality.high;
        canvas.drawRect(Rect.fromLTWH(0, 0, width, height), paint);

        final picture = recorder.endRecording();
        _sourceImage = await picture.toImage(width.toInt(), height.toInt());

        /// geçici devre dışı log    print('✅ ULTRA HIGH-RES test pattern created: ${width.toInt()}x${height.toInt()}');
      }

      setState(() {
        _isLoading = false;
      });

      // Shader yüklendi - AnimationController'ı şimdi başlat
      if (!_animationController.isAnimating) {
        _animationController.repeat();
      }

      // Video frame'lerini sürekli güncelle (30 FPS)
      _startVideoFrameUpdates();
    } catch (e) {
      print('Error loading shader: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Video frame'lerini sürekli güncelle (only when NOT exporting)
  void _startVideoFrameUpdates() {
    _videoFrameTimer?.cancel();
    // Skip real-time updates during export (position$ stream drives updates instead)
    if (directorService.isGenerating) {
      print('⏸️ Video frame updates paused (export mode)');
      return;
    }
    print('🎬 Video frame updates started');
    _videoFrameTimer = Timer.periodic(const Duration(milliseconds: 33), (
      _,
    ) async {
      if (directorService.isGenerating) {
        _videoFrameTimer?.cancel();
        return;
      }
      final captured = await _captureStageToImage();
      if (!mounted) return;
      if (captured != null) {
        // Eski resmi serbest bırak
        _sourceImage?.dispose();
        _sourceImage = captured;
        // Yeniden çizim
        setState(() {});
      }
    });
  }

  /// RepaintBoundary üzerinden video/image sahnesini yakala
  Future<ui.Image?> _captureStageToImage() async {
    try {
      final ctx = directorService.shaderCaptureKey.currentContext;
      if (ctx == null) return null;
      final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final dpr = PlayerLayout.devicePixelRatio(ctx);
      final image = await boundary.toImage(pixelRatio: dpr);
      return image;
    } catch (e) {
      // Yakalama başarısız olabilir (ilk build sırasında vb.)
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    /// geçici devre dışı log   print('🔄 BUILD called - isLoading=$_isLoading');

    if (_isLoading) {
      /// geçici devre dışı log    print('⏳ Still loading...');
      return Center(child: CircularProgressIndicator()); // Loading göster
    }

    if (_shader == null || _sourceImage == null || _asset == null) {
      /// geçici devre dışı log   print('⚠️ Shader not ready: shader=${_shader != null}, image=${_sourceImage != null}, asset=${_asset != null}');
      return SizedBox.shrink(); // Shader yoksa boş döndür
    }

    /// geçici devre dışı log   print('🎨 Rendering shader: ${_asset!.type}, image size: ${_sourceImage!.width}x${_sourceImage!.height}');

    // ALWAYS use stream for real-time updates (both editing and timeline mode)
    return LayoutBuilder(
      builder: (context, constraints) {
        final double playerW = constraints.maxWidth;
        final double playerH = constraints.maxHeight;

        return StreamBuilder<Map<String, dynamic>>(
          stream: shaderEffectService.shaderParams$,
          initialData:
              (shaderEffectService.editingShaderEffectAsset ?? _asset)!.toParamsMap(),
          builder: (context, snapshot) {
            // Current asset (editing first)
            final currentAsset = shaderEffectService.editingShaderEffectAsset ?? _asset;
            if (currentAsset == null) return const SizedBox.shrink();

            final rawParams = snapshot.data ?? currentAsset.toParamsMap();
            final params = Map<String, dynamic>.of(rawParams);
            // Keep uniform layout in sync with compiled shader
            params['type'] = currentAsset.type;
            // Ensure alpha is always present for preview, even if upstream doesn't send it
            params['alpha'] = currentAsset.alpha;

            final double safeScale = (currentAsset.scale.isFinite ? currentAsset.scale : 1.0).clamp(0.1, 4.0);
            final double safeX = (currentAsset.x.isFinite ? currentAsset.x : 0.5).clamp(0.0, 1.0);
            final double safeY = (currentAsset.y.isFinite ? currentAsset.y : 0.5).clamp(0.0, 1.0);
            final double safeAlpha = (currentAsset.alpha.isFinite ? currentAsset.alpha : 1.0).clamp(0.0, 1.0);

            final double overlayW = playerW * safeScale;
            final double overlayH = playerH * safeScale;
            final double left = safeX * playerW - (overlayW / 2);
            final double top = safeY * playerH - (overlayH / 2);

            return StreamBuilder<int>(
              stream: directorService.position$,
              initialData: directorService.position,
              builder: (context, snapshot) {
                final position = snapshot.data ?? 0;
                final time = (position / 1000.0);

                return ClipRect(
                  child: SizedBox(
                    width: playerW,
                    height: playerH,
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned(
                          left: left,
                          top: top,
                          width: overlayW,
                          height: overlayH,
                          child: Opacity(
                            opacity: safeAlpha,
                            child: OverflowBox(
                              alignment: Alignment.center,
                              minWidth: 0,
                              minHeight: 0,
                              maxWidth: double.infinity,
                              maxHeight: double.infinity,
                              child: Transform.scale(
                                scale: safeScale,
                                alignment: Alignment.center,
                                child: SizedBox(
                                  width: playerW,
                                  height: playerH,
                                  child: AnimatedBuilder(
                                    animation: _animationController,
                                    builder: (context, _) {
                                      return CustomPaint(
                                        painter: ShaderPainter(
                                          shader: _shader!,
                                          sourceImage: _sourceImage,
                                          time: time,
                                          params: params,
                                        ),
                                        size: Size(playerW, playerH),
                                        isComplex: true,
                                        willChange: true,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class ShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final ui.Image? sourceImage;
  final double time;
  final Map<String, dynamic> params;

  ShaderPainter({
    required this.shader,
    required this.sourceImage,
    required this.time,
    required this.params,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double numVal(dynamic v, double fallback) {
      if (v is num) {
        final d = v.toDouble();
        return d.isFinite ? d : fallback;
      }
      return fallback;
    }

    // Use paint size as resolution to match FlutterFragCoord space
    final double resW = size.width;
    final double resH = size.height;

    // Determine shader type to map uniform layout
    String shaderType = ((params['type'] ?? 'rain') as String).trim().toLowerCase();
    // Normalize aliases (prevent uniform mismatch) - avoid substring collisions
    if (shaderType.startsWith('vign'))
      shaderType = 'vignette';
    else if (shaderType.startsWith('blur'))
      shaderType = 'blur';
    else if (shaderType == 'rain')
      shaderType = 'rain';
    else if (shaderType == 'snow')
      shaderType = 'snow';
    // IMPORTANT: keep 'wave_water' distinct; do NOT fold into 'water'
    else if (shaderType == 'wave_water')
      shaderType = 'wave_water';
    // Keep only exact 'water' folded; preserve distinct water_* shaders
    else if (shaderType == 'water')
      shaderType = 'water';
    else if (shaderType == 'dispersion')
      shaderType = 'spectrum';
    // fractal ve psychedelic kaldırıldı

    // Set shader uniforms (ordered by each shader's declared floats)
    shader.setFloat(0, resW); // resolution.x (uResolution/iResolution)
    shader.setFloat(1, resH); // resolution.y

    // Only these shaders declare time
    final bool hasTime =
        shaderType == 'rain' ||
        shaderType == 'rain_glass' ||
        shaderType == 'snow' ||
        shaderType == 'water' ||
        shaderType == 'sphere' ||
        shaderType == 'spectrum' ||
        shaderType == 'wave_water' ||
        shaderType == 'dunes' ||
        shaderType == 'film_grain' ||
        shaderType == 'wave_propagation' ||
        shaderType == 'water2d' ||
        shaderType == 'water_surface' ||
        shaderType == 'water_blobs' ||
        shaderType == 'fishe' ||
        shaderType == 'sfishe';
    int floatIndex = 2;
    if (hasTime) {
      shader.setFloat(2, time); // uTime/iTime
      floatIndex = 3;
    }

    // IMPORTANT: Set sampler AFTER floats
    shader.setImageSampler(0, sourceImage!);

    // Common intensity (immediately after time if present, else after resolution)
    final double intensity = numVal(params['intensity'], 0.5).clamp(0.0, 1.0);
    shader.setFloat(floatIndex++, intensity);

    switch (shaderType) {
      case 'rain':
        shader.setFloat(
          floatIndex++,
          numVal(params['speed'], 1.0).clamp(0.0, 5.0),
        );
        shader.setFloat(
          floatIndex++,
          numVal(params['size'], 1.0).clamp(0.0, 10.0),
        ); // uDropSize
        shader.setFloat(
          floatIndex++,
          numVal(params['density'], 0.5).clamp(0.0, 1.0),
        );
        break;

      case 'rain_glass':
        shader.setFloat(
          floatIndex++,
          numVal(params['speed'], 1.0).clamp(0.0, 5.0),
        );
        shader.setFloat(
          floatIndex++,
          numVal(params['size'], 1.0).clamp(0.0, 10.0),
        ); // uDropSize
        shader.setFloat(
          floatIndex++,
          numVal(params['density'], 0.5).clamp(0.0, 1.0),
        );
        break;

      case 'snow':
        shader.setFloat(
          floatIndex++,
          numVal(params['speed'], 1.0).clamp(0.0, 5.0),
        );
        shader.setFloat(
          floatIndex++,
          numVal(params['size'], 1.0).clamp(0.0, 10.0),
        ); // uFlakeSize
        shader.setFloat(
          floatIndex++,
          numVal(params['density'], 0.5).clamp(0.0, 1.0),
        );
        break;

      case 'water':
        // Water shader uniforms: uIntensity (already set), uSpeed, uFrequency, uAmplitude
        shader.setFloat(
          floatIndex++,
          numVal(params['speed'], 1.0).clamp(0.0, 5.0),
        ); // uSpeed
        shader.setFloat(
          floatIndex++,
          numVal(params['frequency'], 2.0).clamp(0.0, 50.0),
        ); // uFrequency
        shader.setFloat(
          floatIndex++,
          numVal(params['amplitude'], 0.3).clamp(0.0, 10.0),
        ); // uAmplitude
        break;

      case 'blur':
        shader.setFloat(
          floatIndex++,
          numVal(params['blurRadius'], 5.0).clamp(0.0, 100.0),
        );
        break;

      case 'vignette':
        // Do not set vignetteSize to avoid out-of-range if optimized out by compiler
        break;

      // fractal ve psychedelic kaldırıldı

      // New overlay types rely only on intensity (and optional time). No extra floats.
      case 'half_tone':
      case 'edge_detect':
      case 'tiles':
      case 'circle_radius':
      case 'dunes':
      case 'heat_vision':
      case 'spectrum':
      case 'wave_water':
      case 'sphere':
      case 'fishe':
      case 'sfishe':
        break;
    }

    // Draw shader with MAXIMUM quality settings (alpha kontrolü shader'da)
    final paint = Paint()
      ..shader = shader
      ..isAntiAlias = true // Anti-aliasing aktif
      ..filterQuality = FilterQuality.high // Yüksek kalite filtreleme
      ..blendMode = BlendMode.srcOver; // Video üzerine blend

    // Full screen rect
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(ShaderPainter oldDelegate) {
    // HER ZAMAN repaint et (animasyon için)
    return true;
  }
}
