import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../../core/theme.dart' as app_theme;

class ActionButton extends StatelessWidget { // State tutmadığı için Stateless daha performanslı
  final String tooltip;
  final String asset;
  final Color color; // Null olamaz dedik
  final VoidCallback onPressed;

  const ActionButton({
    super.key,
    required this.tooltip,
    required this.asset,
    required this.color,
    required this.onPressed,
    // Hero tag'i kaldırdım, gerekirse eklersin
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Tema renklerini burada belirledik, okunurluk arttı
    final bgColor = isDark ? app_theme.projectListCardBg : app_theme.surface;
    final borderColor = isDark ? app_theme.projectListCardBorder : app_theme.border;
    final textColor = isDark ? app_theme.darkTextPrimary : app_theme.textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0 , vertical: 4.0),
      // 1. DÜZELTME: Semantics (Erişilebilirlik için önemli)
      child: Semantics(
        label: tooltip,
        button: true,
        child: Material(
          color: Colors.transparent, // Material rengi şeffaf olsun
          child: Ink( // 2. DÜZELTME: Container yerine Ink kullanıyoruz
            width: 60,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: borderColor,
                width: 1,
              ),
            ),
            child: InkWell( // InkWell artık decoration'ın İÇİNDE
              onTap: onPressed,
              borderRadius: BorderRadius.circular(14),
              // Video editörlerinde hızlı tepki için splash rengini biraz kısabilirsin
              splashColor: color.withAlpha(5),
              highlightColor: color.withAlpha(15),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      'assets/vector/$asset.svg',
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain, // Contain en güvenlisidir
                      // clipBehavior: Clip.none, -> SVG'lerin artık tam boyutlu olduğu için buna gerek kalmayabilir ama kalsın zararı yok.
                      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                    ),
                    const SizedBox(height: 4),
                    // 3. DÜZELTME: Flexible Text
                    // Yazı uzun gelirse (örn: Almanca çeviri) fontu biraz küçültür
                    Flexible(
                      child: Text(
                        tooltip,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}