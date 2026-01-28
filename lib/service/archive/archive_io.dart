import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ArchiveIO {
  static Future<Directory> getDefaultExportDirectory() async {
    if (Platform.isAndroid) {
      try {
        await Permission.storage.request();
        final downloads = Directory('/storage/emulated/0/Download');
        if (await _ensureDirWritable(downloads)) return downloads;
      } catch (_) {}
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      try {
        final d = await getDownloadsDirectory();
        if (d != null && await _ensureDirWritable(d)) return d;
      } catch (_) {}
    }
    final appDir = await getApplicationDocumentsDirectory();
    final outDir = Directory(p.join(appDir.path, 'exports'));
    await outDir.create(recursive: true);
    return outDir;
  }

  static Future<bool> _ensureDirWritable(Directory dir) async {
    try {
      await dir.create(recursive: true);
      final probe = File(p.join(dir.path, '.vvz_write_probe'));
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  static String norm(String s) => p.normalize(s).replaceAll('\\', '/');
  static String safeName(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9_\- ]+'), '').trim().replaceAll(' ', '_');

  static bool isVideo(String path) {
    final e = p.extension(path).toLowerCase();
    return ['.mp4', '.mov', '.m4v', '.webm', '.avi', '.mkv'].contains(e);
  }

  static bool isAudio(String path) {
    final e = p.extension(path).toLowerCase();
    return ['.mp3', '.aac', '.wav', '.m4a', '.ogg', '.flac'].contains(e);
  }

  static Future<String> hashFile(File f) async {
    final digest = await crypto.sha256.bind(f.openRead()).first;
    return digest.toString();
  }
}
