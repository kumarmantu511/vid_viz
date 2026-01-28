import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/ui/widgets/timeline/player_metrics.dart';

/// VisualStageEffect - Audio reactive shader that samples the current stage as texture
/// Designed for shaders under assets/shaders/visual/ that expect a sampler (s0)
class VisualStageEffect extends StatefulWidget {
  final List<double> frequencies;
  final String shaderPath; // name without .frag
  final Color color;
  final Color? gradientColor;
  final double intensity;
  final double speed;
  final double width;
  final double height;
  final int barCount;
  final bool mirror;
  final double rotation; // degrees
  // Overlay ayarlari (pro_nation shader icin)
  final String? centerImagePath;
  final Color? ringColor;  // Cember rengi (null = gokkusagi)
  final String? backgroundImagePath;

  const VisualStageEffect({
    Key? key,
    required this.frequencies,
    required this.shaderPath,
    this.color = const Color(0xFFFFFFFF),
    this.gradientColor,
    this.intensity = 1.0,
    this.speed = 1.0,
    this.width = 500,
    this.height = 250,
    this.barCount = 24,
    this.mirror = false,
    this.rotation = 0.0,
    this.centerImagePath,
    this.ringColor,
    this.backgroundImagePath,
  }) : super(key: key);

  @override
  State<VisualStageEffect> createState() => _VisualStageEffectState();
}

