import 'dart:io';
import 'package:flutter/material.dart';
import 'package:vidviz/model/layer.dart';
import 'package:vidviz/service_locator.dart';
import 'media_library/media_library_sheet.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/l10n/generated/app_localizations.dart';
import 'package:vidviz/ui/widgets/video/video_speed_editor.dart';
import 'package:photo_manager/photo_manager.dart' as photo_manager;
import 'package:vidviz/core/theme.dart' as app_theme;
import 'action_button.dart';


class EditorAction extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  EditorAction({super.key});

  @override
  Widget build(BuildContext context) {
    // Audio Reactive stream'ini de dinle
    return StreamBuilder<bool>(
      stream: directorService.isAnyEditorOpen$,
      initialData: directorService.isAnyEditorOpen,
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        final bool isLandscape =  (MediaQuery.of(context).orientation == Orientation.landscape);
        final bool isEditing = snapshot.data ?? directorService.isAnyEditorOpen;

        if (isEditing) {
            return SizedBox();
        } else {
          if (isLandscape) {
            return _ActionLandscape();
          } else {
            return _ActionPortrait();
          }
        }
      },
    );
  }
}

class _AssetFadeEditor extends StatefulWidget {
  const _AssetFadeEditor();

  @override
  State<_AssetFadeEditor> createState() => _AssetFadeEditorState();
}

class _AssetFadeEditorState extends State<_AssetFadeEditor> {
  final directorService = locator.get<DirectorService>();
  int _fadeInMs = 0;
  int _fadeOutMs = 0;

  @override
  void initState() {
    super.initState();
    final asset = directorService.assetSelected;
    if (asset != null) {
      final fi = asset.data?['fadeInMs'];
      final fo = asset.data?['fadeOutMs'];
      if (fi is num) _fadeInMs = fi.toInt().clamp(0, asset.duration);
      if (fo is num) _fadeOutMs = fo.toInt().clamp(0, asset.duration);
    }
  }

  void _apply() {
    final asset = directorService.assetSelected;
    if (asset == null) return;
    final int maxDur = asset.duration;
    final int fi = _fadeInMs.clamp(0, maxDur);
    final int fo = _fadeOutMs.clamp(0, maxDur);
    directorService.setSelectedAssetFade(fadeInMs: fi, fadeOutMs: fo);
    setState(() {
      _fadeInMs = fi;
      _fadeOutMs = fo;
    });
  }

