import 'dart:async';
import 'package:logger/logger.dart';
import 'package:rxdart/rxdart.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:vidviz/service_locator.dart';

class Generator {
  final logger = locator.get<Logger>();
  final Map<String, bool> _audioStreamCache = {};

  final BehaviorSubject<FFmpegStat> _ffmepegStat = BehaviorSubject.seeded(
    FFmpegStat(),
  );
  Stream<FFmpegStat> get ffmepegStat$ => _ffmepegStat.stream;
  FFmpegStat get ffmepegStat => _ffmepegStat.value;

  Future<int> getVideoDuration(String path) async {
    try {
      final session = await FFprobeKit.getMediaInformation(path);
      final information = session.getMediaInformation();
      final duration = information?.getDuration();
      if (duration == null) return 0;
      // Duration'ı milisaniyeye çeviriyoruz (FFmpeg saniye cinsinden veriyor)
      return (double.parse(duration) * 1000).round();
    } catch (e) {
      try {
        logger.w('getVideoDuration error: $e');
      } catch (_) {}
      return 0;
    }
  }

  /// Returns true if the input media file has at least one audio stream
  Future<bool> hasAudioStream(String path) async {
    if (path.isEmpty) {
      return false;
    }
    if (_audioStreamCache.containsKey(path)) {
      return _audioStreamCache[path]!;
    }
    bool hasAudio = false;
    try {
      final session = await FFprobeKit.getMediaInformation(path);
      final info = session.getMediaInformation();
      final streams = info?.getStreams();
      if (streams == null) {
        _audioStreamCache[path] = false;
        return false;
      }
      for (final s in streams) {
        final t = (s.getType() ?? '').toString().toLowerCase();
        if (t == 'audio') {
          hasAudio = true;
          break;
        }
      }
    } catch (e) {
      try {
        logger.w('hasAudioStream error: $e');
      } catch (_) {}
    }
    _audioStreamCache[path] = hasAudio;
    return hasAudio;
  }

  generateVideoThumbnail(
    String srcPath,
    String thumbnailPath,
    int pos,
    VideoResolution videoResolution,
  ) async {
    VideoResolutionSize size = _videoResolutionSize(videoResolution);
    List pathList = thumbnailPath.split('.');
    pathList[pathList.length - 2] += '_${size.width}x${size.height}';
    String path = pathList.join('.');
    String arguments =
        '-loglevel error -y -i "$srcPath" ' +
        '-ss ${pos / 1000} -vframes 1 -vf scale=-2:${size.height} "$path"';
    await FFmpegKit.execute(arguments);
    return path;
  }

  generateImageThumbnail(
    String srcPath,
    String thumbnailPath,
    VideoResolution videoResolution,
  ) async {
    VideoResolutionSize size = _videoResolutionSize(videoResolution);
    List pathList = thumbnailPath.split('.');
    pathList[pathList.length - 2] += '_${size.width}x${size.height}';
    String path = pathList.join('.');
    String arguments =
        '-loglevel error -y -r 1 -i "$srcPath" ' +
        '-ss 0 -vframes 1 -vf scale=-2:${size.height} "$path"';
    await FFmpegKit.execute(arguments);
    return path;
  }

  executeCommand(
    String arguments, {
    String? outputPath,
    int? fileNum,
    int? totalFiles,
    bool finished = false,
  }) {
    final completer = new Completer<String?>();
    DateTime initTime = DateTime.now();

    FFmpegKit.executeAsync(
      ///arguments.split(' '), daha önce esyncargumentle kulanıldı hata verirdi
      arguments,
      (session) async {
        try {
          final returnCode = await session.getReturnCode();
          if (ReturnCode.isSuccess(returnCode)) {
            ffmepegStat.finished = finished;
            ffmepegStat.outputPath = outputPath;
            _ffmepegStat.add(ffmepegStat);
            Duration diffTime = DateTime.now().difference(initTime);
            logger.i('Generator.executeCommand() $diffTime)');
            if (!completer.isCompleted) {
              completer.complete(outputPath);
            }
          } else if (!ReturnCode.isCancel(returnCode)) {
            ffmepegStat.error = true;
            _ffmepegStat.add(ffmepegStat);
            final output = await session.getOutput();
            logger.e('Generator.executeCommand() $output');
            try {
              FirebaseCrashlytics.instance.recordError(
                'Last ffmpeg command output: $output - Arguments: $arguments',
                null,
              );
            } catch (_) {}
            if (!completer.isCompleted) {
              completer.complete(null);
            }
          } else {
            if (!completer.isCompleted) {
              completer.complete(null);
            }
          }
        } catch (e) {
          try {
            logger.e('Generator.executeCommand() callback exception: $e');
          } catch (_) {}
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        } finally {
          _ffmepegStat.add(FFmpegStat());
        }
      },
      (log) {
        // Log callback
      },
      (statistics) {
        _ffmepegStat.add(
          FFmpegStat(
            time: statistics.getTime(),
            size: statistics.getSize(),
            bitrate: statistics.getBitrate(),
            speed: statistics.getSpeed(),
            videoFrameNumber: statistics.getVideoFrameNumber(),
            videoQuality: statistics.getVideoQuality(),
            videoFps: statistics.getVideoFps(),
            timeElapsed: DateTime.now().difference(initTime).inMilliseconds,
            fileNum: fileNum,
            totalFiles: totalFiles,
          ),
        );
      },
    );

    return completer.future;
  }

