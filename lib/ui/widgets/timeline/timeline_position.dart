import 'package:flutter/material.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/core/params.dart';
import 'package:vidviz/core/theme.dart' as app_theme;

/// Timeline üzerindeki dikey pozisyon çizgisi (playhead)
class TimelinePosition extends StatelessWidget {
  const TimelinePosition({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2.0,
      height: Params.getTimelineHeight(context) - 4,
      margin: const EdgeInsets.fromLTRB(0, 2, 0, 2),
      decoration: BoxDecoration(
        color: app_theme.accent,
        borderRadius: BorderRadius.circular(50),
        //boxShadow: [
        //  BoxShadow(
        //    color: app_theme.accent.withValues(alpha: 0.2),
        //    blurRadius: 0.2,
        //    spreadRadius: 0.2,
        //  ),
        //],
      ),
    );
  }
}

/// Timeline上的zaman göstergesi (marker)
class TimelinePositionMarker extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  TimelinePositionMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: Params.RULER_HEIGHT - 4,
      margin: const EdgeInsets.fromLTRB(0, 2, 0, 2),
      decoration: BoxDecoration(
        gradient: app_theme.neonButtonGradient,
        borderRadius: BorderRadius.circular(1),
        boxShadow: [
          BoxShadow(
            color: app_theme.accent.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: StreamBuilder(
        stream: directorService.position$,
        initialData: 0,
        builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
          return Center(
            child: Text(
              '${directorService.positionMinutes}:${directorService.positionSeconds}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          );
        },
      ),
    );
  }
}