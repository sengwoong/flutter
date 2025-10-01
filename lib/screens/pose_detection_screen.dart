import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import '../providers/pose_detection_provider.dart';
import '../main.dart';

class PoseDetectionScreen extends StatefulWidget {
  final String detectionType;

  const PoseDetectionScreen({
    Key? key,
    required this.detectionType,
  }) : super(key: key);

  @override
  _PoseDetectionScreenState createState() => _PoseDetectionScreenState();
}

class _PoseDetectionScreenState extends State<PoseDetectionScreen> {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('카메라를 찾을 수 없습니다.')),
      );
      return;
    }

    // 카메라 권한 요청
    final status = await Permission.camera.request();
    if (status != PermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('카메라 권한이 필요합니다.')),
      );
      return;
    }

    // 전면 카메라 찾기
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
      context.read<PoseDetectionProvider>().setImageRotation(rotation);
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
      print('카메라 초기화 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('카메라 초기화에 실패했습니다.')),
      );
    }
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

  String _getTitle() {
    return '앉기/서기 판별';
  }

  String _getInstructions() {
    return '전신이 카메라에 보이도록 정면에서 촬영해주세요.\n앉기/서기를 자동으로 판별합니다.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(_getTitle()),
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
          // 카메라 뷰
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
                            painter: _PoseOverlayPainter(
                              poses: provider.poses,
                              imageSize: provider.lastImageSize,
                              posture: provider.currentPosture,
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

          // 결과 표시 영역
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              color: Colors.white,
              child: Consumer<PoseDetectionProvider>(
                builder: (context, provider, child) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 안내 메시지
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getInstructions(),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue[800],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(height: 16),

                        // 현재 자세 (실시간 업데이트)
                        _buildResultCard(
                          '현재 자세',
                          provider.postureConfidence > 0
                              ? '${provider.currentPosture} (${(provider.postureConfidence * 100).toStringAsFixed(0)}%)'
                              : provider.currentPosture,
                          Icons.accessibility_new,
                          _getPostureColor(provider.currentPosture),
                        ),
                        if (provider.postureConfidence > 0) ...[
                          SizedBox(height: 8),
                          _buildConfidenceBar(provider.postureConfidence),
                        ],
                        SizedBox(height: 12),

                        // 감지된 포즈 수
                      _buildSitStandStatus(provider),
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

  Widget _buildResultCard(String title, String value, IconData icon, [Color? iconColor]) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor ?? Color(0xFF003A56)),
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

  Widget _buildConfidenceBar(double confidence) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '신뢰도',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
              Text(
                '${(confidence * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 12, color: Colors.grey[800], fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: confidence.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.grey[300],
              color: _getPostureColor(context.read<PoseDetectionProvider>().currentPosture),
            ),
          ),
        ],
      ),
    );
  }

  Color _getPostureColor(String posture) {
    switch (posture) {
      case '누워있음':
        return Colors.red;
      case '앉아있음':
        return Colors.orange;
      case '서있음':
        return Colors.green;
      default:
        return Color(0xFF003A56);
    }
  }

  Widget _buildSitStandStatus(PoseDetectionProvider provider) {
    final posture = provider.currentPosture;
    final isStanding = posture == '서있음';
    final isSitting = posture == '앉아있음';

    Color activeColor(String label) {
      switch (label) {
        case '서있음':
          return Colors.green;
        case '앉아있음':
          return Colors.orange;
        default:
          return Color(0xFF003A56);
      }
    }

    Widget buildChip(String label, bool active) {
      return Expanded(
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? activeColor(label).withOpacity(0.12) : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? activeColor(label) : Colors.grey[300]!),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: active ? activeColor(label) : Colors.grey[700],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildResultCard(
          '판별 결과',
          posture,
          Icons.fitness_center,
          _getPostureColor(posture),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            buildChip('서있음', isStanding),
            SizedBox(width: 8),
            buildChip('앉아있음', isSitting),
          ],
        ),
      ],
    );
  }

  // 상세 결과 위젯들은 앉기/서기 전용 화면으로 단순화하면서 제거되었습니다.
}

class _PoseOverlayPainter extends CustomPainter {
  final List<Pose> poses;
  final Size? imageSize;
  final String posture;
  final int quarterTurns; // 0,1,2,3

  _PoseOverlayPainter({
    required this.poses,
    required this.imageSize,
    required this.posture,
    this.quarterTurns = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (poses.isEmpty || imageSize == null) return;

    // 오버레이 자체를 회전하기 위한 캔버스 변환
    if (quarterTurns % 4 != 0) {
      final double angle = (quarterTurns % 4) * 3.1415926535 / 2.0;
      canvas.translate(size.width / 2, size.height / 2);
      canvas.rotate(angle);
      // 회전 후 원점과 크기 재정의
      if (quarterTurns % 2 == 1) {
        // 90/270도: 폭/높이 스왑
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
      ..color = Colors.greenAccent
      ..style = PaintingStyle.fill;

    final bonePaint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // 그릴 연결(스켈레톤) 정의
    final connections = [
      // 상지
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
      [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
      [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
      // 하지
      [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
      [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
      [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
      [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
      [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
      // 몸통
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
    ];

    for (final pose in poses) {
      if (pose is! Pose) continue;
      // 점
      pose.landmarks.forEach((type, lm) {
        final offset = Offset(lm.x * scaleX, lm.y * scaleY);
        canvas.drawCircle(offset, 3.0, pointPaint);
      });

      // 선
      for (final pair in connections) {
        final a = pose.landmarks[pair[0]];
        final b = pose.landmarks[pair[1]];
        if (a == null || b == null) continue;
        final p1 = Offset(a.x * scaleX, a.y * scaleY);
        final p2 = Offset(b.x * scaleX, b.y * scaleY);
        canvas.drawLine(p1, p2, bonePaint);
      }
    }

    // 상태 배지(카메라 영역 오른쪽 아래)
    final badgeText = posture;
    final textPainter = TextPainter(
      text: TextSpan(
        text: badgeText,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final padding = 8.0;
    final rectWidth = textPainter.width + padding * 2;
    final rectHeight = textPainter.height + padding * 2;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width - rectWidth - 12, size.height - rectHeight - 12, rectWidth, rectHeight),
      Radius.circular(8),
    );
    final bgPaint = Paint()..color = Colors.black.withOpacity(0.5);
    canvas.drawRRect(rect, bgPaint);
    textPainter.paint(
      canvas,
      Offset(size.width - rectWidth - 12 + padding, size.height - rectHeight - 12 + padding),
    );
  }

  @override
  bool shouldRepaint(covariant _PoseOverlayPainter oldDelegate) {
    return oldDelegate.poses != poses ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.posture != posture;
  }
}