class _VisualStageEffectState extends State<VisualStageEffect>
    with SingleTickerProviderStateMixin {
  final directorService = locator.get<DirectorService>();
  ui.FragmentProgram? _program;
  ui.FragmentShader? _shader;
  bool _isLoading = true;
  String? _error;
  ui.Image? _stageImage;
  Timer? _stageTimer;
  late AnimationController _controller;
  ui.Image? _fallbackTransparent;
  // Overlay resimleri
  ui.Image? _centerImage;
  ui.Image? _bgImage;
  String? _loadedCenterPath;
  String? _loadedBgPath;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(days: 1))..repeat();
    _loadShader();
  }

  @override
  void didUpdateWidget(covariant VisualStageEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shaderPath != widget.shaderPath) {
      setState(() {
        _isLoading = true;
        _error = null;
        _program = null;
        _shader?.dispose();
        _shader = null;
      });
      _loadShader();
    }
    // Overlay resimleri degistiyse yeniden yukle
    if (oldWidget.centerImagePath != widget.centerImagePath) {
      _loadOverlayImage(widget.centerImagePath, 'center');
    }
    if (oldWidget.backgroundImagePath != widget.backgroundImagePath) {
      _loadOverlayImage(widget.backgroundImagePath, 'bg');
    }
  }

  Future<ui.Image> _createTransparent1x1() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = Colors.transparent;
    canvas.drawRect(const Rect.fromLTWH(0, 0, 1, 1), paint);
    final picture = recorder.endRecording();
    return picture.toImage(1, 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    _shader?.dispose();
    _stageImage?.dispose();
    _stageTimer?.cancel();
    _centerImage?.dispose();
    _bgImage?.dispose();
    super.dispose();
  }

  Future<void> _loadShader() async {
    try {
      ui.FragmentProgram? program;
      final candidates = [
        'assets/shaders/effects/${widget.shaderPath}.frag',
        'assets/shaders/visual/${widget.shaderPath}.frag',
        'assets/shaders/visualizer/${widget.shaderPath}.frag',
      ];
      for (final p in candidates) {
        try {
          program = await ui.FragmentProgram.fromAsset(p);
          break;
        } catch (_) {}
      }
      // Fallback to pro_nation if the requested shader is not bundled
      if (program == null) {
        try {
          program = await ui.FragmentProgram.fromAsset('assets/shaders/visual/pro_nation.frag');
        } catch (_) {}
      }
      if (program == null) throw Exception('Shader not found: ${widget.shaderPath}');
      _program = program;
      _shader = program.fragmentShader();
      // Prepare fallback transparent image for early frames
      _fallbackTransparent ??= await _createTransparent1x1();
      setState(() => _isLoading = false);

      // Nation-family visual shaders do not rely on stage texture anymore.
      // Avoid expensive RenderRepaintBoundary.toImage() capture for them.
      const nationVisuals = ['pro_nation'];
      if (nationVisuals.contains(widget.shaderPath)) {
        _stageTimer?.cancel();
        _stageImage?.dispose();
        _stageImage = null;
        // Overlay resimlerini yukle
        _loadOverlayImage(widget.centerImagePath, 'center');
        _loadOverlayImage(widget.backgroundImagePath, 'bg');
      } else {
        _startStageCapture();
      }
    } catch (e) {
      setState(() {
        _error = 'Shader load failed: $e';
        _isLoading = false;
      });
    }
  }

  void _startStageCapture() {
    _stageTimer?.cancel();
    // During export, ShaderEffectPlayer pauses live capture; here we also pause to rely on position$ rebuilds
    if (directorService.isGenerating) return;
    _stageTimer = Timer.periodic(const Duration(milliseconds: 33), (_) async {
      if (!mounted) return;
      if (directorService.isGenerating) return;
      final img = await _captureStageToImage();
      if (!mounted) return;
      if (img != null) {
        _stageImage?.dispose();
        _stageImage = img;
        setState(() {});
      }
    });
  }

  Future<ui.Image?> _captureStageToImage() async {
    try {
      final ctx = directorService.shaderCaptureKey.currentContext;
      if (ctx == null) return null;
      final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final dpr = PlayerLayout.devicePixelRatio(ctx);
      final image = await boundary.toImage(pixelRatio: dpr);
      return image;
    } catch (_) {
      return null;
    }
  }
  
  /// Overlay resimlerini dosyadan yukle
  Future<void> _loadOverlayImage(String? path, String type) async {
    if (path == null || path.isEmpty) {
      // Resim yok - temizle
      switch (type) {
        case 'center':
          _centerImage?.dispose();
          _centerImage = null;
          _loadedCenterPath = null;
          break;
        case 'bg':
          _bgImage?.dispose();
          _bgImage = null;
          _loadedBgPath = null;
          break;
      }
      if (mounted) setState(() {});
      return;
    }
    
    // Ayni path zaten yukluyse tekrar yukleme
    switch (type) {
      case 'center':
        if (_loadedCenterPath == path) return;
        break;
      case 'bg':
        if (_loadedBgPath == path) return;
        break;
    }
    
    try {
      final file = File(path);
      if (!await file.exists()) return;
      
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      
      if (!mounted) {
        image.dispose();
        return;
      }
      
      switch (type) {
        case 'center':
          _centerImage?.dispose();
          _centerImage = image;
          _loadedCenterPath = path;
          break;
        case 'bg':
          _bgImage?.dispose();
          _bgImage = image;
          _loadedBgPath = path;
          break;
      }
      setState(() {});
    } catch (e) {
      print('Overlay resim yuklenemedi ($type): $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    if (_error != null || _program == null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: Center(child: Text(_error ?? 'Shader error', style: const TextStyle(color: Colors.red, fontSize: 12))),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      return StreamBuilder<int>(
        stream: directorService.position$,
        initialData: directorService.position,
        builder: (context, snapshot) {
          final time = (snapshot.data ?? 0) / 1000.0;
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                size: Size(widget.width, widget.height),
                painter: _VisualStagePainter(
                  program: _program!,
                  stageImage: _stageImage ?? _fallbackTransparent,
                  frequencies: widget.frequencies,
                  color: widget.color,
                  gradientColor: widget.gradientColor,
                  intensity: widget.intensity,
                  speed: widget.speed,
                  time: time,
                  barCount: widget.barCount,
                  mirror: widget.mirror,
                  rotation: widget.rotation,
                  centerImage: _centerImage,
                  ringColor: widget.ringColor,
                  bgImage: _bgImage,
                ),
              );
            },
          );
        },
      );
    });
  }
}

class _VisualStagePainter extends CustomPainter {
  final ui.FragmentProgram program;
  final ui.Image? stageImage;
  final List<double> frequencies;
  final Color color;
  final Color? gradientColor;
  final double intensity;
  final double speed;
  final double time;
  final int barCount;
  final bool mirror;
  final double rotation;
  // Overlay ayarlari
  final ui.Image? centerImage;
  final Color? ringColor;  // Cember rengi (null = gokkusagi)
  final ui.Image? bgImage;

