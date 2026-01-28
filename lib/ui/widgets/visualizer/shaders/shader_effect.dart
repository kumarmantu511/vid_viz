import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/director_service.dart';

/// ShaderEffect - Base shader visualizer widget
/// GPU-accelerated audio reactive shader effects
class ShaderEffect extends StatefulWidget {
  final List<double> frequencies;
  final String shaderPath;
  final Color color;
  final Color? gradientColor; // optional secondary color
  final double intensity;
  final double speed;
  final double? barFill;
  final double? glow;
  final double? strokeWidth;
  final double width;
  final double height;
  final int barCount;
  final bool mirror;
  final double rotation; // degrees
  // Optional progress uniforms for non-audio shaders (e.g. progress bars)
  final double? progress;
  final double? style;
  final double? thickness;
  final double? trackOpacity;
  final double? corner;
  final double? gap;
  final double? theme;
  final double? effectAmount;
  final Color? trackColor;
  final double? headAmount;
  final double? headSize;
  final double? headStyle;
  // Glow is handled inside shaders or canvas effects; no external blur in shader mode

  const ShaderEffect({
    Key? key,
    required this.frequencies,
    required this.shaderPath,
    this.color = const Color(0xFFFFFFFF),
    this.gradientColor,
    this.intensity = 1.0,
    this.speed = 1.0,
    this.barFill,
    this.glow,
    this.strokeWidth,
    this.width = 300,
    this.height = 150,
    this.barCount = 24,
    this.mirror = false,
    this.rotation = 0.0,
    this.progress,
    this.style,
    this.thickness,
    this.trackOpacity,
    this.corner,
    this.gap,
    this.theme,
    this.effectAmount,
    this.trackColor,
    this.headAmount,
    this.headSize,
    this.headStyle,
  }) : super(key: key);

  @override
  State<ShaderEffect> createState() => _ShaderEffectState();
}

class _ShaderEffectState extends State<ShaderEffect> with SingleTickerProviderStateMixin {
  final directorService = locator.get<DirectorService>();
  late AnimationController _controller;
  ui.FragmentProgram? _program;
  bool _isLoading = true;
  String? _error;
  ui.Image? _fallbackSound;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(days: 1), // Sürekli çalışsın
    )..repeat();
    _loadShader();
    _createTransparent1x1().then((img) {
      if (!mounted) {
        img.dispose();
        return;
      }
      _fallbackSound?.dispose();
      _fallbackSound = img;
      setState(() {});
    });
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
  void didUpdateWidget(covariant ShaderEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Shader dosyası değiştiyse yeniden yükle
    if (oldWidget.shaderPath != widget.shaderPath) {
      setState(() {
        _isLoading = true;
        _error = null;
        _program = null;
      });
      _loadShader();
    }
  }

  Future<void> _loadShader() async {
    try {
    /// geçici devre dışı log  print('🎨 Shader yükleniyor: ${widget.shaderPath}');
    /// geçici devre dışı log  print('📁 Shader paths: assets/shaders/visual/${widget.shaderPath}.frag | assets/shaders/visualizer/${widget.shaderPath}.frag');
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
        } catch (_) {
          // try next
        }
      }
      if (program == null) {
        try {
          program = await ui.FragmentProgram.fromAsset('assets/shaders/visual/pro_nation.frag');
        } catch (_) {}
      }
      if (program == null) throw Exception('Shader not found for ${widget.shaderPath}');
      setState(() {
        _program = program;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Shader yüklenemedi: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _fallbackSound?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_error != null || _program == null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: Center(
          child: Text(
            _error ?? 'Shader yüklenemedi',
            style: const TextStyle(color: Colors.red, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return StreamBuilder<int>(
      stream: directorService.position$,
      initialData: directorService.position,
      builder: (context, snapshot) {
        // Use timeline position for deterministic shader time (critical for export)
        // Do NOT multiply by speed here; pass speed as separate uniform to avoid double-scaling
        final position = snapshot.data ?? 0;
        final time = (position / 1000.0);
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              size: Size(widget.width, widget.height),
              painter: ShaderPainter(
                program: _program!,
                shaderPath: widget.shaderPath,
                soundImage: _fallbackSound,
                frequencies: widget.frequencies,
                color: widget.color,
                gradientColor: widget.gradientColor,
                intensity: widget.intensity,
                speed: widget.speed,
                barFill: widget.barFill,
                glow: widget.glow,
                strokeWidth: widget.strokeWidth,
                time: time,
                barCount: widget.barCount,
                mirror: widget.mirror,
                rotation: widget.rotation,
                progress: widget.progress,
                style: widget.style,
                thickness: widget.thickness,
                trackOpacity: widget.trackOpacity,
                corner: widget.corner,
                gap: widget.gap,
                theme: widget.theme,
                effectAmount: widget.effectAmount,
                trackColor: widget.trackColor,
                headAmount: widget.headAmount,
                headSize: widget.headSize,
                headStyle: widget.headStyle,
              ),
            );
          },
        );
      },
    );
  }
}

