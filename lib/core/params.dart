import 'dart:core';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class Params {

  static bool fixHeight = false;

  static const double APP_BAR_HEIGHT = 80;
  static const double FOOTER_HEIGHT = 36;
  static const double RULER_HEIGHT = 24;
  static const double TIMELINE_HEADER_W = 30;
  static const bool   TIMELINE_HEADER = true;

  // Snap logical size to nearest physical pixel to avoid sub-pixel gaps
  static double _snap(BuildContext context, double logical) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    if (dpr <= 0) return logical;
    return (logical * dpr).round() / dpr;
  }

  static double getPlayerHeight(BuildContext context) {
    var isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    if (isLandscape) {
      final h = MediaQuery.of(context).size.height - getTimelineHeight(context) - (fixHeight ? 24 : 24);
      return _snap(context, h);
    } else {
      final h = getPlayerWidth(context) * 9 / 16;
      return _snap(context, h);
    }
  }

  static double getPlayerWidth(BuildContext context) {
    var isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    if (isLandscape) {
      final w = getPlayerHeight(context) * 16 / 9;
      return _snap(context, w);
    } else {
      final w = MediaQuery.of(context).size.width;
      return _snap(context, w);
    }
  }

  static double getSideMenuWidth(BuildContext context) {
    return (MediaQuery.of(context).size.width - getPlayerWidth(context)) / 2;
  }


  static double getTimelineHeight(BuildContext context) {
    var isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    if (isLandscape) {
      return 0.6 * MediaQuery.of(context).size.height;
    } else {
      return MediaQuery.of(context).size.height - (getPlayerHeight(context) + APP_BAR_HEIGHT * 2 + 24);
    }
  }

  static double getLayerHeight(BuildContext context, String type) {
    if (type == "raster") {
      return math.min( 60, (getTimelineHeight(context) - RULER_HEIGHT) / 4.5 * 2 - 2);
    } else {
      // All overlay types (vector/audio/visualizer/shader/overlay) use same height
      return math.min( 36, (getTimelineHeight(context) - RULER_HEIGHT) / 4.5 - 2);
    }
  }

  static double getLayerBottom(BuildContext context) {
    return getTimelineHeight(context) - RULER_HEIGHT - getLayerHeight(context, "raster") * 2 - 6;
  }
}