  @override
  Widget build(BuildContext context) {
    final asset = directorService.assetSelected;
    final int maxDur = asset?.duration ?? 0;
    final int maxMs = maxDur > 0 ? maxDur : 5000;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.graphic_eq,
                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  loc.editorFadeTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Fade In: ${_fadeInMs} ms',
              style: TextStyle(
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
              ),
            ),
            Row(
              children: [
                Text('0 ms', style: TextStyle(color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary)),
                Expanded(
                  child: Slider(
                    value: _fadeInMs.clamp(0, maxMs).toDouble(),
                    min: 0,
                    max: maxMs.toDouble(),
                    divisions: maxMs > 0 ? (maxMs ~/ 100).clamp(1, 100) : 1,
                    label: '${_fadeInMs} ms',
                    activeColor: app_theme.accent,
                    inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
                    onChanged: (v) {
                      setState(() => _fadeInMs = v.round());
                    },
                    onChangeEnd: (_) => _apply(),
                  ),
                ),
                Text('$maxMs ms', style: TextStyle(color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Fade Out: ${_fadeOutMs} ms',
              style: TextStyle(
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
              ),
            ),
            Row(
              children: [
                Text('0 ms', style: TextStyle(color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary)),
                Expanded(
                  child: Slider(
                    value: _fadeOutMs.clamp(0, maxMs).toDouble(),
                    min: 0,
                    max: maxMs.toDouble(),
                    divisions: maxMs > 0 ? (maxMs ~/ 100).clamp(1, 100) : 1,
                    label: '${_fadeOutMs} ms',
                    activeColor: app_theme.accent,
                    inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
                    onChanged: (v) {
                      setState(() => _fadeOutMs = v.round());
                    },
                    onChangeEnd: (_) => _apply(),
                  ),
                ),
                Text('$maxMs ms', style: TextStyle(color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AssetVolumeEditor extends StatefulWidget {
  const _AssetVolumeEditor();

  @override
  State<_AssetVolumeEditor> createState() => _AssetVolumeEditorState();
}

class _AssetVolumeEditorState extends State<_AssetVolumeEditor> {
  final directorService = locator.get<DirectorService>();
  double _volume = 1.0;

  @override
  void initState() {
    super.initState();
    final asset = directorService.assetSelected;
    if (asset != null) {
      final v = asset.data?['volume'];
      if (v is num) {
        _volume = v.toDouble().clamp(0.0, 1.0);
      }
    }
  }

  void _apply(double v) {
    directorService.setSelectedAssetVolume(v);
    setState(() => _volume = v);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.volume_up,
                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  loc.editorVolumeTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${(_volume * 100).round()}%',
                  style: TextStyle(
                    color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('0%', style: TextStyle(color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary)),
                Expanded(
                  child: Slider(
                    value: _volume.clamp(0.0, 1.0),
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    label: '${(_volume * 100).round()}%',
                    activeColor: app_theme.accent,
                    inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
                    onChanged: (v) => setState(() => _volume = v),
                    onChangeEnd: (v) => _apply(v),
                  ),
                ),
                Text('100%', style: TextStyle(color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _apply(0.0),
                    icon: Icon(
                      Icons.volume_off,
                      color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                      size: 18,
                    ),
                    label: Text(
                      loc.editorVolumeMute,
                      style: TextStyle(
                        color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _apply(1.0),
                    icon: Icon(
                      Icons.refresh,
                      color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                      size: 18,
                    ),
                    label: Text(
                      loc.editorVolumeReset,
                      style: TextStyle(
                        color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionLandscape extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? app_theme.projectListBg : app_theme.background,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        padding: EdgeInsets.only(right: 8),
        child: directorService.selected.layerIndex == -1
               ? _ButtonAdd() // No selection: Show add buttons (full width with scroll)
               : _ButtonEdit(), // Asset selected: Show edit buttons with scroll
      ),
    );
  }
}

class _ActionPortrait extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? app_theme.projectListBg : app_theme.background,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.only(bottom: 8),
        child: directorService.selected.layerIndex == -1
               ? _ButtonAdd() // No selection: Show add buttons (full width with scroll)
               : _ButtonEdit(), // Asset selected: Show edit buttons with scroll
      ),
    );
  }

}

class _ButtonEdit extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  @override
  Widget build(BuildContext context) {
    final bool isLandscape =  (MediaQuery.of(context).orientation == Orientation.landscape);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    List<Widget> buttons = [];

    // Edit/Delete/Cut buttons (when asset selected)
    if (directorService.selected.layerIndex != -1) {
      buttons.add(
        ActionButton(
          tooltip: AppLocalizations.of(context).editorActionDelete,
          asset: 'delete',
          color: Colors.red, // Keep critical actions distinct if desired, or use theme error color
          onPressed: directorService.delete,
        ),
      );

      // Cut button for all asset types
      if (directorService.assetSelected != null) {
        buttons.add(
          ActionButton(
            tooltip: AppLocalizations.of(context).editorActionSplit,
            asset: 'split',
            color: Colors.orange,
            onPressed: directorService.cutAsset,
          ),
        );

        // Edit button based on asset type
        final assetType = directorService.assetSelected?.type;
        final overlayType = directorService.assetSelected?.data?['overlayType'];
        final layerType = directorService.layers![directorService.selected.layerIndex].type;

        // Clone button for basic media assets (video/image/audio)
        final bool canClone = assetType == AssetType.video || assetType == AssetType.image || assetType == AssetType.audio;

        if (canClone) {
          buttons.add(
            ActionButton(

              tooltip: loc.editorActionClone,
              asset: 'copy',
              color: app_theme.accent,
              onPressed: () {
                directorService.cloneSelectedAsset();
              },
            ),
          );
        }

        // Video Settings button (only for video/image in raster layer)
        if ((assetType == AssetType.video || assetType == AssetType.image) && layerType == 'raster') {
          buttons.add(
            ActionButton(
              tooltip: loc.editorActionSettings,
              asset: 'settings',
              color: Colors.amber,
              onPressed: directorService.editVideoSettings,
            ),
          );
        }

        // Per-asset volume control for video/audio
        final bool canAssetVolume =
             (assetType == AssetType.video && layerType == 'raster') ||
             (assetType == AssetType.audio && layerType == 'audio');
        if (canAssetVolume) {
          buttons.add(
            ActionButton(

              tooltip: loc.editorActionVolume,
              asset: 'volume_up',
              color: Colors.lightGreenAccent,
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  useSafeArea: true,
                  isScrollControlled: true,
                  backgroundColor: isDark ? app_theme.projectListCardBg : app_theme.surface,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  builder: (ctx) => const FractionallySizedBox(
                    heightFactor: 0.26,
                    child: _AssetVolumeEditor(),
                  ),
                );
              },
            ),
          );
        }

        // Per-asset fade control for video/audio
        final bool canAssetFade = canAssetVolume;
        if (canAssetFade) {
          buttons.add(
            ActionButton(
              tooltip: loc.editorActionFade,
              asset: 'fade',
              color: Colors.purpleAccent,
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  useSafeArea: true,
                  isScrollControlled: true,
                  backgroundColor: isDark ? app_theme.projectListCardBg : app_theme.surface,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  builder: (ctx) => const FractionallySizedBox(
                    heightFactor: 0.30,
                    child: _AssetFadeEditor(),
                  ),
                );
              },
            ),
          );
        }

        // Speed button for video assets in raster layer
        if (assetType == AssetType.video && layerType == 'raster') {
          buttons.add(
            ActionButton(

              tooltip: loc.editorActionSpeed,
              asset: 'speed',
              color: Colors.lightBlueAccent,
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  useSafeArea: true,
                  isScrollControlled: true,
                  backgroundColor: isDark ? app_theme.projectListCardBg : app_theme.surface,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  builder: (ctx) => const FractionallySizedBox(
                    heightFactor: 0.40,
                    child: VideoSpeedEditor(),
                  ),
                );
              },
            ),
          );
        }

        final bool canReplace = (assetType == AssetType.video && layerType == 'raster') ||
             (assetType == AssetType.image && layerType == 'raster' && overlayType == null) ||
             (assetType == AssetType.audio && layerType == 'audio');
        if (canReplace) {
          buttons.add(
            ActionButton(

              tooltip: loc.editorActionReplace,
              asset: 'replace',
              color: Colors.greenAccent,
              onPressed: () {
                directorService.replaceSelectedAssetMedia();
              },
            ),
          );
        }

        if (assetType == AssetType.text) {
          buttons.add(
            ActionButton(

              tooltip: loc.editorActionEdit,
              asset: 'edit',
              color: Colors.blue,
              onPressed: directorService.editTextAsset,
            ),
          );
        } else if (assetType == AssetType.visualizer) {
          buttons.add(
            ActionButton(

              tooltip: loc.editorActionEdit,
              asset: 'edit',
              color: Colors.purple,
              onPressed: directorService.editVisualizerAsset,
            ),
          );
        } else if (assetType == AssetType.shader) {
          buttons.add(
            ActionButton(

              tooltip: loc.editorActionEdit,
              asset: 'edit',
              color: Colors.cyan,
              onPressed: directorService.editShaderEffectAsset,
            ),
          );
        } else if (assetType == AssetType.image && overlayType == 'media') {
          buttons.add(
            ActionButton(

              tooltip: loc.editorActionEdit,
              asset: 'edit',
              color: Colors.teal,
              onPressed: directorService.editMediaOverlayAsset,
            ),
          );
        } else if (assetType == AssetType.image && overlayType == 'audio_reactive') {
          buttons.add(
            ActionButton(

              tooltip: loc.editorActionEdit,
              asset: 'edit',
              color: Colors.deepPurple,
              onPressed: directorService.editAudioReactiveAsset,
            ),
          );
        }
      }
    }

    return isLandscape ? Column(children: buttons) : Row(children: buttons);
  }

}

class _ButtonAdd extends StatefulWidget {
  @override
  State<_ButtonAdd> createState() => _ButtonAddState();
}

class _ButtonAddState extends State<_ButtonAdd> {
  final directorService = locator.get<DirectorService>();

  final List<photo_manager.AssetEntity> _selectedAssets = [];

  void _showMediaPicker(AssetType assetType) async {
    // İzin kontrolü
    final photo_manager.PermissionState ps = await photo_manager.PhotoManager.requestPermissionExtend();
    final loc = AppLocalizations.of(context);
    if (!ps.isAuth) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ ${loc.mediaPermissionRequired}')),
      );
      return;
    }

    int initialTab = 0;
    if (assetType == AssetType.image) {
      initialTab = 1;
    } else if (assetType == AssetType.video) {
      initialTab = 2;
    } else if (assetType == AssetType.audio) {
      initialTab = 3;
    }

    // BottomSheet aç
    final result = await showModalBottomSheet<List<photo_manager.AssetEntity>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MediaPickerSheet(
        selectedAssets: _selectedAssets,
        initialTabIndex: initialTab,
      ),
    );

