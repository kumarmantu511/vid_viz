import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:vidviz/l10n/generated/app_localizations.dart';
import 'package:video_player/video_player.dart';
import 'package:vidviz/core/theme.dart' as app_theme;

class PlaybackScreen extends StatefulWidget {
  final String path;
  const PlaybackScreen({Key? key, required this.path}) : super(key: key);

  @override
  State<PlaybackScreen> createState() => _PlaybackScreenState();
}

class _PlaybackScreenState extends State<PlaybackScreen> {
  late VideoPlayerController _controller;
  StreamSubscription? _posTicker;
  double _sliderValue = 0.0;
  bool _isScrubbing = false;
  bool _isMuted = false;
  bool _isLooping = false;

  Future<void> _handleBack() async {
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.path));
    _init();
  }

  Future<void> _init() async {
    await _controller.initialize();
    await _controller.setLooping(false);
    await _controller.setVolume(1.0);
    _isLooping = false;
    _isMuted = false;
    await _controller.play();
    _posTicker = Stream.periodic(const Duration(milliseconds: 250)).listen((_) {
      if (!_isScrubbing && mounted && _controller.value.isInitialized) {
        final d = _controller.value.duration.inMilliseconds;
        final p = _controller.value.position.inMilliseconds;
        if (d > 0) {
          setState(() => _sliderValue = p / d);
        }
      }
    });
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _posTicker?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return WillPopScope(
      onWillPop: () async {
        await _handleBack();
        return false;
      },
      child: Scaffold(
        backgroundColor: app_theme.surface,
        appBar: AppBar(
          backgroundColor: app_theme.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: app_theme.textPrimary,
            ),
            onPressed: _handleBack,
          ),
          title: Text(
            AppLocalizations.of(context).playbackPreviewTitle,
            style: const TextStyle(
              color: app_theme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: _controller.value.isInitialized
            ? Column(
              children: [
                // Video Player
                Expanded(
                  child: Container(
                    color: app_theme.videoPlayerBg,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: VideoPlayer(_controller),
                      ),
                    ),
                  ),
                ),
                
                // Controls Container
                Container(
                  color: isDark ? app_theme.projectListCardBg : app_theme.surface,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSeekBar(),
                        const SizedBox(height: 10),
                        Container(
                            margin: const EdgeInsets.only(bottom: 32),
                            child: _buildControls()
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              )
            : const Center(
                child: CircularProgressIndicator(
                  color: app_theme.videoPlayerControls,
                ),
              ),
      ),
    );
  }

  Widget _buildControls() {
    final isPlaying = _controller.value.isPlaying;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? app_theme.darkTextPrimary : app_theme.textPrimary;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Mute/Unmute
          IconButton(
            iconSize: 24,
            icon: Icon(
              _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: iconColor,
            ),
            onPressed: () async {
              _isMuted = !_isMuted;
              await _controller.setVolume(_isMuted ? 0.0 : 1.0);
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(width: 4),
          // Rewind 10s
          IconButton(
            iconSize: 28,
            icon: Icon(
              Icons.replay_10_rounded,
              color: iconColor,
            ),
            onPressed: () async {
              final cur = _controller.value.position;
              final back = Duration(
                milliseconds: (cur.inMilliseconds - 10000).clamp(
                  0,
                  _controller.value.duration.inMilliseconds,
                ),
              );
              await _controller.seekTo(back);
            },
          ),
          const SizedBox(width: 8),
          // Play/Pause
          Container(
            decoration: BoxDecoration(
              gradient: app_theme.neonButtonGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: app_theme.neonCyan.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              iconSize: 32,
              icon: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: app_theme.videoPlayerControls,
              ),
              onPressed: () async {
                if (isPlaying) {
                  await _controller.pause();
                } else {
                  await _controller.play();
                }
                if (mounted) setState(() {});
              },
            ),
          ),
          const SizedBox(width: 8),
          // Forward 10s
          IconButton(
            iconSize: 28,
            icon: Icon(
              Icons.forward_10_rounded,
              color: iconColor,
            ),
            onPressed: () async {
              final cur = _controller.value.position;
              final dur = _controller.value.duration.inMilliseconds;
              final fwd = Duration(
                milliseconds: (cur.inMilliseconds + 10000).clamp(0, dur),
              );
              await _controller.seekTo(fwd);
            },
          ),
          const SizedBox(width: 4),
          
          // Loop toggle
          IconButton(
            iconSize: 24,
            icon: Icon(
              Icons.loop_rounded,
              color: _isLooping ? app_theme.neonCyan : iconColor,
            ),
            onPressed: () async {
              _isLooping = !_isLooping;
              await _controller.setLooping(_isLooping);
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSeekBar() {
    final duration = _controller.value.isInitialized
        ? _controller.value.duration
        : Duration.zero;
    final position = _controller.value.isInitialized
        ? _controller.value.position
        : Duration.zero;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: [
          // Time labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _fmt(position),
              _fmt(duration),
            ],
          ),
          const SizedBox(height: 4),
          // Slider
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: app_theme.neonCyan,
              inactiveTrackColor: (isDark ? app_theme.darkTextSecondary : app_theme.textSecondary).withOpacity(0.3),
              thumbColor: app_theme.videoPlayerControls,
              overlayColor: app_theme.neonCyan.withOpacity(0.2),
            ),
            child: Slider(
              value: _sliderValue.clamp(0.0, 1.0),
              onChangeStart: (_) => setState(() => _isScrubbing = true),
              onChanged: (v) => setState(() => _sliderValue = v),
              onChangeEnd: (v) async {
                final target = Duration(
                  milliseconds: (duration.inMilliseconds * v).round(),
                );
                await _controller.seekTo(target);
                setState(() => _isScrubbing = false);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _fmt(Duration d) {
    String two(int v) => v.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final text = h > 0
        ? '${two(h)}:${two(m)}:${two(s)}'
        : '${two(m)}:${two(s)}';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Text(
      text,
      style: TextStyle(
        color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
