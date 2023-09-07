import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:flutter/material.dart';

import '../../services/ml_service.dart';

class FacePainter extends CustomPainter {
  FacePainter({
    required this.imageSize,
    required this.face,
    this.camDire2,
    this.pair,
  });
  final Size imageSize;
  final Pair? pair;
  double? scaleX, scaleY;
  Face? face;

  CameraLensDirection? camDire2;

  @override
  void paint(Canvas canvas, Size size) {
    if (face == null) return;

    Paint paint;

    if (this.face!.headEulerAngleY! > 10 || this.face!.headEulerAngleY! < -10) {
      paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = Colors.red;
    } else {
      paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = Colors.green;
    }

    scaleX = size.width / imageSize.width;
    scaleY = size.height / imageSize.height;

    canvas.drawRRect(
      _scaleRect(
          rect: face!.boundingBox,
          imageSize: imageSize,
          widgetSize: size,
          scaleX: scaleX ?? 1,
          scaleY: scaleY ?? 1),
      paint,
    );
    // // print(
    // // "object face!.contours.entries ${face!.contours.entries.first.value!.points}");
    TextSpan span = TextSpan(
        style: const TextStyle(color: Colors.white, fontSize: 20),
        text: "${pair!.name}  ${pair!.distance.toStringAsFixed(2)}");
    // text: "${face.name}  ${face.distance.toStringAsFixed(2)}");
    TextPainter tp = TextPainter(
        text: span,
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(
        canvas,
        Offset(
            face!.boundingBox.left * scaleX!, face!.boundingBox.top * scaleY!));
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) {
    return oldDelegate.imageSize != imageSize || oldDelegate.face != face;
  }
}

RRect _scaleRect(
    {required Rect rect,
    required Size imageSize,
    required Size widgetSize,
    double scaleX = 1,
    double scaleY = 1}) {
  return RRect.fromLTRBR(
      (widgetSize.width - rect.left.toDouble() * scaleX),
      rect.top.toDouble() * scaleY,
      widgetSize.width - rect.right.toDouble() * scaleX,
      rect.bottom.toDouble() * scaleY,
      Radius.circular(10));
}