    if (result == null || result.isEmpty) {
      return;
    }

    final files = await Future.wait<File?>(result.map((a) => a.originFile));

    final videoPaths = <String>[];
    final imagePaths = <String>[];
    final audioPaths = <String>[];

    for (int i = 0; i < result.length; i++) {
      final entity = result[i];
      final file = files[i];
      if (file == null) continue;

      switch (entity.type) {
        case photo_manager.AssetType.video:
          videoPaths.add(file.path);
          break;
        case photo_manager.AssetType.image:
          imagePaths.add(file.path);
          break;
        case photo_manager.AssetType.audio:
          audioPaths.add(file.path);
          break;
        default:
          break;
      }
    }

    if (videoPaths.isNotEmpty) {
      await directorService.mediaAdd(AssetType.video, videoPaths);
    }
    if (imagePaths.isNotEmpty) {
      await directorService.mediaAdd(AssetType.image, imagePaths);
    }
    if (audioPaths.isNotEmpty) {
      await directorService.mediaAdd(AssetType.audio, audioPaths);
    }

    setState(() {
      _selectedAssets
        ..clear()
        ..addAll(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isLandscape =  (MediaQuery.of(context).orientation == Orientation.landscape);
    final loc = AppLocalizations.of(context);
    final buttons = [
      ActionButton(

        tooltip: loc.editorActionVideo,
        asset: 'video',
        color: app_theme.layerRaster,
        onPressed: () => _showMediaPicker(AssetType.video),
        ///onPressed: () => directorService.add(AssetType.video),
      ),
      ActionButton(

        tooltip: loc.editorActionImage,
        asset: 'image',
        color: Color(0xFF00B894),
        onPressed: () => _showMediaPicker(AssetType.image),
      ),
      ActionButton(

        tooltip: loc.editorActionAudio,
        asset: 'audio',
        color: app_theme.layerAudio,
        onPressed: () => _showMediaPicker(AssetType.audio),
      ),
      ActionButton(

        tooltip: loc.editorActionText,
        asset: 'text',
        color: app_theme.layerVector,
        onPressed: () => directorService.add(AssetType.text),
      ),
      ActionButton(

        tooltip: loc.editorActionVisualizer,
        asset: 'visualizer',
        color: app_theme.layerVisualizer,
        onPressed: () => directorService.add(AssetType.visualizer),
      ),
      ActionButton(

        tooltip: loc.editorActionShader,
        asset: 'effects',
        color: app_theme.layerShader,
        onPressed: () => directorService.add(AssetType.shader),
      ),
      ActionButton(

        tooltip: loc.editorActionMedia,
        asset: 'overlay',
        color: app_theme.layerOverlay,
        onPressed: () => directorService.addMediaOverlay(),
      ),
      ActionButton(

        tooltip: loc.editorActionReactive,
        asset: 'reactive',
        color: app_theme.layerAudioReactive,
        onPressed: () => directorService.addAudioReactive(),
      ),
    ];
    return isLandscape ? Column(children: buttons) : Row(children: buttons);
  }
}