  _VisualStagePainter({
    required this.program,
    required this.stageImage,
    required this.frequencies,
    required this.color,
    required this.gradientColor,
    required this.intensity,
    required this.speed,
    required this.time,
    required this.barCount,
    required this.mirror,
    required this.rotation,
    this.centerImage,
    this.ringColor,
    this.bgImage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();

    double safeNum(double v, double fallback, double min, double max) {
      final x = v.isFinite ? v : fallback;
      return x.clamp(min, max);
    }

    bool didRotate = false;
    final double safeRotation = safeNum(rotation, 0.0, 0.0, 360.0);
    if (safeRotation != 0.0) {
      final double rad = safeRotation * math.pi / 180.0;
      canvas.save();
      canvas.translate(size.width / 2, size.height / 2);
      canvas.rotate(rad);
      canvas.translate(-size.width / 2, -size.height / 2);
      didRotate = true;
    }

    int idx = 0;
    // uResolution
    shader.setFloat(idx++, size.width);
    shader.setFloat(idx++, size.height);
    // uTime
    shader.setFloat(idx++, time);
    // uIntensity
    shader.setFloat(idx++, safeNum(intensity, 1.0, 0.0, 2.0));
    // uSpeed
    shader.setFloat(idx++, safeNum(speed, 1.0, 0.0, 5.0));
    // uColor
    shader.setFloat(idx++, color.red / 255.0);
    shader.setFloat(idx++, color.green / 255.0);
    shader.setFloat(idx++, color.blue / 255.0);
    // uBars
    shader.setFloat(idx++, barCount.clamp(1, 256).toDouble());

    // FFT 8-band
    const sb = 8;
    final resampled = List<double>.filled(sb, 0.0);
    if (frequencies.isNotEmpty) {
      final n = frequencies.length;
      for (int i = 0; i < sb; i++) {
        final pos = i * (n - 1) / (sb - 1);
        final i0 = pos.floor();
        final i1 = math.min(i0 + 1, n - 1);
        final t = pos - i0;
        final v0 = safeNum(frequencies[i0], 0.0, 0.0, 1.0);
        final v1 = safeNum(frequencies[i1], 0.0, 0.0, 1.0);
        resampled[i] = v0 * (1.0 - t) + v1 * t;
      }
    }
    for (int i = 0; i < sb; i++) {
      double v = resampled[i];
      if (mirror && i >= sb ~/ 2) {
        v = resampled[sb - 1 - i];
      }
      try {
        shader.setFloat(idx++, v);
      } catch (_) {
        break;
      }
    }

    // Optional uColor2
    try {
      final gc = (gradientColor ?? color);
      shader.setFloat(idx++, gc.red / 255.0);
      shader.setFloat(idx++, gc.green / 255.0);
      shader.setFloat(idx++, gc.blue / 255.0);
    } catch (_) {}

    // Stage sampler at image slot 0 (if provided)
    if (stageImage != null) {
      try {
        shader.setImageSampler(0, stageImage!);
      } catch (_) {}
    }

    // Optional uAspect for aspect-ratio aware shaders
    try {
      final double aspect = size.height != 0.0 ? (size.width / size.height) : 1.0;
      shader.setFloat(idx++, aspect);
    } catch (_) {}
    
    // Overlay resimleri (pro_nation shader icin)
    // Sampler slot'lari: 0=stage, 1=center, 2=bg
    // Flutter Impeller TUM sampler'larin set edilmesini istiyor - null olsa bile fallback gerekli
    try {
      // Center image - her zaman set et (fallback: stage veya transparent)
      shader.setImageSampler(1, centerImage ?? stageImage!);
      // Background image - her zaman set et (fallback: stage veya transparent)
      shader.setImageSampler(2, bgImage ?? stageImage!);
    } catch (_) {}
    
    // uHasCenter, uHasBg flag'leri ve uRingColor
    try {
      shader.setFloat(idx++, centerImage != null ? 1.0 : 0.0);  // uHasCenter
      shader.setFloat(idx++, bgImage != null ? 1.0 : 0.0);      // uHasBg
      // Ring color (null = gokkusagi, -1 olarak gonder)
      if (ringColor != null) {
        shader.setFloat(idx++, ringColor!.red / 255.0);   // uRingColorR
        shader.setFloat(idx++, ringColor!.green / 255.0); // uRingColorG
        shader.setFloat(idx++, ringColor!.blue / 255.0);  // uRingColorB
        shader.setFloat(idx++, 1.0);                       // uHasRingColor
      } else {
        shader.setFloat(idx++, 0.0);  // uRingColorR
        shader.setFloat(idx++, 0.0);  // uRingColorG
        shader.setFloat(idx++, 0.0);  // uRingColorB
        shader.setFloat(idx++, 0.0);  // uHasRingColor (gokkusagi)
      }
    } catch (_) {}

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
    if (didRotate) canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _VisualStagePainter oldDelegate) => true;
}
