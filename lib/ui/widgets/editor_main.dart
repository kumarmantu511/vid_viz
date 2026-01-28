import 'package:flutter/material.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/service/visualizer_service.dart';
import 'package:vidviz/service/shader_effect_service.dart';
import 'package:vidviz/service/media_overlay_service.dart';
import 'package:vidviz/service/audio_reactive_service.dart';
import 'package:vidviz/core/params.dart';
import 'package:vidviz/core/aspect_ratio.dart';
import 'package:vidviz/core/theme.dart' as app_theme;
import 'package:vidviz/ui/widgets/editor_action.dart';
import 'package:vidviz/ui/widgets/editor_header.dart';
import 'package:vidviz/ui/widgets/video_footer.dart';
import 'package:vidviz/ui/widgets/color_editor.dart';
import 'package:vidviz/ui/widgets/text/text_asset_editor.dart';
import 'package:vidviz/ui/widgets/visualizer/visualizer_asset_editor.dart';
import 'package:vidviz/ui/widgets/shader/shader_effect_editor.dart';
import 'package:vidviz/ui/widgets/media_overlay/media_overlay_editor.dart';
import 'package:vidviz/ui/widgets/audio_reactive/audio_reactive_editor.dart';
import 'package:vidviz/ui/widgets/video/video_settings_editor.dart';
import 'package:vidviz/ui/widgets/timeline/timeline_main.dart';
import 'package:vidviz/ui/widgets/timeline/timeline_player.dart';
import 'package:vidviz/ui/widgets/timeline/timeline_position.dart';

class EditorMain extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final audioReactiveService = locator.get<AudioReactiveService>();
  final mediaOverlayService = locator.get<MediaOverlayService>();
  final shaderEffectService = locator.get<ShaderEffectService>();
  final visualizerService = locator.get<VisualizerService>();

  EditorMain({super.key});

  /// Cancel editing and clear all editing states
  void _cancelEditing() {
    directorService.isAdding = false;
    directorService.editingTextAsset = null;
    mediaOverlayService.editingMediaOverlay = null;
    visualizerService.editingVisualizerAsset = null;
    audioReactiveService.editingAudioReactive = null;
    shaderEffectService.editingShaderEffectAsset = null;
    directorService.editingVideoSettings = null;
    directorService.editingColor = null;
    directorService.select(-1, -1);
  }

  /// Save current overlay based on editing state (not selection)
  void _saveCurrentOverlay() {
    // Check editing states instead of selection (for initial add)
    if (directorService.editingTextAsset != null) {
      directorService.saveTextAsset();
    } else if (visualizerService.editingVisualizerAsset != null) {
      directorService.saveVisualizerAsset();
    } else if (shaderEffectService.editingShaderEffectAsset != null) {
      directorService.saveShaderEffectAsset();
    } else if (mediaOverlayService.editingMediaOverlay != null) {
      directorService.saveMediaOverlayAsset();
    } else if (audioReactiveService.editingAudioReactive != null) {
      directorService.saveAudioReactiveAsset();
    } else if (directorService.editingVideoSettings != null) {
      directorService.saveVideoSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    if(isLandscape){
      return Stack(
        children: [
          Column(
            children: [
              // Üst kısım - Player ve kontroller
              Expanded(child: _buildLandscapeLayout(context)),
              // Alt kısım - Timeline
              Expanded(child: _buildTimelineSection(context)),
              // Action bar
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: EditorAction(),
          )
        ],
      );
    }else{
      return Column(
      children: [
        // Üst kısım - Player ve kontroller
        _buildPortraitLayout(context),
        // Alt kısım - Timeline
        Expanded(child: _buildTimelineSection(context)),
        // Action bar
        EditorAction(),
      ],
    );
    }
  }

  /// Landscape layout - Yatay mod
  Widget _buildLandscapeLayout(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 4,child: EditorHeader()),
        Expanded(flex: 6, child: TimelinePlayer()),
        Expanded(flex: 4,child: _buildFooterStream(context, isVertical: true),),
      ],
    );
  }

  /// Portrait layout - Dikey mod
  Widget _buildPortraitLayout(BuildContext context) {
    final vs = directorService.editingVideoSettings ?? directorService.getProjectVideoSettings();
    final double aspect = parseAspectRatioString(vs.aspectRatio);
    final double screenW = MediaQuery.of(context).size.width;
    final double screenH = MediaQuery.of(context).size.height;
    double stageH = (aspect > 0) ? (screenW / aspect) : (screenW * 9 / 16);
    final double maxStageH = screenH * 0.30;
    if (stageH > maxStageH) stageH = maxStageH;
    if (!stageH.isFinite || stageH <= 0) stageH = maxStageH;

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: Params.APP_BAR_HEIGHT, child: EditorHeader()),
        /// ornek olarak bıraktık çünkü eskiden yüksklik tuttışmam sorunu vardı sabit yüksklik verdik SizedBox(height: stageH, child: TimelinePlayer()),
        SizedBox(height: Params.getPlayerHeight(context), child: TimelinePlayer()),
        SizedBox(height: Params.FOOTER_HEIGHT, child: _buildFooterStream(context, isVertical: false),),
      ],
    );
  }

  /// Footer stream builder - Editing/Normal footer
  Widget _buildFooterStream(BuildContext context, {required bool isVertical}) {
    return StreamBuilder(
      stream: directorService.isAnyEditorOpen$,
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        final isEditing = snapshot.data ?? directorService.isAnyEditorOpen;
        return isEditing ? _buildEditingFooter(context, isVertical: isVertical) : VideoFooter();
      },
    );
  }

  /// Timeline section - Alt kısım
  Widget _buildTimelineSection(BuildContext context) {
    return Stack(
      alignment: const Alignment(0, -1),
      children: [
        // Timeline scroll area
        TimelineMain(),
        // Position indicators
        TimelinePosition(),
        /// devredışı TimelinePositionMarker(),
        // Editors
        TextAssetEditor(),
        VisualizerAssetEditor(),
        ShaderEffectEditor(),
        MediaOverlayEditor(),
        AudioReactiveEditor(),
        VideoSettingsEditor(),
        ColorEditor(),
      ],
    );
  }

  /// Editing footer - Cancel/Save butonları
  Widget _buildEditingFooter(BuildContext context, {bool isVertical = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final aspectRatio = MediaQuery.of(context).size.aspectRatio;

    // Renkler
    final cancelBg = isDark ? app_theme.darkSurface : app_theme.surface;
    final cancelIcon = isDark ? app_theme.darkTextSecondary : app_theme.textSecondary;
    final saveBg = app_theme.accent;
    final saveIcon = Colors.white;

    final cancelButton = Expanded(
      child: GestureDetector(
        onTap: _cancelEditing,
        child: Container(
          height: isVertical ? null : aspectRatio * 80,
          decoration: BoxDecoration(color: cancelBg),
          child: Icon(
            Icons.close_rounded,
            fill: 1,
            weight: 700,
            grade: 200,
            color: cancelIcon,
          ),
        ),
      ),
    );

    final saveButton = Expanded(
      child: GestureDetector(
        onTap: _saveCurrentOverlay,
        child: Container(
          height: isVertical ? null : aspectRatio * 80,
          decoration: BoxDecoration(color: saveBg),
          child: Icon(
            Icons.check_rounded,
            fill: 1,
            weight: 700,
            grade: 200,
            color: saveIcon,
          ),
        ),
      ),
    );

    return isVertical ? Row(crossAxisAlignment: CrossAxisAlignment.end, children: [cancelButton, saveButton]) : Row(children: [cancelButton, saveButton]);
  }

}

