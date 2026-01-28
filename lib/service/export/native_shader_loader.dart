import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

class NativeExportShaderLoader {
  final Logger logger;

  NativeExportShaderLoader(this.logger);

  Future<String?> tryLoadShaderSource(String type) async {
    final normalizedType = type.trim();
    if (normalizedType.isEmpty) return null;
    final hasPath = normalizedType.contains('/');
    final pureType = hasPath ? normalizedType.split('/').last : normalizedType;

    final String? compiledBase = Platform.isIOS ? 'assets/native/ios' : (Platform.isAndroid ? 'assets/native/android' : null);
    final String? compiledExt = Platform.isIOS ? 'metal' : (Platform.isAndroid ? 'glsl' : null);

    final compiledCandidates = <String>[
      if (compiledBase != null && compiledExt != null) ...[
        if (hasPath) '$compiledBase/$normalizedType.$compiledExt',
        '$compiledBase/effects/$pureType.$compiledExt',
        '$compiledBase/filters/$pureType.$compiledExt',
        '$compiledBase/visual/$pureType.$compiledExt',
        '$compiledBase/text/$pureType.$compiledExt',
        '$compiledBase/visualizer/$pureType.$compiledExt',
        '$compiledBase/$pureType.$compiledExt',
      ],
    ];

    for (final path in compiledCandidates) {
      try {
        final ByteData data = await rootBundle.load(path);
        final String src = utf8.decode(data.buffer.asUint8List());
        if (src.isNotEmpty) {
          logger.i('✅ Shader yuklendi: $path');
          return src;
        }
      } catch (_) {
        continue;
      }
    }

    logger.e('❌ KRITIK: "$pureType" shader dosyası hiçbir klasörde bulunamadı!');
    return null;
  }
}
