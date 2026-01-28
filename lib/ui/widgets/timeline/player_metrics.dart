import 'package:flutter/widgets.dart';
import 'package:vidviz/core/params.dart';

class PlayerMetrics extends InheritedWidget {
  final Size size;
  final double devicePixelRatio;

  const PlayerMetrics({
    super.key,
    required this.size,
    required this.devicePixelRatio,
    required super.child,
  });

  static PlayerMetrics? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PlayerMetrics>();
  }

  static PlayerMetrics of(BuildContext context) {
    final m = maybeOf(context);
    assert(m != null, 'PlayerMetrics not found in widget tree');
    return m!;
  }

  @override
  bool updateShouldNotify(PlayerMetrics oldWidget) {
    return size != oldWidget.size || devicePixelRatio != oldWidget.devicePixelRatio;
  }
}

class PlayerLayout {
  static Size size(BuildContext context) {
    final metrics = PlayerMetrics.maybeOf(context);
    final s = metrics?.size;
    if (s != null && s.width.isFinite && s.height.isFinite && s.width > 0 && s.height > 0) {
      return s;
    }
    return Size(Params.getPlayerWidth(context), Params.getPlayerHeight(context));
  }

  static double width(BuildContext context) => size(context).width;

  static double height(BuildContext context) => size(context).height;

  static double devicePixelRatio(BuildContext context) {
    final metrics = PlayerMetrics.maybeOf(context);
    return metrics?.devicePixelRatio ?? MediaQuery.of(context).devicePixelRatio;
  }
}
