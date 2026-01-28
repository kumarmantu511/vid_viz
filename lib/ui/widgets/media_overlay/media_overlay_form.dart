import 'dart:io';
import 'package:flutter/material.dart';
import 'package:vidviz/l10n/generated/app_localizations.dart';
import 'package:vidviz/core/theme.dart' as app_theme;
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/media_overlay_service.dart';
import 'package:vidviz/model/layer.dart';
import 'package:vidviz/model/media_overlay.dart';

/// MediaOverlayForm - TextForm ve VisualizerForm pattern'ini takip eder
/// Media overlay ayarları: kaynak, pozisyon, scale, opacity, rotation
class MediaOverlayForm extends StatelessWidget {
  final mediaOverlayService = locator.get<MediaOverlayService>();
  final MediaOverlayAsset _asset;

  MediaOverlayForm(this._asset) : super();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Stream ile dinle (Text/Visualizer gibi)
    return StreamBuilder<MediaOverlayAsset?>(
      stream: mediaOverlayService.editingMediaOverlay$,
      initialData: _asset,
      builder: (context, snapshot) {
        MediaOverlayAsset currentAsset = snapshot.data ?? _asset;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView( scrollDirection: Axis.vertical,child: _SubMenu()),
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  color: isDark ? app_theme.projectListBg : app_theme.background,
                  padding: const EdgeInsets.only(left: 16, top: 8, right: 16, bottom: 16),
                  child: Wrap(
                    spacing: 0.0,
                    runSpacing: 0.0,
                    children: [
                      _SourceSelection(currentAsset),
                      _PositionSlider(currentAsset, 'X', true),
                      _PositionSlider(currentAsset, 'Y', false),
                      _ScaleSlider(currentAsset),
                      _FrameFitControls(currentAsset),
                      _CropControls(currentAsset),
                      _OpacitySlider(currentAsset),
                      _RotationSlider(currentAsset),
                      _BorderRadiusSlider(currentAsset),
                      _AnimationSelector(currentAsset),
                      _AnimationDurationSlider(currentAsset),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FrameFitControls extends StatelessWidget {
  final mediaOverlayService = locator.get<MediaOverlayService>();
  final MediaOverlayAsset _asset;

  _FrameFitControls(this._asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String frameMode = _asset.frameMode;
    final String fitMode = _asset.fitMode;

    return Wrap(
      spacing: 0.0,
      runSpacing: 0.0,
      children: [
        Container(
          /// iki defa verilince kesiyo width: 240,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Text(
            'Frame',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
            ),
          ),
        ),
        Container(
          width: 420,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniChipButton(
                label: 'Square',
                selected: frameMode == 'square',
                onTap: () {
                  final updated = MediaOverlayAsset.clone(_asset)
                    ..frameMode = 'square'
                    ..scale = 2.0;
                  mediaOverlayService.editingMediaOverlay = updated;
                },
              ),
              _MiniChipButton(
                label: '9:16',
                selected: frameMode == 'portrait',
                onTap: () {
                  final updated = MediaOverlayAsset.clone(_asset)
                    ..frameMode = 'portrait'
                    ..scale = 2.0;
                  mediaOverlayService.editingMediaOverlay = updated;
                },
              ),
              _MiniChipButton(
                label: '16:9',
                selected: frameMode == 'landscape',
                onTap: () {
                  final updated = MediaOverlayAsset.clone(_asset)
                    ..frameMode = 'landscape'
                    ..scale = 2.0;
                  mediaOverlayService.editingMediaOverlay = updated;
                },
              ),
              _MiniChipButton(
                label: 'Full',
                selected: frameMode == 'fullscreen',
                onTap: () {
                  final updated = MediaOverlayAsset.clone(_asset)
                    ..frameMode = 'fullscreen'
                    ..x = 0.5
                    ..y = 0.5
                    ..scale = 1.0;
                  mediaOverlayService.editingMediaOverlay = updated;
                },
              ),
            ],
          ),
        ),
        Container(
          width: 240,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Text(
            'Fit',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
            ),
          ),
        ),
        Container(
          width: 420,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniChipButton(
                label: 'Cover',
                selected: fitMode == 'cover',
                onTap: () {
                  final updated = MediaOverlayAsset.clone(_asset)
                    ..fitMode = 'cover';
                  mediaOverlayService.editingMediaOverlay = updated;
                },
              ),
              _MiniChipButton(
                label: 'Contain',
                selected: fitMode == 'contain',
                onTap: () {
                  final updated = MediaOverlayAsset.clone(_asset)
                    ..fitMode = 'contain';
                  mediaOverlayService.editingMediaOverlay = updated;
                },
              ),
              _MiniChipButton(
                label: 'Stretch',
                selected: fitMode == 'stretch',
                onTap: () {
                  final updated = MediaOverlayAsset.clone(_asset)
                    ..fitMode = 'stretch';
                  mediaOverlayService.editingMediaOverlay = updated;
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MiniChipButton({
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = selected ? app_theme.accent.withOpacity(isDark ? 0.35 : 0.20) : (isDark ? app_theme.projectListCardBg : app_theme.surface);
    final Color border = selected ? app_theme.accent : (isDark ? app_theme.projectListCardBorder : app_theme.border);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _CropControls extends StatelessWidget {
  final mediaOverlayService = locator.get<MediaOverlayService>();
  final MediaOverlayAsset _asset;

  _CropControls(this._asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String mode = _asset.cropMode;
    final bool enabled = mode == 'custom';

    double zoom = _asset.cropZoom;
    if (zoom < 1.0) zoom = 1.0;
    if (zoom > 4.0) zoom = 4.0;

    double panX = _asset.cropPanX;
    if (panX < -1.0) panX = -1.0;
    if (panX > 1.0) panX = 1.0;

    double panY = _asset.cropPanY;
    if (panY < -1.0) panY = -1.0;
    if (panY > 1.0) panY = 1.0;

    Widget sliders = Wrap(
      spacing: 0.0,
      runSpacing: 0.0,
      children: [
        Container(
          /// iki defa verilince kesiyo width: 240,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Crop',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                ),
              ),
              DropdownButton<String>(
                value: (mode == 'custom') ? 'custom' : 'none',
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('None')),
                  DropdownMenuItem(value: 'custom', child: Text('Custom')),
                ],
                onChanged: (val) {
                  final next = val ?? 'none';
                  final updated = MediaOverlayAsset.clone(_asset)
                    ..cropMode = next;
                  mediaOverlayService.editingMediaOverlay = updated;
                },
              ),
            ],
          ),
        ),
        Opacity(
          opacity: enabled ? 1.0 : 0.45,
          child: IgnorePointer(
            ignoring: !enabled,
            child: Container(
              /// iki defa verilince kesiyo width: 220,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Zoom',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                        ),
                      ),
                      Text(
                        'x${zoom.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 36,
                    child: Slider(
                      value: zoom,
                      min: 1.0,
                      max: 4.0,
                      divisions: 30,
                      activeColor: app_theme.accent,
                      inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
                      onChanged: (val) {
                        final updated = MediaOverlayAsset.clone(_asset)
                          ..cropZoom = val;
                        mediaOverlayService.editingMediaOverlay = updated;
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Opacity(
          opacity: enabled ? 1.0 : 0.45,
          child: IgnorePointer(
            ignoring: !enabled,
            child: Container(
              /// iki defa verilince kesiyo  width: 220,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pan X',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                        ),
                      ),
                      Text(
                        panX.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 36,
                    child: Slider(
                      value: panX,
                      min: -1.0,
                      max: 1.0,
                      divisions: 40,
                      activeColor: app_theme.accent,
                      inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
                      onChanged: (val) {
                        final updated = MediaOverlayAsset.clone(_asset)
                          ..cropPanX = val;
                        mediaOverlayService.editingMediaOverlay = updated;
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Opacity(
          opacity: enabled ? 1.0 : 0.45,
          child: IgnorePointer(
            ignoring: !enabled,
            child: Container(
              /// iki defa verilince kesiyo width: 220,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pan Y',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                        ),
                      ),
                      Text(
                        panY.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 36,
                    child: Slider(
                      value: panY,
                      min: -1.0,
                      max: 1.0,
                      divisions: 40,
                      activeColor: app_theme.accent,
                      inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
                      onChanged: (val) {
                        final updated = MediaOverlayAsset.clone(_asset)
                          ..cropPanY = val;
                        mediaOverlayService.editingMediaOverlay = updated;
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Opacity(
          opacity: enabled ? 1.0 : 0.45,
          child: IgnorePointer(
            ignoring: !enabled,
            child: Container(
              /// iki defa verilince kesiyo width: 220,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _MiniChipButton(
                      label: 'Center',
                      onTap: () {
                        final updated = MediaOverlayAsset.clone(_asset)
                          ..cropPanX = 0.0
                          ..cropPanY = 0.0;
                        mediaOverlayService.editingMediaOverlay = updated;
                      },
                    ),
                    _MiniChipButton(
                      label: 'Left',
                      onTap: () {
                        final updated = MediaOverlayAsset.clone(_asset)
                          ..cropPanX = (-1.0)
                          ..cropPanY = _asset.cropPanY;
                        mediaOverlayService.editingMediaOverlay = updated;
                      },
                    ),
                    _MiniChipButton(
                      label: 'Right',
                      onTap: () {
                        final updated = MediaOverlayAsset.clone(_asset)
                          ..cropPanX = 1.0
                          ..cropPanY = _asset.cropPanY;
                        mediaOverlayService.editingMediaOverlay = updated;
                      },
                    ),
                    _MiniChipButton(
                      label: 'Up',
                      onTap: () {
                        final updated = MediaOverlayAsset.clone(_asset)
                          ..cropPanX = _asset.cropPanX
                          ..cropPanY = (-1.0);
                        mediaOverlayService.editingMediaOverlay = updated;
                      },
                    ),
                    _MiniChipButton(
                      label: 'Down',
                      onTap: () {
                        final updated = MediaOverlayAsset.clone(_asset)
                          ..cropPanX = _asset.cropPanX
                          ..cropPanY = 1.0;
                        mediaOverlayService.editingMediaOverlay = updated;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Container(
          /// iki defa verilince kesiyo width: 180,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                final updated = MediaOverlayAsset.clone(_asset)
                  ..cropMode = 'none'
                  ..cropZoom = 1.0
                  ..cropPanX = 0.0
                  ..cropPanY = 0.0;
                mediaOverlayService.editingMediaOverlay = updated;
              },
              child: const Text('Reset Crop'),
            ),
          ),
        ),
      ],
    );

    return sliders;
  }
}

class _SubMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? app_theme.projectListCardBg : app_theme.surface,
        border: Border(
          right: BorderSide(
            color: isDark ? app_theme.projectListCardBorder : app_theme.border,
            width: 1
          )
        )
      ),
      width: 50, // Sabit genişlik vererek hizalamayı koruyalım
      child: Column(
        children: [
          IconButton(
            icon: Icon(
              Icons.layers, 
              color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary
            ),
            tooltip: loc.mediaOverlaySubmenuTooltip,
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

class _AnimationDurationSlider extends StatelessWidget {
  final mediaOverlayService = locator.get<MediaOverlayService>();
  final MediaOverlayAsset _asset;

  _AnimationDurationSlider(this._asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    // Slider sadece animasyon aktifken anlamlı
    final bool enabled = _asset.animationType != 'none';
    double seconds = _asset.animationDuration / 1000.0;
    if (seconds < 0.1) seconds = 0.1;
    if (seconds > 3.0) seconds = 3.0;

    Widget slider = Container(
      /// iki defa verilince kesiyo width: 250,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loc.mediaOverlayAnimDurationLabel,
                style: TextStyle(
                  fontSize: 14, 
                  fontWeight: FontWeight.w500,
                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
                ),
              ),
              Text(
                '${seconds.toStringAsFixed(1)}s',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
                ),
              ),
            ],
          ),
          SizedBox(
            height: 36,
            child: Slider(
              value: seconds,
              min: 0.1,
              max: 3.0,
              divisions: 29, // 0.1s adım
              activeColor: app_theme.accent,
              inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
              onChanged: (val) {
                final updated = MediaOverlayAsset.clone(_asset)
                  ..animationDuration = (val * 1000).round();
                mediaOverlayService.editingMediaOverlay = updated;
              },
            ),
          ),
        ],
      ),
    );

    if (!enabled) {
      // Animasyon yokken slider pasif ve soluk görünsün
      slider = Opacity(
        opacity: 0.4,
        child: IgnorePointer(ignoring: true, child: slider),
      );
    }

    return slider;
  }
}

class _SourceSelection extends StatelessWidget {
  final mediaOverlayService = locator.get<MediaOverlayService>();
  final MediaOverlayAsset _asset;

  _SourceSelection(this._asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    return StreamBuilder(
      stream: mediaOverlayService.availableMediaSources$,
      initialData: <Asset>[],
      builder: (context, snapshot) {
        final sources = snapshot.data ?? [];
        
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.mediaOverlaySourceTitle(sources.length),
                style: TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.bold,
                  color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 70,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: sources.length + 2, // +2 for "Add Video" and "Add Image" buttons
                  itemBuilder: (context, index) {
                    // "Add Video" button
                    if (index == sources.length) {
                      return _buildAddMediaButton(
                        context,
                        loc.mediaOverlayAddVideo,
                        Icons.videocam,
                        Color(0xFF0060DD),
                        () async {
                          await mediaOverlayService.pickNewMediaSource(
                            true,
                          ); // true = video
                        },
                      );
                    }

                    // "Add Image" button
                    if (index == sources.length + 1) {
                      return _buildAddMediaButton(
                        context,
                        loc.mediaOverlayAddImage,
                        Icons.image,
                        Color(0xFF00DD34), // Yeşil kalabilir, distinct eylem
                        () async {
                          await mediaOverlayService.pickNewMediaSource(
                            false,
                          ); // false = image
                        },
                      );
                    }

                    // Existing sources
                    final source = sources[index];
                    final isSelected = _asset.srcPath == source.srcPath;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () {
                          print(
                            '🎬 Source selected: ${source.title} (${source.type})',
                          );
                          final updated = MediaOverlayAsset.clone(_asset)
                            ..srcPath = source.srcPath
                            ..thumbnailPath = source.thumbnailPath
                            ..mediaType = source.type
                            ..title = source.title;
                          mediaOverlayService.editingMediaOverlay = updated;
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          width: 70,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected ? app_theme.accent : (isDark ? app_theme.projectListCardBorder : app_theme.border),
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                                  child: source.thumbnailPath != null &&
                                          File(source.thumbnailPath!).existsSync()
                                      ? Image.file(
                                          File(source.thumbnailPath!),
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                        )
                                      : source.thumbnailMedPath != null &&
                                            File(
                                              source.thumbnailMedPath!,
                                            ).existsSync()
                                      ? Image.file(
                                          File(source.thumbnailMedPath!),
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                        )
                                      : Container(
                                          color: isDark ? app_theme.projectListCardBg : app_theme.surface,
                                          child: Icon(
                                            source.type == AssetType.video
                                                ? Icons.videocam
                                                : Icons.image,
                                            color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                                            size: 24,
                                          ),
                                        ),
                                ),
                              ),
                              Container(
                                width: double.infinity,
                                color: isSelected ? app_theme.accent.withOpacity(0.1) : Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Text(
                                  source.type == AssetType.video
                                      ? loc.mediaPickerTypeVideo
                                      : loc.mediaPickerTypeImage,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isSelected ? app_theme.accent : (isDark ? app_theme.darkTextSecondary : app_theme.textSecondary),
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Helper: Build "Add Video/Image" button
  Widget _buildAddMediaButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 70,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            border: Border.all(color: color.withOpacity(0.5), width: 1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PositionSlider extends StatelessWidget {
  final mediaOverlayService = locator.get<MediaOverlayService>();
  final MediaOverlayAsset _asset;
  final String label;
  final bool isX;

  _PositionSlider(this._asset, this.label, this.isX);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    double value = isX ? _asset.x : _asset.y;
    return Container(
      /// iki defa verilince kesiyo width: 180,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loc.mediaOverlayPositionLabel(label),
                style: TextStyle(
                  fontSize: 14, 
                  fontWeight: FontWeight.w500,
                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
                ),
              ),
              Text(
                '${(value * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
                ),
              ),
            ],
          ),
          SizedBox(
            height: 36,
            child: Slider(
              value: value,
              min: 0.0,
              max: 1.0,
              activeColor: app_theme.accent,
              inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
              onChanged: (val) {
                final updated = MediaOverlayAsset.clone(_asset);
                if (isX) {
                  updated.x = val;
                } else {
                  updated.y = val;
                }
                mediaOverlayService.editingMediaOverlay = updated;
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ScaleSlider extends StatelessWidget {
  final mediaOverlayService = locator.get<MediaOverlayService>();
  final MediaOverlayAsset _asset;

  _ScaleSlider(this._asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    return Container(
      /// iki defa verilince kesiyo width: 200,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loc.mediaOverlayScaleLabel,
                style: TextStyle(
                  fontSize: 14, 
                  fontWeight: FontWeight.w500,
                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
                ),
              ),
              Text(
                'x${_asset.scale.toStringAsFixed(1)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
                ),
              ),
            ],
          ),
          SizedBox(
            height: 36,
            child: Slider(
              value: _asset.scale,
              min: 0.1,
              max: 4.0,
              divisions: 19,
              activeColor: app_theme.accent,
              inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
              onChanged: (val) {
                final updated = MediaOverlayAsset.clone(_asset)..scale = val;
                mediaOverlayService.editingMediaOverlay = updated;
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OpacitySlider extends StatelessWidget {
  final mediaOverlayService = locator.get<MediaOverlayService>();
  final MediaOverlayAsset _asset;

  _OpacitySlider(this._asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    return Container(
      /// iki defa verilince kesiyo width: 180,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loc.mediaOverlayOpacityLabel,
                style: TextStyle(
                  fontSize: 14, 
                  fontWeight: FontWeight.w500,
                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
                ),
              ),
              Text(
                '${(_asset.opacity * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
                ),
              ),
            ],
          ),
          SizedBox(
            height: 36,
            child: Slider(
              value: _asset.opacity,
              min: 0.0,
              max: 1.0,
              activeColor: app_theme.accent,
              inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
              onChanged: (val) {
                final updated = MediaOverlayAsset.clone(_asset)..opacity = val;
                mediaOverlayService.editingMediaOverlay = updated;
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RotationSlider extends StatelessWidget {
  final mediaOverlayService = locator.get<MediaOverlayService>();
  final MediaOverlayAsset _asset;

  _RotationSlider(this._asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    return Container(
      /// iki defa verilince kesiyo width: 180,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loc.mediaOverlayRotationLabel,
                style: TextStyle(
                  fontSize: 14, 
                  fontWeight: FontWeight.w500,
                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
                ),
              ),
              Text(
                '${_asset.rotation.toInt()}°',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
                ),
              ),
            ],
          ),
          SizedBox(
            height: 36,
            child: Slider(
              value: _asset.rotation,
              min: 0.0,
              max: 360.0,
              activeColor: app_theme.accent,
              inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
              onChanged: (val) {
                final updated = MediaOverlayAsset.clone(_asset)..rotation = val;
                mediaOverlayService.editingMediaOverlay = updated;
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BorderRadiusSlider extends StatelessWidget {
  final mediaOverlayService = locator.get<MediaOverlayService>();
  final MediaOverlayAsset _asset;

  _BorderRadiusSlider(this._asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    return Container(
      /// iki defa verilince kesiyo width: 200,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loc.mediaOverlayCornerLabel,
                style: TextStyle(
                  fontSize: 14, 
                  fontWeight: FontWeight.w500,
                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
                ),
              ),
              Text(
                '${_asset.borderRadius.toInt()}px',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
                ),
              ),
            ],
          ),
          SizedBox(
            height: 36,
            child: Slider(
              value: _asset.borderRadius,
              min: 0.0,
              max: 100.0,
              divisions: 100,
              activeColor: app_theme.accent,
              inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
              onChanged: (val) {
                final updated = MediaOverlayAsset.clone(_asset)
                  ..borderRadius = val;
                mediaOverlayService.editingMediaOverlay = updated;
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimationSelector extends StatelessWidget {
  final mediaOverlayService = locator.get<MediaOverlayService>();
  final MediaOverlayAsset _asset;

  _AnimationSelector(this._asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final animations = <String, String>{
      'none': loc.mediaOverlayAnimNone,
      'fade_in': loc.mediaOverlayAnimFadeIn,
      'fade_out': loc.mediaOverlayAnimFadeOut,
      'slide_left': loc.mediaOverlayAnimSlideLeft,
      'slide_right': loc.mediaOverlayAnimSlideRight,
      'slide_up': loc.mediaOverlayAnimSlideUp,
      'slide_down': loc.mediaOverlayAnimSlideDown,
      'zoom_in': loc.mediaOverlayAnimZoomIn,
      'zoom_out': loc.mediaOverlayAnimZoomOut,
    };
    return Container(
      /// iki defa verilince kesiyo width: 450,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                loc.mediaOverlayAnimationLabel,
                style: TextStyle(
                  fontSize: 14, 
                  fontWeight: FontWeight.w500,
                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
                ),
              ),
              const SizedBox(width: 8),
              Text(
                animations[_asset.animationType] ?? loc.mediaOverlayAnimNone,
                style: TextStyle(
                  fontSize: 12,
                  color: app_theme.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: animations.entries.map((entry) {
              final isSelected = _asset.animationType == entry.key;
              return InkWell(
                onTap: () {
                  if (!isSelected) {
                    final updated = MediaOverlayAsset.clone(_asset)
                      ..animationType = entry.key;
                    mediaOverlayService.editingMediaOverlay = updated;
                  }
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? app_theme.accent.withOpacity(0.2) 
                        : (isDark ? app_theme.projectListCardBg : app_theme.surface),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? app_theme.accent : (isDark ? app_theme.projectListCardBorder : app_theme.border),
                    ),
                  ),
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? app_theme.accent : (isDark ? app_theme.darkTextSecondary : app_theme.textSecondary),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
