import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // HapticFeedback için gerekli

class DashedSlider extends StatelessWidget {
  /// Slider'ın o anki değeri (0.0 - 1.0 arası)
  final double value;

  /// Değer değiştiğinde çalışacak fonksiyon
  final ValueChanged<double> onChanged;

  /// Dolu kısmın rengi (Örn: Turuncu)
  final Color activeColor;

  /// Boş kesik çizgilerin rengi
  final Color inactiveColor;

  /// Tutamaç (Thumb) rengi
  final Color thumbColor;

  /// Arka plandaki kesik çizgi sayısı
  final int dashCount;

  /// Çubuğun yüksekliği
  final double barHeight;

  /// Dokunmatik alan yüksekliği (Kullanıcı deneyimi için daha geniş tutulur)
  final double touchHeight;
  final double thumbWidth;
  final double thumbHeight;
  final double barRadius;

  final double inactiveWidth;
  final double inactiveHeight;
  final double inactiveRadius;
  final bool inactiveLine;

  /// Titreşim olsun mu?
  final bool enableHaptic;

  const DashedSlider({
    Key? key,
    required this.value,
    required this.onChanged,
    this.activeColor = Colors.orange,
    this.inactiveColor = const Color(0x3DFFFFFF), // Colors.white24
    this.thumbColor = Colors.white,
    this.dashCount = 40, // Daha sık çizgiler için artırıldı
    this.barHeight = 12.0,
    this.touchHeight = 40.0, // Parmakla tutması kolay olsun diye geniş
    this.thumbWidth = 6.0, // Parmakla tutması kolay olsun diye geniş
    this.thumbHeight = 26.0, // Parmakla tutması kolay olsun diye geniş
    this.barRadius = 5.0, // Parmakla tutması kolay olsun diye geniş

    this.inactiveWidth = 2.0, // Parmakla tutması kolay olsun diye geniş
    this.inactiveHeight = 12.0, // Parmakla tutması kolay olsun diye geniş
    this.inactiveRadius = 1.0, // Parmakla tutması kolay olsun diye geniş
    this.inactiveLine = false, // Parmakla tutması kolay olsun diye geniş

    this.enableHaptic = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        // Thumb genişliği (Hizalama hesaplaması için)

        return GestureDetector(
          behavior: HitTestBehavior.opaque, // Boşluklara tıklamayı da algıla
          onPanStart: (details) {
            if (enableHaptic) HapticFeedback.selectionClick();
            _handleInput(details.localPosition.dx, maxWidth);
          },
          onPanUpdate: (details) {
            _handleInput(details.localPosition.dx, maxWidth);
          },
          onTapDown: (details) {
            if (enableHaptic) HapticFeedback.selectionClick();
            _handleInput(details.localPosition.dx, maxWidth);
          },
          child: Container(
            height: touchHeight,
            alignment: Alignment.center,
            child: Stack(
              alignment: Alignment.centerLeft,
              clipBehavior: Clip.none, // Thumb'ın gölgesi kesilmesin diye
              children: [
                // 1. KATMAN: Arka Plan Kesik Çizgiler
               if(inactiveLine)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(dashCount, (index) {
                    return Container(
                      width: inactiveWidth, // Çizgi kalınlığı
                      height: inactiveHeight,
                      decoration: BoxDecoration(
                        color: inactiveColor,
                        borderRadius: BorderRadius.circular(inactiveRadius),
                      ),
                    );
                  }),
                )
               else
                Container(
                  height: inactiveHeight,
                  decoration: BoxDecoration(
                    color: inactiveColor,
                    borderRadius: BorderRadius.circular(inactiveRadius),
                  ),
                ),

                // 2. KATMAN: Aktif Dolu Alan (Neon Glow Efekti ile)
                Container(
                  width: maxWidth * value.clamp(0.0, 1.0),
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: activeColor,
                    borderRadius: BorderRadius.circular(barRadius),
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withOpacity(0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 0), // Etrafa yayılma
                      ),
                    ],
                  ),
                ),

                // 3. KATMAN: Thumb (Tutamaç - "Saçlar" ve Gölge)
                Align(
                  alignment: Alignment(value * 2 - 1, 0),
                  child: Container(
                    height: thumbHeight, // Bar'dan daha uzun (Taşma efekti)
                    width: thumbWidth,
                    decoration: BoxDecoration(
                      color: thumbColor,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        // Derinlik gölgesi
                        BoxShadow(
                          color: thumbColor.withOpacity(0.2),
                          blurRadius: 2,
                          offset: const Offset(0, 2),
                        ),
                        // Hafif parlama
                        BoxShadow(
                          color: thumbColor.withOpacity(0.3),
                          blurRadius: 3,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Dokunma mantığı
  void _handleInput(double dx, double maxWidth) {
    // 0.0 ile 1.0 arasında güvenli değer üret
    final newValue = (dx / maxWidth).clamp(0.0, 1.0);

    // Sadece değer gerçekten değiştiyse güncelle (Performans)
    if (newValue != value) {
      onChanged(newValue);
    }
  }
}