import 'package:get_it/get_it.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/service/export/native_generator.dart';
import 'package:vidviz/service/export/native_pipeline.dart';
import 'package:vidviz/service/media_probe.dart';
import 'package:vidviz/service/project_service.dart';
import 'package:vidviz/dao/project_dao.dart';
import 'package:vidviz/service/generated_service.dart';
import 'package:vidviz/service/visualizer_service.dart';
import 'package:vidviz/service/shader_effect_service.dart';
import 'package:vidviz/service/media_overlay_service.dart';
import 'package:vidviz/service/audio_reactive_service.dart';
import 'package:vidviz/service/archive/project_archive_service.dart';
import 'package:vidviz/service/audio_analysis_service.dart';
import 'package:vidviz/service/settings_service.dart';
import 'package:vidviz/service/ad_service.dart';
import 'package:vidviz/service/pro_service.dart';

GetIt locator = GetIt.instance;

void setupLocator(SharedPreferences prefs) {
  locator.registerSingleton<Logger>(createLog());
  locator.registerSingleton<FirebaseAnalytics>(FirebaseAnalytics.instance);
  locator.registerSingleton<AudioAnalysisService>(AudioAnalysisService());
  locator.registerSingleton<ProjectDao>(ProjectDao());
  locator.registerSingleton<ProjectService>(ProjectService());
  locator.registerSingleton<Generator>(Generator());
  locator.registerSingleton<MediaProbe>(MediaProbe());
  locator.registerSingleton<ExportPipeline>(ExportPipeline());
  locator.registerSingleton<DirectorService>(DirectorService());
  locator.registerSingleton<GeneratedService>(GeneratedService());
  locator.registerSingleton<AudioReactiveService>(AudioReactiveService());
  locator.registerSingleton<VisualizerService>(VisualizerService());
  locator.registerSingleton<ShaderEffectService>(ShaderEffectService());
  locator.registerSingleton<MediaOverlayService>(MediaOverlayService());
  locator.registerSingleton<ProjectArchiveService>(ProjectArchiveService());
  locator.registerSingleton<AdService>(AdService());
  locator.registerSingleton<ProService>(ProService(prefs));
  locator.registerSingleton<AppSettingsService>(
    AppSettingsService(
      locator.get<VisualizerService>(),
      locator.get<AudioReactiveService>(),
      prefs,
    ),
  );
}

Logger createLog() {
  Logger.level = Level.debug;
  return Logger(
    filter: ProductionFilter(),
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 8,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      printTime: false,
    ),
    output: null,
  );
}
