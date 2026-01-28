import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'package:vidviz/model/text_asset.dart';
import 'text_effect_painter.dart';
import '../../../core/constants.dart';

class TextEffectPlayer extends StatefulWidget {
  final TextAsset asset;
  final double playerWidth;
  final double? timeSecOverride; // if provided, use this time instead of local ticker
  const TextEffectPlayer(this.asset, {Key? key, required this.playerWidth, this.timeSecOverride}) : super(key: key);

  @override
  State<TextEffectPlayer> createState() => _TextEffectPlayerState();
}

class _TextEffectPlayerState extends State<TextEffectPlayer>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  double _time = 0.0;

  static int _boxParityUiCount = 0;

  ui.FragmentShader? _shader;
  late TextPainter _textPainter;

  // Simple in-memory cache for compiled shader programs by asset path
  static final Map<String, ui.FragmentProgram> _programCache = {};

  @override
  void initState() {
    super.initState();
    _buildTextPainter();
    _loadShader();
    if (widget.timeSecOverride == null) {
      _ticker = createTicker((elapsed) {
        if (!mounted) return;
        setState(() { _time = elapsed.inMicroseconds / 1e6; });
      })..start();
    }
  }

  @override
  void didUpdateWidget(covariant TextEffectPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.effectType != widget.asset.effectType) {
      _loadShader();
    }
    _buildTextPainter();
    // Manage ticker based on override usage changes
    if (oldWidget.timeSecOverride == null && widget.timeSecOverride != null) {
      _ticker?.stop();
      _ticker?.dispose();
      _ticker = null;
    } else if (oldWidget.timeSecOverride != null && widget.timeSecOverride == null) {
      _ticker ??= createTicker((elapsed) {
        if (!mounted) return;
        setState(() { _time = elapsed.inMicroseconds / 1e6; });
      });
      if (!(_ticker!.isActive)) _ticker!.start();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  void _buildTextPainter() {
    // Fallback font safety
    var font = Font.allFonts.first;
    try {
      font = Font.getByPath(widget.asset.font);
    } catch (_) {}
    final fs = widget.asset.fontSize.isFinite ? widget.asset.fontSize : 0.1;
    final style = TextStyle(
      height: 1,
      fontSize: math.max(1.0, fs),
      fontStyle: font.style,
      fontFamily: font.family,
      fontWeight: font.weight,
    );
    _textPainter = TextPainter(
      text: TextSpan(text: widget.asset.title, style: style),
      textDirection: TextDirection.ltr,
    );
    _textPainter.layout();
  }

  Future<void> _loadShader() async {
    final type = widget.asset.effectType;
    if (type == 'none' || type.isEmpty) {
      if (!mounted) return;
      setState(() {
        _shader = null;
      });
      return;
    }
    // Painter-only effects (no shader needed)
    if (type == 'inner_glow' || type == 'inner_shadow') {
      if (!mounted) return;
      setState(() {
        _shader = null;
      });
      return;
    }

    String path;
    switch (type) {
      case 'gradient_fill':
        path = 'assets/shaders/text/gradient_fill.frag';
        break;
      case 'wave_fill':
        path = 'assets/shaders/text/wave_fill.frag';
        break;
      case 'glitch_fill':
        path = 'assets/shaders/text/glitch_fill.frag';
        break;
      case 'neon_glow':
        path = 'assets/shaders/text/neon_glow.frag';
        break;
      case 'metallic_fill':
        path = 'assets/shaders/text/metallic_fill.frag';
        break;
      case 'rainbow_fill':
        path = 'assets/shaders/text/rainbow_fill.frag';
        break;
      case 'chrome_bevel':
        path = 'assets/shaders/text/chrome_bevel.frag';
        break;
      case 'scanlines':
        path = 'assets/shaders/text/scanlines.frag';
        break;
      case 'rgb_shift':
        path = 'assets/shaders/text/rgb_shift.frag';
        break;
      case 'duotone_map':
        path = 'assets/shaders/text/duotone_map.frag';
        break;
      case 'holo_scan':
        path = 'assets/shaders/text/holo_scan.frag';
        break;
      case 'noise_flow':
        path = 'assets/shaders/text/noise_flow.frag';
        break;
      case 'sparkle_glint':
        path = 'assets/shaders/text/sparkle_glint.frag';
        break;
      case 'liquid_distort':
        path = 'assets/shaders/text/liquid_distort.frag';
        break;
      default:
        path = 'assets/shaders/text/gradient_fill.frag';
    }

    try {
      final p = _programCache[path] ?? await ui.FragmentProgram.fromAsset(path);
      _programCache[path] = p;
      final s = p.fragmentShader();
      if (!mounted) return;
      setState(() {
        _shader = s;
      });
    } catch (_) {
      // Fallback to gradient_fill if specific shader missing
      try {
        final fp = 'assets/shaders/text/gradient_fill.frag';
        final p = _programCache[fp] ?? await ui.FragmentProgram.fromAsset(fp);
        _programCache[fp] = p;
        final s = p.fragmentShader();
        if (!mounted) return;
        setState(() {
          _shader = s;
        });
      } catch (__) {
        if (!mounted) return;
        setState(() {
          _shader = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Scale font size to player width like other text widgets do
    final double pw = widget.playerWidth > 1 ? widget.playerWidth : 1.0;
    final double ts = (MediaQuery.maybeOf(context)?.textScaleFactor ?? 1.0);
    final scaled = math.max(1.0, widget.asset.fontSize * pw / (ts > 0 ? ts : 1.0));
    // Safe font fallback
    var font = Font.allFonts.first;
    try {
      font = Font.getByPath(widget.asset.font);
    } catch (_) {
      // keep default
    }
    final double gAlpha = widget.asset.alpha.clamp(0.0, 1.0);
    Color _mulOpacity(Color c, double m) => c.withOpacity((c.opacity * m).clamp(0.0, 1.0));
    final textStyle = TextStyle(
      height: 1,
      fontSize: scaled,
      fontStyle: font.style,
      fontFamily: font.family,
      fontWeight: font.weight,
      color: _mulOpacity(Color(widget.asset.fontColor), gAlpha),
    );

    final painter = TextEffectPainter(
      asset: widget.asset,
      shader: _shader,
      time: widget.timeSecOverride ?? _time,
      textStyle: textStyle,
      title: widget.asset.title,
    );

    // Re-measure with scaled font
    final tp = TextPainter(
      text: TextSpan(text: widget.asset.title, style: textStyle),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    final rawSize = tp.size;
    if (!rawSize.width.isFinite || !rawSize.height.isFinite || rawSize.width <= 0 || rawSize.height <= 0) {
      return const SizedBox(width: 1, height: 1);
    }

    Rect tight = Offset.zero & rawSize;
    if (widget.asset.title.isNotEmpty) {
      final boxes = tp.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: widget.asset.title.length),
      );
      if (boxes.isNotEmpty) {
        Rect r = boxes.first.toRect();
        for (final b in boxes.skip(1)) {
          r = r.expandToInclude(b.toRect());
        }
        if (r.width.isFinite && r.height.isFinite && !r.isEmpty) {
          tight = r;
        }
      }
    }

    final textSize = Size(tight.width, tight.height);

    final double bp = (widget.asset.box && widget.asset.boxPad.isFinite)
        ? widget.asset.boxPad.clamp(0.0, 30.0)
        : 0.0;
    final size = Size(textSize.width + 2 * bp, textSize.height + 2 * bp);
    if (_boxParityUiCount < 20 && widget.asset.box) {
      _boxParityUiCount++;
      print(
        'BOX_PARITY ui titleLen=${widget.asset.title.length} boxPadUi=${bp.toStringAsFixed(3)} '
        'textSize=${textSize.width.toStringAsFixed(3)}x${textSize.height.toStringAsFixed(3)} '
        'paintSize=${size.width.toStringAsFixed(3)}x${size.height.toStringAsFixed(3)}',
      );
    }

    return CustomPaint(
      size: size,
      painter: painter,
    );
  }
}

// Painter moved to: text_effect_painter.dart
