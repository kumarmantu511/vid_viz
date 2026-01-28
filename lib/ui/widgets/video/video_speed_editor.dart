import 'package:flutter/material.dart';
import 'package:vidviz/l10n/generated/app_localizations.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/core/theme.dart' as app_theme;

class VideoSpeedEditor extends StatefulWidget {
  const VideoSpeedEditor({super.key});

  @override
  State<VideoSpeedEditor> createState() => _VideoSpeedEditorState();
}

class _VideoSpeedEditorState extends State<VideoSpeedEditor> {
  final directorService = locator.get<DirectorService>();
  double _speed = 1.0;
  bool _ripple = true;

  @override
  void initState() {
    super.initState();
    final asset = directorService.assetSelected;
    if (asset != null) {
      _speed = asset.playbackSpeed;
      if (_speed <= 0) _speed = 1.0;
    }
  }

  void _apply(double s) {
    directorService.setPlaybackSpeedForSelected(s, ripple: _ripple);
    setState(() => _speed = s);
  }

  @override
  Widget build(BuildContext context) {
    final chips = <double>[0.25, 0.5, 1.0, 2.0, 4.0];
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
                  Icons.speed,
                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  loc.videoSpeedTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_speed.toStringAsFixed(2)}x',
                  style: TextStyle(
                    color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    loc.videoSpeedRippleLabel,
                    style: TextStyle(
                      color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                    ),
                  ),
                ),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: _ripple,
                    onChanged: (v) {
                      setState(() => _ripple = v);
                      _apply(_speed);
                    },
                    activeColor: app_theme.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: chips.map((v) {
                  final sel = (v - _speed).abs() < 1e-6;
                  return ChoiceChip(
                    label: Text('${v}x'),
                    selected: sel,
                    selectedColor: app_theme.accent.withOpacity(0.2),
                    backgroundColor: isDark ? app_theme.projectListCardBg : app_theme.surface,
                    labelStyle: TextStyle(
                      color: sel ? app_theme.accent : (isDark ? app_theme.darkTextPrimary : app_theme.textPrimary),
                      fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: sel ? app_theme.accent : (isDark ? app_theme.projectListCardBorder : app_theme.border),
                    ),
                    onSelected: (_) => _apply(v),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '0.25x',
                  style: TextStyle(
                    color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _speed.clamp(0.25, 4.0),
                    min: 0.25,
                    max: 4.0,
                    divisions: 15,
                    label: '${_speed.toStringAsFixed(2)}x',
                    activeColor: app_theme.accent,
                    inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
                    onChanged: (v) => setState(() => _speed = v),
                    onChangeEnd: (v) => _apply(v),
                  ),
                ),
                Text(
                  '4x',
                  style: TextStyle(
                    color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              loc.videoSpeedNote,
              style: TextStyle(
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
