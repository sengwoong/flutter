import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import '../providers/pose_detection_provider.dart';
import '../main.dart';

class AnkleAutoMeasureScreen extends StatefulWidget {
  const AnkleAutoMeasureScreen({Key? key}) : super(key: key);

  @override
  _AnkleAutoMeasureScreenState createState() => _AnkleAutoMeasureScreenState();
}

class _AnkleAutoMeasureScreenState extends State<AnkleAutoMeasureScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isAnalyzing = false;
  int _overlayTurns = 0; // 0,1,2,3 => 0°,90°,180°,270°

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (cameras.isEmpty) {
      _toast('카메라를 찾을 수 없습니다.');
      return;
    }

    final status = await Permission.camera.request();
    if (status != PermissionStatus.granted) {
      _toast('카메라 권한이 필요합니다.');
      return;
    }

    // 전면 카메라 우선 사용 (앱 컨벤션과 동일)
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _cameraController!.initialize();
      // ML Kit 회전 정보 설정
      final rotation = _cameraRotationToImageRotation(_cameraController!.description.sensorOrientation);
      if (mounted) {
        context.read<PoseDetectionProvider>().setImageRotation(rotation);
      }
      // 가로 기본 기기에서 오버레이가 눕는 경우를 위해 초기 강제 회전값 설정
      _overlayTurns = (rotation == InputImageRotation.rotation270deg) ? 1 : 0;

      setState(() {
        _isCameraInitialized = true;
      });

      // 이미지 스트림 시작
      _cameraController!.startImageStream((CameraImage image) {
        if (!_isAnalyzing) {
          _isAnalyzing = true;
          context.read<PoseDetectionProvider>().detectPoses(image).then((_) {
            _isAnalyzing = false;
          });
        }
      });
    } catch (e) {
      _toast('카메라 초기화에 실패했습니다.');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  InputImageRotation _cameraRotationToImageRotation(int sensorOrientation) {
    switch (sensorOrientation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('발목 각도 자동 측정'),
        backgroundColor: Color(0xFF003A56),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: '오버레이 회전',
            icon: Icon(Icons.rotate_90_degrees_ccw),
            onPressed: () {
              setState(() { _overlayTurns = (_overlayTurns + 1) % 4; });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: _isCameraInitialized
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      // 전면 카메라 미러링 반영
                      Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(3.1415926535),
                        child: CameraPreview(_cameraController!),
                      ),
                      Consumer<PoseDetectionProvider>(
                        builder: (context, provider, _) {
                          return CustomPaint(
                            painter: _AnkleOverlayPainter(
                              poses: provider.poses,
                              imageSize: provider.lastImageSize,
                              quarterTurns: _overlayTurns,
                            ),
                          );
                        },
                      ),
                      Positioned(
                        top: 12,
                        left: 12,
                        child: _buildLiveBadge(),
                      ),
                    ],
                  )
                : Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  ),
          ),

          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              color: Colors.white,
              child: Consumer<PoseDetectionProvider>(
                builder: (context, provider, child) {
                  final ankle = provider.ankleResult;
                  final left = ankle?['leftAnkleAngle'] as double?;
                  final right = ankle?['rightAnkleAngle'] as double?;
                  final avg = ankle?['ankleAngle'] as double?;
                  final ok = (ankle?['isCorrectPosition'] as bool?) ?? false;

                  return SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '전신이 보이도록 서서 발목이 화면에 나오게 해주세요. 실시간으로 발목 각도를 측정합니다.',
                            style: TextStyle(fontSize: 14, color: Colors.blue[800]),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(height: 16),

                        _buildMetricCard('왼쪽 발목 각도', left != null ? '${left.toStringAsFixed(1)}°' : '측정 중...', Icons.directions_walk),
                        SizedBox(height: 8),
                        _buildMetricCard('오른쪽 발목 각도', right != null ? '${right.toStringAsFixed(1)}°' : '측정 중...', Icons.directions_walk),
                        SizedBox(height: 8),
                        _buildMetricCard('평균 발목 각도', avg != null ? '${avg.toStringAsFixed(1)}°' : '측정 중...', Icons.analytics),

                        SizedBox(height: 12),
                        if (avg != null) _buildRangeBar(avg),

                        SizedBox(height: 12),
                        _buildResultChip(ok, avg),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
          ),
          SizedBox(width: 6),
          Text(
            'AI LIVE',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Color(0xFF003A56)),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRangeBar(double value) {
    // 목표 범위: 80~110도
    final min = 60.0;
    final max = 130.0;
    final clamped = value.clamp(min, max);
    final ratio = ((clamped - min) / (max - min)).clamp(0.0, 1.0);
    final inRange = value >= 80 && value <= 110;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('목표 범위: 80° ~ 110°', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
            Text('${value.toStringAsFixed(0)}°', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        SizedBox(height: 6),
        Container(
          height: 12,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(6),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  // 목표 영역 표시
                  Positioned(
                    left: constraints.maxWidth * ((80 - min) / (max - min)),
                    width: constraints.maxWidth * ((110 - 80) / (max - min)),
                    top: 0,
                    bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  // 현재 값 표시
                  Positioned(
                    left: constraints.maxWidth * ratio - 1,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 2, color: inRange ? Colors.green : Colors.orange),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResultChip(bool ok, double? avg) {
    final text = ok ? '정상 범위' : '범위 벗어남';
    final color = ok ? Colors.green : Colors.orange;
    return Container(
      margin: EdgeInsets.only(top: 4),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.error_outline, color: color),
          SizedBox(width: 8),
          Text(
            avg != null ? '$text (평균 ${avg.toStringAsFixed(1)}°)' : '측정 중...'
          ),
        ],
      ),
    );
  }
}

class _AnkleOverlayPainter extends CustomPainter {
  final List<Pose> poses;
  final Size? imageSize;
  final int quarterTurns; // 0,1,2,3

  _AnkleOverlayPainter({
    required this.poses,
    required this.imageSize,
    this.quarterTurns = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (poses.isEmpty || imageSize == null) return;

    if (quarterTurns % 4 != 0) {
      final double angle = (quarterTurns % 4) * 3.1415926535 / 2.0;
      canvas.translate(size.width / 2, size.height / 2);
      canvas.rotate(angle);
      if (quarterTurns % 2 == 1) {
        canvas.translate(-size.height / 2, -size.width / 2);
      } else {
        canvas.translate(-size.width / 2, -size.height / 2);
      }
    }

    final bool swap = (quarterTurns % 2 == 1);
    final double baseW = swap ? imageSize!.height : imageSize!.width;
    final double baseH = swap ? imageSize!.width : imageSize!.height;
    final double scaleX = size.width / baseW;
    final double scaleY = size.height / baseH;

    final pointPaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.fill;

    final bonePaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (final pose in poses) {
      if (pose is! Pose) continue;

      // 관심부위: 무릎-발목-발끝 (좌/우)
      final lk = pose.landmarks[PoseLandmarkType.leftKnee];
      final la = pose.landmarks[PoseLandmarkType.leftAnkle];
      final lf = pose.landmarks[PoseLandmarkType.leftFootIndex];
      final rk = pose.landmarks[PoseLandmarkType.rightKnee];
      final ra = pose.landmarks[PoseLandmarkType.rightAnkle];
      final rf = pose.landmarks[PoseLandmarkType.rightFootIndex];

      Offset? to( PoseLandmark? lm ) => lm == null ? null : Offset(lm.x * scaleX, lm.y * scaleY);

      final offsets = <Offset?>[
        to(lk), to(la), to(lf), to(rk), to(ra), to(rf)
      ];

      for (final o in offsets) {
        if (o != null) canvas.drawCircle(o, 3.0, pointPaint);
      }

      void drawLine(Offset? a, Offset? b) {
        if (a == null || b == null) return;
        canvas.drawLine(a, b, bonePaint);
      }

      drawLine(to(lk), to(la));
      drawLine(to(la), to(lf));
      drawLine(to(rk), to(ra));
      drawLine(to(ra), to(rf));
    }
  }

  @override
  bool shouldRepaint(covariant _AnkleOverlayPainter oldDelegate) {
    return oldDelegate.poses != poses || oldDelegate.imageSize != imageSize;
  }
}


