import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/svg.dart';

class SvgIcon extends StatelessWidget {
  final String asset;
  final double size;
  final Color? color;
  final VoidCallback? onTap;
  final BoxFit fit;
  final Alignment alignment;
  final bool matchTextDirection;
  final String? semanticLabel;
  final Clip clipBehavior;

  const SvgIcon({
    super.key,
    required this.asset,
    this.size = 24,
    this.color,
    this.onTap,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.matchTextDirection = false,
    this.semanticLabel,
    this.clipBehavior = Clip.none,
  });

  @override
  Widget build(BuildContext context) {
    Widget icon = SvgPicture.asset(
      'assets/vector/$asset.svg',
      width: size,
      height: size,
      fit: fit,
      alignment: alignment,
      clipBehavior: clipBehavior,
      matchTextDirection: matchTextDirection,
      semanticsLabel: semanticLabel,
      colorFilter:
      color != null ? ColorFilter.mode(color!, BlendMode.srcIn) : null,
    );

    if (onTap != null) {
      icon = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onTap,
        child: icon,
      );
    }

    return icon;
  }
}
