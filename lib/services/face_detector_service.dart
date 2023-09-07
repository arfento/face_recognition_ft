import 'package:face_net_authentication/locator.dart';
import 'package:face_net_authentication/services/camera.service.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:flutter/material.dart';

class FaceDetectorService {
  CameraService _cameraService = locator<CameraService>();

  late FaceDetector _faceDetector;
  FaceDetector get faceDetector => _faceDetector;

  List<Face> _faces = [];
  List<Face> get faces => _faces;
  bool get faceDetected => _faces.isNotEmpty;

  void initialize() {
    _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      // enableContours: true,
      // enableClassification: true,
    ));
  }

  Future<void> detectFacesFromImage(CameraImage image) async {
    int bytePerRow = 0;
    image.planes.map(
      (Plane plane) {
        bytePerRow = plane.bytesPerRow;
      },
    );
    InputImageMetadata _firebaseImageMetadata = InputImageMetadata(
      rotation:
          _cameraService.cameraRotation ?? InputImageRotation.rotation0deg,
      format: InputImageFormatValue.fromRawValue(image.format.raw) ??
          InputImageFormat.yuv_420_888,
      size: Size(image.width.toDouble(), image.height.toDouble()),
      bytesPerRow: bytePerRow,
      // bytesPerRow: image.planes[0].bytesPerRow,
    );

    // for mlkit 13
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    InputImage _firebaseVisionImage = InputImage.fromBytes(
      // bytes: image.planes[0].bytes,
      bytes: bytes, metadata: _firebaseImageMetadata,
    );
    // for mlkit 13

    _faces = await _faceDetector.processImage(_firebaseVisionImage);
    print('LL :: count ${faces.length}');
  }

  dispose() {
    _faceDetector.close();
  }
}
