import 'package:flutter/material.dart';
import 'package:vidviz/l10n/generated/app_localizations.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/model/layer.dart';
import 'package:vidviz/core/theme.dart' as app_theme;

import 'custom_slider.dart';

class AudioMixerSheet extends StatelessWidget {
  AudioMixerSheet({super.key});

  final DirectorService directorService = locator.get<DirectorService>();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? app_theme.projectListBg : app_theme.background,
        body: SafeArea(
          child: Column(
            children: [
              // --- 1. HEADER (Görseldeki Gibi) ---
              _buildHeader(context),

              Divider(color: isDark ? app_theme.projectListCardBorder : app_theme.border, height: 1),

              // --- 2. İÇERİK (StreamBuilder Korundu) ---
              Expanded(
                child: StreamBuilder<bool>(
                  stream: directorService.layersChanged$,
                  initialData: true,
                  builder: (context, snapshot) {
                    final loc = AppLocalizations.of(context);
                    final layers = directorService.layers ?? [];
                    final items = <int>[];
                    final rasterIndexes = <int>[];
                    for (int i = 0; i < layers.length; i++) {
                      if (layers[i].type == 'audio' || layers[i].type == 'raster') {
                        items.add(i);
                      }
                      if (layers[i].type == 'raster') {
                        rasterIndexes.add(i);
                      }
                    }

                    final hasRaster = rasterIndexes.isNotEmpty;
                    final allRasterUseVideo = hasRaster &&
                        rasterIndexes.every((i) => layers[i].useVideoAudio == true);

                    return SingleChildScrollView(
                      padding: const EdgeInsets.only(top: 12, bottom: 24, right: 16, left: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // AUDIO ONLY PLAY SWITCH (Senin mantığın)
                          StreamBuilder<bool>(
                            stream: directorService.audioOnlyPlay$,
                            initialData: directorService.audioOnlyPlay,
                            builder: (context, snap) {
                              final loc = AppLocalizations.of(context);
                              final enabled = snap.data ?? false;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 20),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? app_theme.projectListCardBg : app_theme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark ? app_theme.projectListCardBorder : app_theme.border,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.headphones,
                                          color: app_theme.accent,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          loc.audioMixerAudioOnlyPlay,
                                          style: TextStyle(
                                            color: isDark
                                                ? app_theme.darkTextPrimary
                                                : app_theme.textPrimary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const Spacer(),
                                        Transform.scale(
                                          scale: 0.8,
                                          child: Switch(
                                            value: enabled,
                                            onChanged: (v) => directorService.setAudioOnlyPlay(v),
                                            activeColor: app_theme.accent,
                                          ),
                                        ),
                                      ],
                                    ),

                                    if (hasRaster)
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.movie_rounded,
                                            color: isDark
                                                ? app_theme.darkTextPrimary
                                                : app_theme.accent,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              loc.audioMixerUseOriginalVideoAudio,
                                              style: TextStyle(
                                                color: isDark
                                                    ? app_theme.darkTextPrimary
                                                    : app_theme.textPrimary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          Transform.scale(
                                            scale: 0.8,
                                            child: Switch(
                                              value: allRasterUseVideo,
                                              onChanged: (v) {
                                                for (final idx in rasterIndexes) {
                                                  directorService.setRasterUseVideoAudio(idx, v);
                                                }
                                              },
                                              activeColor: app_theme.accent,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),

                          if (items.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Text(
                                  loc.audioMixerNoAudioLayers,
                                  style: TextStyle(color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary),
                                ),
                              ),
                            ),

                          // KATMAN LİSTESİ (Tasarım Giydirildi)
                          ...items.map((idx) => _LayerRow(
                            index: idx,
                            layer: layers[idx],
                            onMuteChanged: (v) => directorService.setLayerMute(idx, v),
                            onVolumeChanged: (v) => directorService.setLayerVolume(idx, v),
                            onUseVideoAudioChanged: (v) => directorService.setRasterUseVideoAudio(idx, v),
                          )),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
  }

  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.close,
              color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
              size: 26,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Container(
            width: 1,
            height: 20,
            color: isDark ? app_theme.projectListCardBorder : app_theme.border,
            margin: const EdgeInsets.symmetric(horizontal: 5),
          ),
          //IconButton(
          //  icon: Icon(
          //    Icons.undo,
          //    color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
          //    size: 24,
          //  ),
          //  onPressed: () {},
          //),
          Expanded(
            child: Center(
              child: Text(
                AppLocalizations.of(context).audioMixerTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 20,
            color: isDark ? app_theme.projectListCardBorder : app_theme.border,
            margin: const EdgeInsets.symmetric(horizontal: 5),
          ),
          IconButton(
            icon: const Icon(Icons.check, color: app_theme.accent, size: 28),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _LayerRow extends StatelessWidget {
  final int index;
  final Layer layer;
  final ValueChanged<bool> onMuteChanged;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<bool> onUseVideoAudioChanged;

  const _LayerRow({
    required this.index,
    required this.layer,
    required this.onMuteChanged,
    required this.onVolumeChanged,
    required this.onUseVideoAudioChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMuted = layer.mute == true;
    final effectiveVol = (isMuted ? 0.0 : layer.volume);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. ÜST KISIM: İsim ve Mute Butonu
          Row(
            children: [
              // Mute Butonu
              GestureDetector(
                onTap: () => onMuteChanged(!isMuted),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isMuted
                        ? (isDark ? app_theme.projectListCardBg : app_theme.surface)
                        : app_theme.accent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),

                  ),
                  child: Icon(
                    isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    color: isMuted
                        ? (isDark ? app_theme.darkTextSecondary : app_theme.textSecondary)
                        : app_theme.accent,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Katman İsmi
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      layer.name,
                      style: TextStyle(
                        color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      isMuted
                          ? AppLocalizations.of(context).audioMixerMuted
                          : '${(effectiveVol * 100).round()}% ' +
                              AppLocalizations.of(context).audioMixerVolumeSuffix,
                      style: TextStyle(
                        color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 2. SLIDER KISMI (ÖZEL TASARIM)
          Row(
            children: [
              Expanded(
                child: DashedSlider(
                  barHeight: 20,
                  touchHeight: 20,
                  dashCount: 50,
                  thumbColor: isDark ? app_theme.darkTextPrimary: app_theme.textPrimary,
                  inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
                  activeColor: app_theme.accent, // İsteğe bağlı renk değişimi
                  enableHaptic: true,
                  barRadius: 6,
                  thumbHeight: 16,
                  thumbWidth: 8,
                  inactiveHeight:16,
                  inactiveLine: false,
                  inactiveRadius: 3,
                  inactiveWidth: 5,
                  value: layer.volume, // Mevcut ses seviyesi (0.0 - 1.0)

                  onChanged: (newValue) {
                    if (isMuted) onMuteChanged(false); // Slider oynarsa mute'u aç
                    onVolumeChanged(newValue);
                    // Servise veya state'e değeri gönder
                    //  directorService.setLayerVolume(index, newValue);
                  },
                ),
              ),
         /*     Expanded(
                child: _CustomDashedSlider(
                  value: layer.volume.clamp(0.0, 1.0).toDouble(),
                  onChanged: (val) {
                    if (isMuted) onMuteChanged(false); // Slider oynarsa mute'u aç
                    onVolumeChanged(val);
                  },
                ),
              ),*/
              const SizedBox(width: 15),
              SizedBox(
                width: 40,
                child: Text(
                  '${(effectiveVol * 100).round()}%',
                  style: TextStyle(
                    color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),

          // 3. RASTER KATMANI İÇİN EKSTRA AYAR (Video Audio Kullanımı)
          // Artık global kartın içinde yönetiliyor (Audio-only play kutusunun alt satırı)
        ],
      ),
    );
  }
}

class CustomDashedSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const CustomDashedSlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,

      // Parmağın X pozisyonunu doğrudan value yapıyoruz → %100 düzgün
      onPanUpdate: (details) {
        RenderBox box = context.findRenderObject() as RenderBox;
        double width = box.size.width;

        double newValue =
        (details.localPosition.dx / width).clamp(0.0, 1.0);

        onChanged(newValue);
      },

      onTapDown: (details) {
        RenderBox box = context.findRenderObject() as RenderBox;
        double width = box.size.width;

        double newValue =
        (details.localPosition.dx / width).clamp(0.0, 1.0);

        onChanged(newValue);
      },

      child: Container(
        height: 25,
        color: app_theme.transparent,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            // --- Kesik Çizgiler ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(40, (index) {
                return Container(
                  width: 2,
                  height: 20,
                  color: isDark
                      ? app_theme.projectListCardBorder
                      : app_theme.border,
                );
              }),
            ),

            // --- Dolu Kısım ---
            LayoutBuilder(
              builder: (context, constraints) {
                return Container(
                  width: constraints.maxWidth * value,
                  height: 20,
                  decoration: BoxDecoration(
                    gradient: app_theme.neonButtonGradient,
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: [
                      BoxShadow(
                        color: app_theme.neonCyan.withOpacity(0.4),
                        blurRadius: 6,
                      )
                    ],
                  ),
                );
              },
            ),

            // --- Thumb ---
            Align(
              alignment: Alignment(value * 2 - 1, 0),
              child: Container(
                height: 16,
                width: 8,
                decoration: BoxDecoration(
                  color: isDark
                      ? app_theme.darkTextPrimary
                      : app_theme.textPrimary,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: app_theme.neonCyan.withOpacity(0.6),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
