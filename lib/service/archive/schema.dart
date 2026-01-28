/// Archive package schema for VidViz project export (.vvz)
/// Language: English in code, Turkish in comments where helpful.

class ArchiveConstants {
  static const String packageExtension = '.vvz';
  static const int schemaVersion = 1;

  static const String manifestFile = 'manifest.json';
  static const String projectFile = 'project.json';
  static const String assetsIndexFile = 'assets-hashes.json';
  static const String assetsDir = 'assets';
  static const String thumbnailsDir = 'thumbnails';
}

class ArchivePhase {
  final String name;
  const ArchivePhase._(this.name);

  static const hashing = ArchivePhase._('hashing');
  static const copying = ArchivePhase._('copying');
  static const zipping = ArchivePhase._('zipping');
  static const extracting = ArchivePhase._('extracting');
  static const finalizing = ArchivePhase._('finalizing');
}

class ArchiveProgress {
  final ArchivePhase phase;
  final int current; // item index
  final int total;   // item count
  final int bytesProcessed;
  final int bytesTotal;
  final bool finished;
  final bool error;
  final String? message;
  final String? outputPath;

  const ArchiveProgress({
    required this.phase,
    this.current = 0,
    this.total = 0,
    this.bytesProcessed = 0,
    this.bytesTotal = 0,
    this.finished = false,
    this.error = false,
    this.message,
    this.outputPath,
  });

  ArchiveProgress copyWith({
    ArchivePhase? phase,
    int? current,
    int? total,
    int? bytesProcessed,
    int? bytesTotal,
    bool? finished,
    bool? error,
    String? message,
    String? outputPath,
  }) => ArchiveProgress(
        phase: phase ?? this.phase,
        current: current ?? this.current,
        total: total ?? this.total,
        bytesProcessed: bytesProcessed ?? this.bytesProcessed,
        bytesTotal: bytesTotal ?? this.bytesTotal,
        finished: finished ?? this.finished,
        error: error ?? this.error,
        message: message ?? this.message,
        outputPath: outputPath ?? this.outputPath,
      );
}

class ExportOptions {
  final bool includeVideos;
  final bool includeAudios;
  final int maxVideoMb; // 0 = no limit
  final int maxTotalMb; // 0 = no limit

  const ExportOptions({
    this.includeVideos = true,
    this.includeAudios = true,
    this.maxVideoMb = 500,
    this.maxTotalMb = 0,
  });
}

class ArchiveEstimate {
  final int files;
  final int bytes;
  final int skippedFiles;
  final int skippedBytes;
  const ArchiveEstimate(this.files, this.bytes, this.skippedFiles, this.skippedBytes);
}
