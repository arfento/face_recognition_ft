import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:face_net_authentication/pages/db/databse_helper.dart';
import 'package:face_net_authentication/locator.dart';
import 'package:face_net_authentication/pages/models/user.model.dart';
import 'package:face_net_authentication/pages/widgets/camera_detection_preview.dart';
import 'package:face_net_authentication/pages/widgets/camera_header.dart';
import 'package:face_net_authentication/pages/widgets/signin_form.dart';
import 'package:face_net_authentication/pages/widgets/single_picture.dart';
import 'package:face_net_authentication/services/camera.service.dart';
import 'package:face_net_authentication/services/ml_service.dart';
import 'package:face_net_authentication/services/face_detector_service.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';

import '../constants/constants.dart';

class SignInAutoDetect extends StatefulWidget {
  const SignInAutoDetect({Key? key}) : super(key: key);

  @override
  SignInState createState() => SignInState();
}

class SignInState extends State<SignInAutoDetect> {
  CameraService _cameraService = locator<CameraService>();
  FaceDetectorService _faceDetectorService = locator<FaceDetectorService>();
  MLService _mlService = locator<MLService>();

  GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isPictureTaken = false;
  bool _isInitializing = false;
  Pair? pair = Pair("", -5);
  Dio dio = Dio();
  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _cameraService.dispose();
    _mlService.dispose();
    _faceDetectorService.dispose();
    super.dispose();
  }

  Future _start() async {
    setState(() => _isInitializing = true);
    await _cameraService.initialize();
    setState(() => _isInitializing = false);
    _frameFaces();
  }

  _frameFaces() async {
    bool processing = false;
    _cameraService.cameraController!
        .startImageStream((CameraImage image) async {
      if (processing) return; // prevents unnecessary overprocessing.
      processing = true;
      await _predictFacesFromImage(image: image);
      processing = false;
    });
  }

  Future<void> _predictFacesFromImage({@required CameraImage? image}) async {
    assert(image != null, 'Image is null');
    await _faceDetectorService.detectFacesFromImage(image!);
    if (_faceDetectorService.faceDetected) {
      _mlService.setCurrentPrediction(image, _faceDetectorService.faces[0]);
      _predictDirection();
    }
    if (mounted) setState(() {});
  }

  Future<void> _predictDirection() async {
    DatabaseHelper _dbHelper = DatabaseHelper.instance;

    List<User> users = await _dbHelper.queryAllUsers();
    double currDist = 0.0;
    pair = Pair("Unknown", -5);
    for (User user in users) {
      if (user.modelData == null || _mlService.predictedData == null)
        throw Exception("Null argument");

      double sum = 0.0;
      for (int i = 0; i < user.modelData.length; i++) {
        sum += math.pow((user.modelData[i] - _mlService.predictedData[i]), 2);
      }
      currDist = math.sqrt(sum);

      if (pair!.distance == -5 || currDist < pair!.distance) {
        pair!.distance = currDist;
        pair!.name = user.user;
        if (_faceDetectorService.faces[0].headEulerAngleY! > 10 ||
            _faceDetectorService.faces[0].headEulerAngleY! < -10) {
        } else {
          // await Future.delayed(Duration(seconds: 1)).then((value) async {
          await _onFaceDetected();
          // });
        }
      }
      if (pair!.distance > 0.5) {
        pair!.name = "Unknown";
      }
    }
  }

  Future<void> takePicture() async {
    XFile? xfile = await _cameraService.takePicture();

    print("object detected user : ${xfile!.path}");
    File file = File(xfile.path);
    setState(() => _isPictureTaken = true);
    await uploadImage(file);
  }

  Future<void> uploadImage(File file) async {
    String fileName = file.path.split('/').last;
    print(
        "object uploud image user filename : $fileName path:  ${file.path}, path2 :${_cameraService.imagePath!}");
    FormData formData = FormData.fromMap({
      "file": await MultipartFile.fromFile(
        file.path,
        filename: fileName,
        contentType: MediaType("image", "jpeg"), //important
      ),
    });

    await dio
        .post(
      Constants.recognize!,
      data: formData,
      options: Options(
        headers: {
          "Accept": "application/json",
          "Content-Type": "multipart/form-data"
        },
      ),
    )
        .then((response) async {
      print("then response $response");
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
                content: Text(
                    '${response.data['message']}, ${response.data['data']['user']}'));
          });
      await Future.delayed(Duration(seconds: 1), () {
        _onBackPressed();
      });
    }).catchError((error) {
      log("error upload image user :$error");
    });
  }

  _onBackPressed() {
    Navigator.of(context).pop();
  }

  _reload() {
    if (mounted) setState(() => _isPictureTaken = false);
    _start();
  }

  Future<void> _onFaceDetected() async {
    if (_faceDetectorService.faces[0].headEulerAngleY! > 10 ||
        _faceDetectorService.faces[0].headEulerAngleY! < -10) {
    } else {
      await takePicture();

      User? user = await _mlService.predict();
      var bottomSheetController = scaffoldKey.currentState!
          .showBottomSheet((context) => signInSheet(user: user));
      await Future.delayed(Duration(seconds: 2)).then((value) {
        _onBackPressed();
        bottomSheetController.closed.whenComplete(_reload);
      });
    }
  }

  Widget getBodyWidget() {
    if (_isInitializing) return Center(child: CircularProgressIndicator());
    if (_isPictureTaken)
      return SinglePicture(imagePath: _cameraService.imagePath!);
    return CameraDetectionPreview(pair);
  }

  @override
  Widget build(BuildContext context) {
    Widget header = CameraHeader("LOGIN", onBackPressed: _onBackPressed);
    Widget body = getBodyWidget();

    return Scaffold(
      key: scaffoldKey,
      body: Stack(
        children: [body, header],
      ),
    );
  }

  signInSheet({required User? user}) => user == null
      ? Container(
          width: MediaQuery.of(context).size.width,
          padding: EdgeInsets.all(20),
          child: Text(
            'User not found 😞',
            style: TextStyle(fontSize: 20),
          ),
        )
      : SignInSheet(user: user);
}
