import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:camera/camera.dart';
import 'dart:math';
import 'dart:typed_data';
import 'dart:io';

class PoseDetectionProvider extends ChangeNotifier {
  PoseDetector? _poseDetector;
  List<Pose> _poses = [];
  bool _isDetecting = false;
  Size? _lastImageSize;
  Size? _rawImageSize;
  InputImageRotation _imageRotation = InputImageRotation.rotation0deg;
  int _extraQuarterTurns = 0; // 추가 강제 회전 (90도 단위)
  
  // 분석 결과
  Map<String, dynamic>? _armStretchResult;
  Map<String, dynamic>? _standUpResult;
  Map<String, dynamic>? _ankleResult;
  String _currentPosture = '알 수 없음';
  double _postureConfidence = 0.0;

  // Getters
  List<Pose> get poses => _poses;
  bool get isDetecting => _isDetecting;
  Size? get lastImageSize => _lastImageSize;
  Size? get rawImageSize => _rawImageSize;
  InputImageRotation get imageRotation => _imageRotation;

  void setImageRotation(InputImageRotation rotation) {
    _imageRotation = rotation;
    // 일부 기기(가로 기본)에서 옆으로 누운 케이스 보정: 270도면 추가 90도 회전 적용
    _extraQuarterTurns = (rotation == InputImageRotation.rotation270deg) ? 1 : 0;
  }
  Map<String, dynamic>? get armStretchResult => _armStretchResult;
  Map<String, dynamic>? get standUpResult => _standUpResult;
  Map<String, dynamic>? get ankleResult => _ankleResult;
  String get currentPosture => _currentPosture;
  double get postureConfidence => _postureConfidence;

  PoseDetectionProvider() {
    _initializePoseDetector();
  }

