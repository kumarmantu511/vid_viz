import 'package:flutter/material.dart';

class TestWrapper extends StatelessWidget {
  final Widget child;
  final Size testSize;
  final double? devicePixelRatio;

  const TestWrapper({
    required this.child,
    required this.testSize,
    this.devicePixelRatio,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        // Gerçek pencere boyutunu simüle et
        data: MediaQueryData(
          size: testSize,
          devicePixelRatio: devicePixelRatio ?? 1.0,
          padding: EdgeInsets.zero,
          viewPadding: EdgeInsets.zero,
         /// orientation: testSize.width > testSize.height ? Orientation.landscape : Orientation.portrait,
        ),
        child: Container(
          color: Colors.lightGreen.shade200, // Görsel olarak fark edilsin
          width: testSize.width,
          height: testSize.height,
          alignment: Alignment.center,
          child: SizedBox.fromSize(
            size: testSize,
            child: child,
          ),
        ),
      ),
    );
  }
}