  finishVideoGeneration() async {
    _ffmepegStat.add(FFmpegStat());
    await FFmpegKit.cancel();
  }

  VideoResolutionSize videoResolutionSize(VideoResolution videoResolution) {
    return _videoResolutionSize(videoResolution);
  }

  VideoResolutionSize _videoResolutionSize(VideoResolution videoResolution) {
    switch (videoResolution) {
      case VideoResolution.uhd8k:
        return VideoResolutionSize(width: 7680, height: 4320);
      case VideoResolution.uhd6k:
        return VideoResolutionSize(width: 6144, height: 3456);
      case VideoResolution.uhd4k:
        return VideoResolutionSize(width: 3840, height: 2160);
      case VideoResolution.qhd:
        return VideoResolutionSize(width: 2560, height: 1440);
      case VideoResolution.fullHd:
        return VideoResolutionSize(width: 1920, height: 1080);
      case VideoResolution.hd:
        return VideoResolutionSize(width: 1280, height: 720);
      case VideoResolution.mini:
        return VideoResolutionSize(width: 64, height: 36);
      case VideoResolution.sd:
        return VideoResolutionSize(width: 640, height: 360);
    }
  }

  String videoResolutionString(VideoResolution videoResolution) {
    switch (videoResolution) {
      case VideoResolution.uhd8k:
        return '8K UHD 4320p';
      case VideoResolution.uhd6k:
        return '6K UHD 3456p';
      case VideoResolution.uhd4k:
        return '4K UHD 2160p';
      case VideoResolution.qhd:
        return '2K QHD 1440p';
      case VideoResolution.fullHd:
        return 'Full HD 1080p';
      case VideoResolution.hd:
        return 'HD 720p';
      case VideoResolution.mini:
        return 'Thumbnail 36p';
      case VideoResolution.sd:
        return 'SD 360p';
    }
  }

  String dateTimeString(DateTime dateTime) {
    return '${dateTime.year.toString().padLeft(4, "0")}' +
        '${dateTime.month.toString().padLeft(2, "0")}' +
        '${dateTime.day.toString().padLeft(2, "0")}' +
        '_${dateTime.hour.toString().padLeft(2, "0")}' +
        '${dateTime.minute.toString().padLeft(2, "0")}' +
        '${dateTime.second.toString().padLeft(2, "0")}';
  }
}

enum VideoResolution {
  sd, // 640x360
  hd, // 1280x720
  fullHd, // 1920x1080
  qhd, // 2560x1440 (2K)
  uhd4k, // 3840x2160 (4K)
  uhd6k, // 6144x3456 (6K)
  uhd8k, // 7680x4320 (8K)
  mini, // 64x36 (thumbnail)
}

class VideoResolutionSize {
  int width;
  int height;
  VideoResolutionSize({required this.width, required this.height});
}

class FFmpegStat {
  int? time;
  int? size;
  double? bitrate;
  double? speed;
  int? videoFrameNumber;
  double? videoQuality;
  double? videoFps;
  bool? finished = false;
  String? outputPath;
  String? message;
  bool? error = false;
  int? timeElapsed;
  int? fileNum;
  int? totalFiles;

  FFmpegStat({
    this.time = 0,
    this.size = 0,
    this.bitrate = 0,
    this.speed = 0,
    this.videoFrameNumber = 0,
    this.videoQuality = 0,
    this.videoFps = 0,
    this.outputPath,
    this.message,
    this.timeElapsed = 0,
    this.fileNum,
    this.totalFiles,
  });
}