  void _initializePoseDetector() {
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.base,
      ),
    );
  }

  // 정밀 단일 이미지 포즈 감지 (실시간 아님, 정확도 우선)
  Future<List<Pose>> detectPosesFromFilePath(String filePath) async {
    final singleImageDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.single,
        model: PoseDetectionModel.accurate,
      ),
    );

    try {
      final inputImage = InputImage.fromFilePath(filePath);
      final poses = await singleImageDetector.processImage(inputImage);
      return poses;
    } catch (e) {
      debugPrint('단일 이미지 포즈 감지 오류: $e');
      return [];
    } finally {
      await singleImageDetector.close();
    }
  }

  // 실제 Google ML Kit을 사용한 포즈 감지
  Future<void> detectPoses(CameraImage image) async {
    if (_isDetecting || _poseDetector == null) return;

    _isDetecting = true;

    try {
      // 회전 보정된 좌표계에서 사용할 이미지 크기 설정
      final Size rawSize = Size(image.width.toDouble(), image.height.toDouble());
      _rawImageSize = rawSize;
      if (_imageRotation == InputImageRotation.rotation90deg || _imageRotation == InputImageRotation.rotation270deg) {
        _lastImageSize = Size(rawSize.height, rawSize.width);
      } else {
        _lastImageSize = rawSize;
      }
      debugPrint('[MLKit] frame ${image.width}x${image.height}, planes=${image.planes.length}, rot=$_imageRotation');
      final inputImage = _convertCameraImage(image);
      if (inputImage != null) {
        // 실제 Google ML Kit으로 포즈 감지
        _poses = await _poseDetector!.processImage(inputImage);
        
        if (_poses.isNotEmpty) {
          _analyzeAllPoses();
          print('[PoseDetection] ✅ 실제 포즈 감지 완료: ${_poses.length}개 포즈');
        } else {
          print('[PoseDetection] ⚠️ 포즈가 감지되지 않았습니다');
        }
        
        notifyListeners();
      }
    } catch (e) {
      print('포즈 감지 오류: $e');
    } finally {
      _isDetecting = false;
    }
  }

  // 카메라 이미지를 InputImage로 변환 (Android: YUV420→NV21, iOS: BGRA8888)
  InputImage? _convertCameraImage(CameraImage image) {
    try {
      final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());

      if (Platform.isAndroid) {
        final bytes = _yuv420ToNv21(image);
        debugPrint('[MLKit] NV21 bytes=${bytes.length}, y=${image.planes[0].bytes.length}');
        return InputImage.fromBytes(
          bytes: bytes,
          metadata: InputImageMetadata(
            size: imageSize,
            rotation: _imageRotation,
            format: InputImageFormat.nv21,
            // NV21로 재구성했으므로 행 패딩 없이 width 사용
            bytesPerRow: image.width,
          ),
        );
      } else if (Platform.isIOS) {
        final bytes = image.planes.first.bytes;
        debugPrint('[MLKit] BGRA bytes=${bytes.length}');
        return InputImage.fromBytes(
          bytes: bytes,
          metadata: InputImageMetadata(
            size: imageSize,
            rotation: _imageRotation,
            format: InputImageFormat.bgra8888,
            bytesPerRow: image.planes.first.bytesPerRow,
          ),
        );
      }
      return null;
    } catch (e) {
      print('이미지 변환 오류: $e');
      return null;
    }
  }

  // YUV420 3-plane 데이터를 NV21(VU 인터리브)로 변환
  Uint8List _yuv420ToNv21(CameraImage image) {
    final Plane yPlane = image.planes[0];
    final Plane uPlane = image.planes[1];
    final Plane vPlane = image.planes[2];

    final int width = image.width;
    final int height = image.height;

    // 1) Y: 행 패딩 제거하여 width*height로 압축 복사
    final int yRowStride = yPlane.bytesPerRow;
    final Uint8List yBytes = yPlane.bytes;
    final Uint8List y = Uint8List(width * height);
    int yDestIndex = 0;
    for (int row = 0; row < height; row++) {
      final int ySrcIndex = row * yRowStride;
      y.setRange(yDestIndex, yDestIndex + width, yBytes.sublist(ySrcIndex, ySrcIndex + width));
      yDestIndex += width;
    }

    // 2) UV: NV21(VU interleaved)로 재구성 (width*height/2)
    final int uvRowStrideU = uPlane.bytesPerRow;
    final int uvRowStrideV = vPlane.bytesPerRow;
    final int uvPixelStrideU = uPlane.bytesPerPixel ?? 2;
    final int uvPixelStrideV = vPlane.bytesPerPixel ?? 2;
    final Uint8List uBytes = uPlane.bytes;
    final Uint8List vBytes = vPlane.bytes;

    final Uint8List uv = Uint8List(width * height ~/ 2);
    int uvDest = 0;
    for (int row = 0; row < height / 2; row++) {
      final int uRowStart = row * uvRowStrideU;
      final int vRowStart = row * uvRowStrideV;
      for (int col = 0; col < width / 2; col++) {
        final int uIndex = uRowStart + col * uvPixelStrideU;
        final int vIndex = vRowStart + col * uvPixelStrideV;
        // NV21: V 먼저, 그 다음 U
        uv[uvDest++] = vBytes[vIndex];
        uv[uvDest++] = uBytes[uIndex];
      }
    }

    final Uint8List nv21 = Uint8List(y.length + uv.length);
    nv21.setRange(0, y.length, y);
    nv21.setRange(y.length, y.length + uv.length, uv);

    debugPrint('[MLKit] expected NV21=${y.length + uv.length}, y=${y.length}, uv=${uv.length}');
    return nv21;
  }

  // 동적 포즈 데이터 생성 (시간에 따라 변하는 실제 같은 데이터)
  List<Pose> _generateDummyPoses() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final timeVariation = (now / 1000) % 10; // 0-10초 주기로 변화
    
    // 시간에 따라 자세가 변하도록 설정
    double posturePhase = timeVariation / 10.0; // 0.0 ~ 1.0
    
    // 자세 변화: 누워있음(0.0) → 앉아있음(0.5) → 서있음(1.0)
    double shoulderY, hipY, kneeY, ankleY;
    double kneeAngleVariation, torsoAngleVariation;
    
    if (posturePhase < 0.3) {
      // 낮은 활동 자세 (0.0 ~ 0.3) - 단순화하여 '앉아있음'으로 처리
      shoulderY = 150.0;
      hipY = 155.0;
      kneeY = 160.0;
      ankleY = 165.0;
      kneeAngleVariation = 160.0 + (posturePhase * 20); // 160-166도
      torsoAngleVariation = 85.0 - (posturePhase * 10); // 85-75도 (수평에 가까움)
      _currentPosture = '앉아있음';
    } else if (posturePhase < 0.7) {
      // 앉아있는 자세 (0.3 ~ 0.7)
      double sittingPhase = (posturePhase - 0.3) / 0.4;
      shoulderY = 80.0 + (sittingPhase * 20);
      hipY = 150.0 + (sittingPhase * 10);
      kneeY = 200.0 + (sittingPhase * 20);
      ankleY = 240.0 + (sittingPhase * 30);
      kneeAngleVariation = 90.0 + (sittingPhase * 30); // 90-120도
      torsoAngleVariation = 20.0 + (sittingPhase * 15); // 20-35도
      _currentPosture = '앉아있음';
    } else {
      // 서있는 자세 (0.7 ~ 1.0)
      double standingPhase = (posturePhase - 0.7) / 0.3;
      shoulderY = 80.0;
      hipY = 180.0;
      kneeY = 260.0;
      ankleY = 340.0;
      kneeAngleVariation = 170.0 + (standingPhase * 10); // 170-180도
      torsoAngleVariation = 5.0 + (standingPhase * 10); // 5-15도 (수직에 가까움)
      _currentPosture = '서있음';
    }
    
    // 실제 각도 계산을 위한 동적 키포인트 생성
    final landmarks = <PoseLandmarkType, PoseLandmark>{
      PoseLandmarkType.leftShoulder: PoseLandmark(
        type: PoseLandmarkType.leftShoulder,
        x: 100.0, y: shoulderY, z: 0.0, likelihood: 0.9,
      ),
      PoseLandmarkType.rightShoulder: PoseLandmark(
        type: PoseLandmarkType.rightShoulder,
        x: 200.0, y: shoulderY, z: 0.0, likelihood: 0.9,
      ),
      PoseLandmarkType.leftElbow: PoseLandmark(
        type: PoseLandmarkType.leftElbow,
        x: 80.0 + (timeVariation * 5), y: shoulderY + 40, z: 0.0, likelihood: 0.8,
      ),
      PoseLandmarkType.rightElbow: PoseLandmark(
        type: PoseLandmarkType.rightElbow,
        x: 220.0 - (timeVariation * 5), y: shoulderY + 40, z: 0.0, likelihood: 0.8,
      ),
      PoseLandmarkType.leftWrist: PoseLandmark(
        type: PoseLandmarkType.leftWrist,
        x: 60.0 + (timeVariation * 8), y: shoulderY + 80, z: 0.0, likelihood: 0.7,
      ),
      PoseLandmarkType.rightWrist: PoseLandmark(
        type: PoseLandmarkType.rightWrist,
        x: 240.0 - (timeVariation * 8), y: shoulderY + 80, z: 0.0, likelihood: 0.7,
      ),
      PoseLandmarkType.leftHip: PoseLandmark(
        type: PoseLandmarkType.leftHip,
        x: 110.0, y: hipY, z: 0.0, likelihood: 0.9,
      ),
      PoseLandmarkType.rightHip: PoseLandmark(
        type: PoseLandmarkType.rightHip,
        x: 190.0, y: hipY, z: 0.0, likelihood: 0.9,
      ),
      PoseLandmarkType.leftKnee: PoseLandmark(
        type: PoseLandmarkType.leftKnee,
        x: 115.0, y: kneeY, z: 0.0, likelihood: 0.8,
      ),
      PoseLandmarkType.rightKnee: PoseLandmark(
        type: PoseLandmarkType.rightKnee,
        x: 185.0, y: kneeY, z: 0.0, likelihood: 0.8,
      ),
      PoseLandmarkType.leftAnkle: PoseLandmark(
        type: PoseLandmarkType.leftAnkle,
        x: 120.0 + (timeVariation * 2), y: ankleY, z: 0.0, likelihood: 0.7,
      ),
      PoseLandmarkType.rightAnkle: PoseLandmark(
        type: PoseLandmarkType.rightAnkle,
        x: 180.0 - (timeVariation * 2), y: ankleY, z: 0.0, likelihood: 0.7,
      ),
      PoseLandmarkType.leftFootIndex: PoseLandmark(
        type: PoseLandmarkType.leftFootIndex,
        x: 120.0 + (timeVariation * 3), y: ankleY + 20, z: 0.0, likelihood: 0.6,
      ),
      PoseLandmarkType.rightFootIndex: PoseLandmark(
        type: PoseLandmarkType.rightFootIndex,
        x: 180.0 - (timeVariation * 3), y: ankleY + 20, z: 0.0, likelihood: 0.6,
      ),
    };

    print('[PoseGen] 🎭 자세 생성: $_currentPosture (phase: ${posturePhase.toStringAsFixed(2)})');
    print('[PoseGen] 📐 예상 무릎각도: ${kneeAngleVariation.toStringAsFixed(1)}°, 몸통각도: ${torsoAngleVariation.toStringAsFixed(1)}°');

    return [Pose(landmarks: landmarks)];
  }

  void _analyzeAllPoses() {
    if (_poses.isEmpty) return;

    final pose = _poses.first;
    
    // 팔 뻗기 분석
    _armStretchResult = _analyzeArmStretch(pose);
    
    // 일어나기 분석
    _standUpResult = _analyzeStandUp(pose);
    
    // 발목 분석
    _ankleResult = _analyzeAnkle(pose);
    
    // 자세 분류
    final postureResult = _classifyPostureWithConfidence(pose);
    _currentPosture = postureResult['posture'];
    _postureConfidence = postureResult['confidence'];
  }

  Map<String, dynamic>? _analyzeArmStretch(Pose pose) {
    try {
      final leftShoulder = _findLandmark(pose, PoseLandmarkType.leftShoulder);
      final leftElbow = _findLandmark(pose, PoseLandmarkType.leftElbow);
      final leftWrist = _findLandmark(pose, PoseLandmarkType.leftWrist);
      
      final rightShoulder = _findLandmark(pose, PoseLandmarkType.rightShoulder);
      final rightElbow = _findLandmark(pose, PoseLandmarkType.rightElbow);
      final rightWrist = _findLandmark(pose, PoseLandmarkType.rightWrist);

      if (leftShoulder == null || leftElbow == null || leftWrist == null ||
          rightShoulder == null || rightElbow == null || rightWrist == null) {
        return null;
      }

      final leftAngle = _calculateAngle(
        [leftShoulder.x, leftShoulder.y],
        [leftElbow.x, leftElbow.y],
        [leftWrist.x, leftWrist.y],
      );

      final rightAngle = _calculateAngle(
        [rightShoulder.x, rightShoulder.y],
        [rightElbow.x, rightElbow.y],
        [rightWrist.x, rightWrist.y],
      );

      final leftArmExtended = leftAngle > 160;
      final rightArmExtended = rightAngle > 160;
      final isCorrectPosition = leftArmExtended && rightArmExtended;

      return {
        'leftArmAngle': leftAngle,
        'rightArmAngle': rightAngle,
        'leftArmExtended': leftArmExtended,
        'rightArmExtended': rightArmExtended,
        'isCorrectPosition': isCorrectPosition,
      };
    } catch (e) {
      print('팔 뻗기 분석 오류: $e');
      return null;
    }
  }

  Map<String, dynamic>? _analyzeStandUp(Pose pose) {
    try {
      final leftHip = _findLandmark(pose, PoseLandmarkType.leftHip);
      final leftKnee = _findLandmark(pose, PoseLandmarkType.leftKnee);
      final leftAnkle = _findLandmark(pose, PoseLandmarkType.leftAnkle);

      final rightHip = _findLandmark(pose, PoseLandmarkType.rightHip);
      final rightKnee = _findLandmark(pose, PoseLandmarkType.rightKnee);
      final rightAnkle = _findLandmark(pose, PoseLandmarkType.rightAnkle);

      double? leftKneeAngle;
      double? rightKneeAngle;

      if (leftHip != null && leftKnee != null && leftAnkle != null) {
        leftKneeAngle = _calculateAngle(
          [leftHip.x, leftHip.y],
          [leftKnee.x, leftKnee.y],
          [leftAnkle.x, leftAnkle.y],
        );
      }

      if (rightHip != null && rightKnee != null && rightAnkle != null) {
        rightKneeAngle = _calculateAngle(
          [rightHip.x, rightHip.y],
          [rightKnee.x, rightKnee.y],
          [rightAnkle.x, rightAnkle.y],
        );
      }

      if (leftKneeAngle == null && rightKneeAngle == null) return null;

      final angles = [leftKneeAngle, rightKneeAngle].where((a) => a != null).cast<double>().toList();
      final avgKneeAngle = angles.reduce((a, b) => a + b) / angles.length;
      final isStanding = avgKneeAngle > 160;

      return {
        'leftKneeAngle': leftKneeAngle,
        'rightKneeAngle': rightKneeAngle,
        'kneeAngle': avgKneeAngle,
        'isCorrectPosition': isStanding,
      };
    } catch (e) {
      print('일어나기 분석 오류: $e');
      return null;
    }
  }

  Map<String, dynamic>? _analyzeAnkle(Pose pose) {
    try {
      final leftKnee = _findLandmark(pose, PoseLandmarkType.leftKnee);
      final leftAnkle = _findLandmark(pose, PoseLandmarkType.leftAnkle);
      final leftFootIndex = _findLandmark(pose, PoseLandmarkType.leftFootIndex);

      final rightKnee = _findLandmark(pose, PoseLandmarkType.rightKnee);
      final rightAnkle = _findLandmark(pose, PoseLandmarkType.rightAnkle);
      final rightFootIndex = _findLandmark(pose, PoseLandmarkType.rightFootIndex);

      double? leftAnkleAngle;
      double? rightAnkleAngle;

      if (leftKnee != null && leftAnkle != null) {
        final foot = leftFootIndex ?? PoseLandmark(
          type: PoseLandmarkType.leftFootIndex,
          x: leftAnkle.x + (leftAnkle.x - leftKnee.x) * 0.6,
          y: leftAnkle.y + max(10, (leftAnkle.y - leftKnee.y).abs() * 0.2),
          z: 0,
          likelihood: 0.5,
        );

        leftAnkleAngle = _calculateAngle(
          [leftKnee.x, leftKnee.y],
          [leftAnkle.x, leftAnkle.y],
          [foot.x, foot.y],
        );
      }

      if (rightKnee != null && rightAnkle != null) {
        final foot = rightFootIndex ?? PoseLandmark(
          type: PoseLandmarkType.rightFootIndex,
          x: rightAnkle.x + (rightAnkle.x - rightKnee.x) * 0.6,
          y: rightAnkle.y + max(10, (rightAnkle.y - rightKnee.y).abs() * 0.2),
          z: 0,
          likelihood: 0.5,
        );

        rightAnkleAngle = _calculateAngle(
          [rightKnee.x, rightKnee.y],
          [rightAnkle.x, rightAnkle.y],
          [foot.x, foot.y],
        );
      }

      if (leftAnkleAngle == null && rightAnkleAngle == null) return null;

      final angles = [leftAnkleAngle, rightAnkleAngle].where((a) => a != null).cast<double>().toList();
      final avgAnkleAngle = angles.reduce((a, b) => a + b) / angles.length;
      final isCorrectPosition = avgAnkleAngle > 70 && avgAnkleAngle < 110;

      return {
        'leftAnkleAngle': leftAnkleAngle,
        'rightAnkleAngle': rightAnkleAngle,
        'ankleAngle': avgAnkleAngle,
        'isCorrectPosition': isCorrectPosition,
      };
    } catch (e) {
      print('발목 분석 오류: $e');
      return null;
    }
  }

  Map<String, dynamic> _classifyPostureWithConfidence(Pose pose) {
    try {
      final leftKnee = _findLandmark(pose, PoseLandmarkType.leftKnee);
      final leftAnkle = _findLandmark(pose, PoseLandmarkType.leftAnkle);
      final leftFootIndex = _findLandmark(pose, PoseLandmarkType.leftFootIndex);

      final rightKnee = _findLandmark(pose, PoseLandmarkType.rightKnee);
      final rightAnkle = _findLandmark(pose, PoseLandmarkType.rightAnkle);
      final rightFootIndex = _findLandmark(pose, PoseLandmarkType.rightFootIndex);

      List<double> ankleAngles = [];

      // 왼쪽 발목각
      if (leftKnee != null && leftAnkle != null) {
        final pK = _orientPoint(leftKnee);
        final pA = _orientPoint(leftAnkle);
        List<double>? pF = leftFootIndex != null ? _orientPoint(leftFootIndex) : null;
        if (pK != null && pA != null) {
          pF ??= [
            pA[0] + (pA[0] - pK[0]) * 0.6,
            pA[1] + max(10, (pA[1] - pK[1]).abs() * 0.2),
          ];
          final angle = _calculateAngle(pK, pA, pF);
          ankleAngles.add(angle);
        }
      }

      // 오른쪽 발목각
      if (rightKnee != null && rightAnkle != null) {
        final pK = _orientPoint(rightKnee);
        final pA = _orientPoint(rightAnkle);
        List<double>? pF = rightFootIndex != null ? _orientPoint(rightFootIndex) : null;
        if (pK != null && pA != null) {
          pF ??= [
            pA[0] + (pA[0] - pK[0]) * 0.6,
            pA[1] + max(10, (pA[1] - pK[1]).abs() * 0.2),
          ];
          final angle = _calculateAngle(pK, pA, pF);
          ankleAngles.add(angle);
        }
      }

      if (ankleAngles.isEmpty) {
        return {'posture': '알 수 없음', 'confidence': 0.0};
      }

      final avgAnkleAngle = ankleAngles.reduce((a, b) => a + b) / ankleAngles.length;
      print('[자세분류] 발목각도 평균: ${avgAnkleAngle.toStringAsFixed(1)}° (L/R=${ankleAngles.map((a)=>a.toStringAsFixed(1)).join('/')})');

      // 단순 룰: 80~110° → 서있음, 그 외 → 앉아있음
      if (avgAnkleAngle >= 80 && avgAnkleAngle <= 110) {
        final conf = (avgAnkleAngle >= 85 && avgAnkleAngle <= 100) ? 0.9 : 0.75;
        return {'posture': '서있음', 'confidence': conf};
      } else {
        final conf = (avgAnkleAngle <= 70 || avgAnkleAngle >= 120) ? 0.9 : 0.75;
        return {'posture': '앉아있음', 'confidence': conf};
      }
      
    } catch (e) {
      print('자세 분류 오류: $e');
      return {'posture': '알 수 없음', 'confidence': 0.0};
    }
  }

  PoseLandmark? _findLandmark(Pose pose, PoseLandmarkType type) {
    try {
      return pose.landmarks[type];
    } catch (e) {
      return null;
    }
  }

  double _calculateAngle(List<double> a, List<double> b, List<double> c) {
    final radians = atan2(c[1] - b[1], c[0] - b[0]) - atan2(a[1] - b[1], a[0] - b[0]);
    double angle = (radians * 180.0 / pi).abs();
    if (angle > 180.0) {
      angle = 360 - angle;
    }
    return angle;
  }

  // 회전/미러링 고려한 좌표로 변환 (가로모드에서도 스켈레톤이 올바르게 서 있도록)
  List<double>? _orientPoint(PoseLandmark? lm) {
    if (lm == null || _lastImageSize == null || _rawImageSize == null) return null;
    double x = lm.x;
    double y = lm.y;

    // 입력 프레임 회전에 따라 좌표 회전
    switch (_imageRotation) {
      case InputImageRotation.rotation0deg:
        break;
      case InputImageRotation.rotation90deg:
        {
          final double ox = x;
          final double oy = y;
          x = _rawImageSize!.height - oy;
          y = ox;
        }
        break;
      case InputImageRotation.rotation180deg:
        x = _rawImageSize!.width - x;
        y = _rawImageSize!.height - y;
        break;
      case InputImageRotation.rotation270deg:
        {
          final double ox = x;
          final double oy = y;
          x = oy;
          y = _rawImageSize!.width - ox;
        }
        break;
    }

    // 추가 강제 회전 (기기별 가로 기본 보정)
    for (int i = 0; i < _extraQuarterTurns; i++) {
      final double ox = x;
      final double oy = y;
      // 시계방향 90도 회전: (x,y) -> (H - y, x)  (현재 좌표계의 width/height는 _rawImageSize 기준)
      final double w = _rawImageSize!.width;
      final double h = _rawImageSize!.height;
      x = h - oy;
      y = ox;
      // 회전 후 기준 치수 스왑
      _rawImageSize = Size(h, w);
    }

    // 전면 카메라 미러링(이미 프리뷰는 좌우 반전했지만, 좌표계는 원본 기준이므로 여기서 반전)
    // 화면 기준으로 좌우 일치시키기 위해 x를 width - x 처리
    x = _lastImageSize!.width - (x * (_lastImageSize!.width / _rawImageSize!.width));
    y = y * (_lastImageSize!.height / _rawImageSize!.height);

    return [x, y];
  }

  double _calculateTorsoAngle(PoseLandmark shoulder, PoseLandmark hip) {
    final dx = hip.x - shoulder.x;
    final dy = hip.y - shoulder.y;
    final angleRad = atan2(dy, dx);
    final angleDeg = (angleRad * 180.0 / pi - 90).abs();
    return angleDeg;
  }

  @override
  void dispose() {
    _poseDetector?.close();
    super.dispose();
  }
}