class ShaderPainter extends CustomPainter {
  final ui.FragmentProgram program;
  final String shaderPath;
  final ui.Image? soundImage;
  final List<double> frequencies;
  final Color color;
  final Color? gradientColor; // optional secondary color for uColor2
  final double intensity;
  final double speed;
  final double? barFill;
  final double? glow;
  final double? strokeWidth;
  final double time;
  final int barCount;
  final bool mirror;
  final double rotation; // degrees
  final double? progress;
  final double? style;
  final double? thickness;
  final double? trackOpacity;
  final double? corner;
  final double? gap;
  final double? theme;
  final double? effectAmount;
  final Color? trackColor;
  final double? headAmount;
  final double? headSize;
  final double? headStyle;

  ShaderPainter({
    required this.program,
    required this.shaderPath,
    required this.soundImage,
    required this.frequencies,
    required this.color,
    required this.gradientColor,
    required this.intensity,
    required this.speed,
    required this.barFill,
    required this.glow,
    required this.strokeWidth,
    required this.time,
    required this.barCount,
    required this.mirror,
    required this.rotation,
    this.progress,
    this.style,
    this.thickness,
    this.trackOpacity,
    this.corner,
    this.gap,
    this.theme,
    this.effectAmount,
    this.trackColor,
    this.headAmount,
    this.headSize,
    this.headStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();

    double safeNum(double v, double fallback, double min, double max) {
      final x = v.isFinite ? v : fallback;
      return x.clamp(min, max);
    }

    // Ensure sampler(0) is always bound for shaders that declare iChannel0.
    // Visualizer Shadertoy conversions may ignore the sampler content but Impeller requires a binding.
    if (soundImage != null) {
      try {
        shader.setImageSampler(0, soundImage!);
      } catch (_) {}
    }

    // Apply rotation around center if requested
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

    // Shader uniform'larını ayarla (Flutter shader format)
    int uniformIndex = 0;
    
    // uResolution (vec2) - shader matematiği görünür boyuta göre
    shader.setFloat(uniformIndex++, size.width);
    shader.setFloat(uniformIndex++, size.height);
    
    // uTime (float)
    shader.setFloat(uniformIndex++, time);
    
    // uIntensity (float)
    shader.setFloat(uniformIndex++, safeNum(intensity, 1.0, 0.0, 2.0));

    // uSpeed (float)
    shader.setFloat(uniformIndex++, safeNum(speed, 1.0, 0.0, 5.0));

    // uColor (vec3)
    shader.setFloat(uniformIndex++, color.red / 255.0);
    shader.setFloat(uniformIndex++, color.green / 255.0);
    shader.setFloat(uniformIndex++, color.blue / 255.0);

    // uBars (float)
    shader.setFloat(uniformIndex++, barCount.clamp(1, 256).toDouble());

    // FFT verilerini gönder (8 frekans)
    // barCount'a göre FFT verisini yeniden örnekle
    const int shaderBands = 8;
    List<double> resampledFFT = List.filled(shaderBands, 0.0);
    
    if (frequencies.isNotEmpty) {
      // barCount'a göre FFT'yi yeniden örnekle
      int sourceCount = frequencies.length;
      for (int i = 0; i < shaderBands; i++) {
        // Her shader bandı için kaynak FFT'den örnekle
        double pos = i * (sourceCount - 1) / (shaderBands - 1);
        int i0 = pos.floor();
        int i1 = math.min(i0 + 1, sourceCount - 1);
        double t = pos - i0;
        
        double v0 = safeNum(frequencies[i0], 0.0, 0.0, 1.0);
        double v1 = safeNum(frequencies[i1], 0.0, 0.0, 1.0);
        resampledFFT[i] = v0 * (1.0 - t) + v1 * t;
      }
    }

    // Mirror efekti: sağ yarıyı sol yarının aynası yap
    for (int i = 0; i < shaderBands; i++) {
      double freqValue = resampledFFT[i];
      
      if (mirror && i >= shaderBands ~/ 2) {
        int mirrorIndex = shaderBands - 1 - i;
        freqValue = resampledFFT[mirrorIndex];
      }
      
      try {
        shader.setFloat(uniformIndex, freqValue);
        uniformIndex++;
      } catch (e) {
        // Uniform sınırı aşıldı (ör: uBars optimize edilmiş, toplam float sayısı 16 kaldı)
        // Daha fazla setFloat denemeyi bırak
        if (i == 0) {
          print('⚠️ Shader uniform sınırı: FFT yazımı $uniformIndex indexinden itibaren durduruldu. Hata: $e');
        }
        break;
      }
    }
    // Optional uColor2 (vec3): write safely AFTER FFT uniforms
    // If shader doesn't declare uColor2, setFloat will throw; ignore.
    {
      final int start = uniformIndex;
      int idx = start;
      try {
        final Color gc = (gradientColor ?? color);
        shader.setFloat(idx++, gc.red / 255.0);
        shader.setFloat(idx++, gc.green / 255.0);
        shader.setFloat(idx++, gc.blue / 255.0);
        uniformIndex = idx;
      } catch (_) {
        uniformIndex = start;
      }
    }

    final String sid = shaderPath;

    final bool isLineFamily = sid == 'line' ||sid == 'smooth' || sid == 'wave' || sid == 'curves' || sid == 'wav' || sid == 'sinus';
    final bool isBarFamily  = sid == 'bar' || sid == 'bar_normal' || sid == 'bar_colors' || sid == 'claude' || sid == 'bar_circle'|| sid == 'circle';

    if (isBarFamily) {
      // bar.frag: ... uColor2, uBarFill, uGlow
      final int start = uniformIndex;
      try {
        shader.setFloat(uniformIndex++, safeNum(glow ?? 0.0, 0.0, 0.0, 1.0));
        shader.setFloat(uniformIndex++, safeNum(barFill ?? 0.75, 0.75, 0.0, 1.0));
      } catch (_) {
        uniformIndex = start;
      }
    } if (isLineFamily) {
      // line/wave/curves/wav/sinus: ... uColor2, uStroke
      final int start = uniformIndex;
      try {
        shader.setFloat(uniformIndex++, safeNum(glow ?? 0.0, 0.0, 0.0, 1.0));
        shader.setFloat(uniformIndex++, safeNum(strokeWidth ?? 2.5, 2.5, 0.0, 20.0));
      } catch (_) {
        uniformIndex = start;
      }
    }

    // Optional progress/style/thickness/trackOpacity/corner/gap/theme/effectAmount/trackColor/head uniforms for non-audio shaders (e.g. progress bars)
    if (progress != null || style != null || thickness != null || trackOpacity != null || corner != null || gap != null || theme != null || effectAmount != null || trackColor != null || headAmount != null || headSize != null || headStyle != null) {
      final int start = uniformIndex;
      int idx = start;
      try {
        // progress.frag declares uAspect immediately after uColor2.
        final double safeH = size.height == 0.0 ? 1.0 : size.height;
        shader.setFloat(idx++, size.width / safeH);
        shader.setFloat(idx++, progress ?? 0.0);
        shader.setFloat(idx++, style ?? 0.0);
        shader.setFloat(idx++, thickness ?? 0.0);
        shader.setFloat(idx++, trackOpacity ?? 0.35);
        shader.setFloat(idx++, corner ?? 0.7);
        shader.setFloat(idx++, gap ?? 0.25);
        shader.setFloat(idx++, theme ?? 0.0);
        shader.setFloat(idx++, effectAmount ?? 1.0);
        final Color tc = trackColor ?? const Color(0x00000000);
        shader.setFloat(idx++, tc.red / 255.0);
        shader.setFloat(idx++, tc.green / 255.0);
        shader.setFloat(idx++, tc.blue / 255.0);
        shader.setFloat(idx++, headAmount ?? 0.0);
        shader.setFloat(idx++, headSize ?? 0.5);
        shader.setFloat(idx++, headStyle ?? 1.0);
        uniformIndex = idx;
      } catch (_) {
        uniformIndex = start;
      }
    }

    // External blur devre dışı; doğrudan görünür dikdörtgene çiz
    final paint = Paint()..shader = shader;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    if (didRotate) {
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ShaderPainter oldDelegate) {
    return true; // Her frame yeniden çiz
  }
}
